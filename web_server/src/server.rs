//! The HTTP surface: static bundle, single-page fallback, headers.

use std::sync::Arc;

use axum::body::Body;
use axum::extract::{Request, State};
use axum::http::{header, HeaderMap, HeaderValue, StatusCode, Uri};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::Router;
use tower_http::compression::CompressionLayer;
use tower_http::services::ServeDir;
use tower_http::trace::TraceLayer;

use crate::config::Config;
use crate::fingerprint::Fingerprints;
use crate::index_html;
use crate::meta::{self, Lang};
use crate::questions::Questions;
use crate::route::Route;
use crate::seo;
use crate::sitemap;
use crate::well_known;
use crate::zakon::Law;

pub struct AppState {
    pub config: Config,
    /// `index.html` from the bundle, read once at startup.
    pub index_template: String,
    pub questions: Questions,
    /// The law's text, for the article pages and the sitemap.
    pub law: Law,
    /// Entity tags for the bundled files, taken once at startup.
    pub fingerprints: Fingerprints,
    /// `robots.txt` and `sitemap.xml`, built once out of the bundle.
    pub robots: String,
    pub sitemap: String,
}

impl AppState {
    /// Reads what the server needs out of the built bundle.
    ///
    /// A missing `index.html` is fatal: without it every request would 404 and
    /// the container would look healthy while serving nothing.
    pub fn load(config: Config) -> std::io::Result<Self> {
        let index_path = config.web_root.join("index.html");
        let index_template = std::fs::read_to_string(&index_path).map_err(|error| {
            std::io::Error::new(
                error.kind(),
                format!("cannot read {}: {error}", index_path.display()),
            )
        })?;
        let questions = Questions::load(&config.web_root);
        let law = Law::load(&config.web_root);
        let fingerprints = Fingerprints::scan(&config.web_root);
        tracing::info!(files = fingerprints.len(), "fingerprinted the bundle");
        let robots = sitemap::robots(&config.public_origin);
        let sitemap = sitemap::sitemap(&config.public_origin, &questions, &law);
        tracing::info!(
            questions = questions.ids().len(),
            articles = law.articles().len(),
            "built the sitemap",
        );
        Ok(Self {
            config,
            index_template,
            questions,
            law,
            fingerprints,
            robots,
            sitemap,
        })
    }
}

pub fn app(state: Arc<AppState>) -> Router {
    // Files that exist are served straight from the bundle; everything else
    // falls through to the single-page handler, because the app's routes
    // (`/invite/ABC-DEF-GHI`, `/question/11`, …) are not files on disk.
    let files = ServeDir::new(&state.config.web_root)
        .append_index_html_on_directories(false)
        .fallback(get(single_page).with_state(state.clone()));

    Router::new()
        .route("/healthz", get(healthz))
        .route("/robots.txt", get(robots))
        .route("/sitemap.xml", get(sitemap_xml))
        .route("/.well-known/assetlinks.json", get(well_known::assetlinks))
        .route(
            "/.well-known/apple-app-site-association",
            get(well_known::apple_app_site_association),
        )
        // `/` and `/index.html` go through the handler as well, so the home
        // page gets its metadata like every other route.
        .route("/", get(single_page))
        .route("/index.html", get(single_page))
        .fallback_service(files)
        .layer(axum::middleware::from_fn_with_state(
            state.clone(),
            response_headers,
        ))
        .layer(CompressionLayer::new())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

async fn healthz() -> &'static str {
    "ok"
}

async fn robots(State(state): State<Arc<AppState>>) -> Response {
    (
        [(header::CONTENT_TYPE, "text/plain; charset=utf-8")],
        state.robots.clone(),
    )
        .into_response()
}

async fn sitemap_xml(State(state): State<Arc<AppState>>) -> Response {
    (
        [(header::CONTENT_TYPE, "application/xml; charset=utf-8")],
        state.sitemap.clone(),
    )
        .into_response()
}

/// Serves `index.html` with the metadata of the requested route.
async fn single_page(
    State(state): State<Arc<AppState>>,
    uri: Uri,
    headers: HeaderMap,
) -> Response {
    let path = uri.path();
    // A request for a file that isn't there is a mistake, not a route: answering
    // it with the app's HTML would turn a broken `<img>` into a silent 200 and
    // make the service worker cache HTML under an asset's name.
    if looks_like_a_missing_asset(path) {
        return (StatusCode::NOT_FOUND, "Not Found").into_response();
    }

    let lang = Lang::from_accept_language(
        headers
            .get(header::ACCEPT_LANGUAGE)
            .and_then(|value| value.to_str().ok()),
    );
    let origin = &state.config.public_origin;
    let route = Route::parse(path, uri.query().unwrap_or_default());
    let page = meta::resolve(&route, origin, lang, &state.questions, &state.law);
    let prerendered = seo::prerender(&route, &page, lang, origin, &state.questions, &state.law);
    let html = index_html::render(&state.index_template, &page, prerendered.as_ref());

    (
        [
            (header::CONTENT_TYPE, "text/html; charset=utf-8"),
            // The page is built per language, so a shared cache must not hand
            // one visitor's copy to the next.
            (header::VARY, "Accept-Language"),
        ],
        html,
    )
        .into_response()
}

/// True for paths that can only be an asset the bundle doesn't have.
fn looks_like_a_missing_asset(path: &str) -> bool {
    const ASSET_DIRECTORIES: [&str; 5] = [
        "/assets/",
        "/canvaskit/",
        "/icons/",
        "/packages/",
        "/.well-known/",
    ];
    if ASSET_DIRECTORIES.iter().any(|dir| path.starts_with(dir)) {
        return true;
    }
    // A dot in the last segment means an extension: `main.dart.js`, `a.png`.
    // App routes never have one (`/invite/ABC-DEF-GHI`, `/question/11`).
    path.rsplit('/').next().is_some_and(|last| last.contains('.'))
}

/// Caching and security headers for every response.
async fn response_headers(
    State(state): State<Arc<AppState>>,
    request: Request<Body>,
    next: Next,
) -> Response {
    let path = request.uri().path().to_owned();
    let etag = state.fingerprints.etag(&path).map(str::to_owned);

    // The client already holds this exact file: answer the revalidation and
    // skip reading the bundle at all.
    if etag
        .as_deref()
        .is_some_and(|etag| already_held(request.headers(), etag))
    {
        let mut response = StatusCode::NOT_MODIFIED.into_response();
        decorate(response.headers_mut(), &path, etag.as_deref(), &state);
        return response;
    }

    let mut response = next.run(request).await;

    // An older mime database hands `.wasm` out as octet-stream, and the
    // browser then refuses to stream-compile it. State the type ourselves.
    if path.ends_with(".wasm") {
        response.headers_mut().insert(
            header::CONTENT_TYPE,
            HeaderValue::from_static("application/wasm"),
        );
    }

    // Tagging anything but a complete 200 would let a range or an error body be
    // stored under the whole file's identity.
    let etag = etag.filter(|_| response.status() == StatusCode::OK);
    decorate(response.headers_mut(), &path, etag.as_deref(), &state);
    response
}

/// Writes the caching and security headers shared by 200s and 304s.
fn decorate(headers: &mut HeaderMap, path: &str, etag: Option<&str>, state: &AppState) {
    if let Some(etag) = etag {
        if let Ok(value) = HeaderValue::from_str(etag) {
            headers.insert(header::ETAG, value);
        }
    }

    if !headers.contains_key(header::CACHE_CONTROL) {
        headers.insert(
            header::CACHE_CONTROL,
            HeaderValue::from_static(cache_control_for(path)),
        );
    }

    headers.insert(
        header::X_CONTENT_TYPE_OPTIONS,
        HeaderValue::from_static("nosniff"),
    );
    headers.insert(
        header::REFERRER_POLICY,
        HeaderValue::from_static("strict-origin-when-cross-origin"),
    );

    // Only when explicitly asked for — see CrossOriginIsolation.
    if let Some(coep) = state.config.cross_origin_isolation.coep_header() {
        headers.insert(
            header::HeaderName::from_static("cross-origin-opener-policy"),
            HeaderValue::from_static("same-origin"),
        );
        headers.insert(
            header::HeaderName::from_static("cross-origin-embedder-policy"),
            HeaderValue::from_static(coep),
        );
    }
}

/// True when `If-None-Match` names the copy we are about to serve.
///
/// The list form (`"a", "b"`) and `*` are both part of the header, and the weak
/// prefix is ignored on comparison, as the specification asks.
fn already_held(headers: &HeaderMap, etag: &str) -> bool {
    let Some(value) = headers
        .get(header::IF_NONE_MATCH)
        .and_then(|value| value.to_str().ok())
    else {
        return false;
    };
    let ours = etag.trim_start_matches("W/");
    value
        .split(',')
        .map(|candidate| candidate.trim())
        .any(|candidate| candidate == "*" || candidate.trim_start_matches("W/") == ours)
}

/// Flutter's web output is not content-hashed: `main.dart.js` and the assets
/// keep their names across releases, so a stored copy can only be told apart
/// from a fresh one by revalidating it. Everything is therefore `no-cache` —
/// "ask me first", not "don't store" — and the entity tag turns that ask into a
/// 304 for the files a release didn't touch. A deploy reaches every browser on
/// its next load instead of waiting out a time-to-live.
///
/// The one exception is the question illustrations: there are ~1500 of them,
/// they are addressed by question id, and their content does not change with a
/// release, so they keep a real cache window.
fn cache_control_for(path: &str) -> &'static str {
    if path.starts_with("/assets/assets/img/") {
        "public, max-age=86400"
    } else {
        "no-cache"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::to_bytes;
    use std::path::Path;
    use tower::ServiceExt;

    const INDEX: &str = r#"<!DOCTYPE html>
<html>
<head>
  <meta name="description" content="Стандардни опис.">
  <title>saobracaj</title>
</head>
<body><script src="flutter_bootstrap.js" async></script></body>
</html>
"#;

    fn bundle() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        write(dir.path(), "index.html", INDEX);
        write(dir.path(), "flutter_bootstrap.js", "// bootstrap");
        write(dir.path(), "main.dart.wasm", "\0asm");
        write(dir.path(), "assets/assets/img/42.jpeg", "\u{ff}\u{d8}\u{ff}");
        write(
            dir.path(),
            "assets/assets/allQuestions.json",
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешак је приказан:", "HasImage": true,
                 "categoryId": "25", "subcategoryId": 91,
                 "Choices": [{"Text": "на слици А", "isCorrect": true}]}]"#,
        );
        write(
            dir.path(),
            "assets/assets/categories.json",
            r#"[{"id": "25", "name": "Основе безбедности", "subcategories": [{"Id": 91, "Description": "Основне одредбе"}]}]"#,
        );
        write(
            dir.path(),
            "assets/assets/parsed_zakon.json",
            r#"[{"chapter": "I", "chlan": "2", "paragraph": "0", "sr": "Члан 2.", "ru": "Статья 2."},
                {"chapter": "I", "chlan": "2", "paragraph": "1", "sr": "Контролу саобраћаја врши Министарство.", "ru": "…"}]"#,
        );
        dir
    }

    fn write(root: &Path, relative: &str, body: &str) {
        let path = root.join(relative);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, body).unwrap();
    }

    fn router(dir: &tempfile::TempDir) -> Router {
        let config = Config {
            web_root: dir.path().to_path_buf(),
            addr: "127.0.0.1:0".parse().unwrap(),
            public_origin: "https://saobracaj.gleb.at".to_string(),
            cross_origin_isolation: crate::config::CrossOriginIsolation::Off,
        };
        app(Arc::new(AppState::load(config).unwrap()))
    }

    async fn get_path(router: &Router, path: &str) -> (StatusCode, HeaderMap, String) {
        get_with(router, path, &[]).await
    }

    async fn get_with(
        router: &Router,
        path: &str,
        request_headers: &[(header::HeaderName, &str)],
    ) -> (StatusCode, HeaderMap, String) {
        let mut request = Request::builder().uri(path);
        for (name, value) in request_headers {
            request = request.header(name, *value);
        }
        let response = router
            .clone()
            .oneshot(request.body(Body::empty()).unwrap())
            .await
            .unwrap();
        let status = response.status();
        let headers = response.headers().clone();
        let body = to_bytes(response.into_body(), usize::MAX).await.unwrap();
        (status, headers, String::from_utf8_lossy(&body).to_string())
    }

    #[tokio::test]
    async fn an_app_route_gets_the_page_with_its_own_card() {
        let dir = bundle();
        let (status, headers, body) = get_path(&router(&dir), "/question/11").await;

        assert_eq!(status, StatusCode::OK);
        assert_eq!(headers[header::CONTENT_TYPE], "text/html; charset=utf-8");
        assert_eq!(headers[header::CACHE_CONTROL], "no-cache");
        assert!(body.contains("<title>Питање бр. 11 — Saobraćaj</title>"));
        assert!(body.contains("Пешак је приказан:"));
        assert!(body.contains("/assets/assets/img/42.jpeg"));
        // The bundle's own body is still there — this is the real app, not a
        // stand-in page.
        assert!(body.contains("flutter_bootstrap.js"));
    }

    #[tokio::test]
    async fn an_invite_link_lands_on_the_app_and_not_on_a_404() {
        let dir = bundle();
        let (status, _, body) = get_path(&router(&dir), "/invite/ABC-DEF-GHI").await;

        assert_eq!(status, StatusCode::OK);
        assert!(body.contains("Позивница у групу"));
    }

    #[tokio::test]
    async fn a_missing_asset_is_a_404_rather_than_the_app() {
        let dir = bundle();
        for path in ["/assets/assets/img/1.jpeg", "/nope.png", "/canvaskit/x"] {
            let (status, _, _) = get_path(&router(&dir), path).await;
            assert_eq!(status, StatusCode::NOT_FOUND, "{path}");
        }
    }

    #[tokio::test]
    async fn bundle_files_are_served_with_the_right_type_and_caching() {
        let dir = bundle();
        let router = router(&dir);

        // Nothing in the bundle may be served from a stale cache, or a deploy
        // takes a time-to-live to reach anyone.
        for path in ["/main.dart.wasm", "/flutter_bootstrap.js"] {
            let (status, headers, _) = get_path(&router, path).await;
            assert_eq!(status, StatusCode::OK, "{path}");
            assert_eq!(headers[header::CACHE_CONTROL], "no-cache", "{path}");
            assert!(headers.contains_key(header::ETAG), "{path}");
        }
        assert_eq!(
            get_path(&router, "/main.dart.wasm").await.1[header::CONTENT_TYPE],
            "application/wasm",
        );

        // The illustrations are addressed by question id and outlive releases.
        let (_, headers, _) = get_path(&router, "/assets/assets/img/42.jpeg").await;
        assert_eq!(headers[header::CACHE_CONTROL], "public, max-age=86400");
    }

    #[tokio::test]
    async fn an_unchanged_file_revalidates_into_a_304_and_a_changed_one_does_not() {
        let dir = bundle();
        let router = router(&dir);

        let (_, headers, _) = get_path(&router, "/main.dart.wasm").await;
        let etag = headers[header::ETAG].to_str().unwrap().to_string();

        let (status, headers, body) = get_with(
            &router,
            "/main.dart.wasm",
            &[(header::IF_NONE_MATCH, &etag)],
        )
        .await;
        assert_eq!(status, StatusCode::NOT_MODIFIED);
        assert!(body.is_empty());
        // A 304 carries the caching and security headers of the real response.
        assert_eq!(headers[header::CACHE_CONTROL], "no-cache");
        assert_eq!(headers[header::X_CONTENT_TYPE_OPTIONS], "nosniff");
        assert_eq!(headers[header::ETAG], etag);

        // What the next release changed comes down in full — this is the copy
        // the browser is holding from the previous one.
        let (status, _, body) = get_with(
            &router,
            "/main.dart.wasm",
            &[(header::IF_NONE_MATCH, "W/\"0000000000000000\"")],
        )
        .await;
        assert_eq!(status, StatusCode::OK);
        assert!(!body.is_empty());
    }

    #[tokio::test]
    async fn the_page_itself_is_never_tagged() {
        // It is rendered per request (title, description, language), so a stored
        // copy of one route must not stand in for another.
        let dir = bundle();
        let (_, headers, _) = get_path(&router(&dir), "/question/11").await;
        assert!(!headers.contains_key(header::ETAG));
        assert_eq!(headers[header::CACHE_CONTROL], "no-cache");
    }

    #[tokio::test]
    async fn the_link_verification_files_are_served_as_json() {
        let dir = bundle();
        let router = router(&dir);

        for path in [
            "/.well-known/assetlinks.json",
            "/.well-known/apple-app-site-association",
        ] {
            let (status, headers, body) = get_path(&router, path).await;
            assert_eq!(status, StatusCode::OK, "{path}");
            assert_eq!(headers[header::CONTENT_TYPE], "application/json", "{path}");
            serde_json::from_str::<serde_json::Value>(&body).unwrap();
        }
    }

    #[tokio::test]
    async fn isolation_headers_are_off_unless_asked_for() {
        let dir = bundle();
        let (_, headers, _) = get_path(&router(&dir), "/").await;
        assert!(headers.get("cross-origin-opener-policy").is_none());
        assert_eq!(headers[header::X_CONTENT_TYPE_OPTIONS], "nosniff");

        let config = Config {
            web_root: dir.path().to_path_buf(),
            addr: "127.0.0.1:0".parse().unwrap(),
            public_origin: "https://saobracaj.gleb.at".to_string(),
            cross_origin_isolation: crate::config::CrossOriginIsolation::Credentialless,
        };
        let isolated = app(Arc::new(AppState::load(config).unwrap()));
        let (_, headers, _) = get_path(&isolated, "/").await;
        assert_eq!(headers["cross-origin-opener-policy"], "same-origin");
        assert_eq!(headers["cross-origin-embedder-policy"], "credentialless");
    }

    #[tokio::test]
    async fn a_question_page_carries_the_question_for_a_crawler_to_read() {
        let dir = bundle();
        let (status, headers, body) = get_path(&router(&dir), "/question/11").await;

        assert_eq!(status, StatusCode::OK);
        // The app draws itself on a canvas, so the words have to be in the HTML.
        assert!(body.contains("<h1>Питање бр. 11</h1>"));
        assert!(body.contains("на слици А"));
        assert!(body.contains(r#"<script type="application/ld+json">"#));
        // Built per language — a shared cache must know that.
        assert_eq!(headers[header::VARY], "Accept-Language");
        // And the app is still what actually runs.
        assert!(body.contains("flutter_bootstrap.js"));
    }

    #[tokio::test]
    async fn a_law_article_is_a_page_of_its_own() {
        let dir = bundle();
        let (_, _, body) = get_path(&router(&dir), "/zakon?chapter=I&chlan=2").await;

        assert!(body.contains("<h1>Члан 2.</h1>"));
        assert!(body.contains("Контролу саобраћаја врши Министарство."));
        assert!(body.contains(r#"<link rel="canonical" href="https://saobracaj.gleb.at/zakon?chapter=I&amp;chlan=2">"#));
    }

    #[tokio::test]
    async fn a_personal_screen_is_neither_prerendered_nor_indexed() {
        let dir = bundle();
        let router = router(&dir);

        for path in ["/invite/ABC-DEF-GHI", "/settings/profile", "/groups/7/feed"] {
            let (status, _, body) = get_path(&router, path).await;
            assert_eq!(status, StatusCode::OK, "{path}");
            assert!(body.contains(r#"<meta name="robots" content="noindex, follow">"#), "{path}");
            assert!(!body.contains("seo-prerender"), "{path}");
        }
    }

    #[tokio::test]
    async fn robots_and_the_sitemap_are_served() {
        let dir = bundle();
        let router = router(&dir);

        let (status, headers, body) = get_path(&router, "/robots.txt").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(headers[header::CONTENT_TYPE], "text/plain; charset=utf-8");
        assert!(body.contains("Sitemap: https://saobracaj.gleb.at/sitemap.xml"));

        let (status, headers, body) = get_path(&router, "/sitemap.xml").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(headers[header::CONTENT_TYPE], "application/xml; charset=utf-8");
        assert!(body.contains("<loc>https://saobracaj.gleb.at/question/11</loc>"));
        assert!(body.contains("<loc>https://saobracaj.gleb.at/zakon?chapter=I&amp;chlan=2</loc>"));
    }

    #[tokio::test]
    async fn health_check_answers_without_touching_the_bundle() {
        let dir = bundle();
        let (status, _, body) = get_path(&router(&dir), "/healthz").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body, "ok");
    }
}
