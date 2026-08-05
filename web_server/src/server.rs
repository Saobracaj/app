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
use crate::index_html;
use crate::meta::{self, Lang};
use crate::questions::Questions;
use crate::well_known;

pub struct AppState {
    pub config: Config,
    /// `index.html` from the bundle, read once at startup.
    pub index_template: String,
    pub questions: Questions,
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
        Ok(Self {
            config,
            index_template,
            questions,
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
    let page = meta::resolve(path, &state.config.public_origin, lang, &state.questions);
    let html = index_html::render(&state.index_template, &page);

    (
        [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
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
    let mut response = next.run(request).await;
    let headers = response.headers_mut();

    // An older mime database hands `.wasm` out as octet-stream, and the
    // browser then refuses to stream-compile it. State the type ourselves.
    if path.ends_with(".wasm") {
        headers.insert(
            header::CONTENT_TYPE,
            HeaderValue::from_static("application/wasm"),
        );
    }

    if !headers.contains_key(header::CACHE_CONTROL) {
        let is_html = headers
            .get(header::CONTENT_TYPE)
            .and_then(|value| value.to_str().ok())
            .is_some_and(|value| value.starts_with("text/html"));
        headers.insert(
            header::CACHE_CONTROL,
            HeaderValue::from_static(cache_control_for(&path, is_html)),
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

    response
}

/// Flutter's web output is not content-hashed: `main.dart.js` keeps its name
/// across releases. So nothing may be cached immutably — the entry points are
/// revalidated every time, and the rest gets a short window that a deploy
/// outlives.
fn cache_control_for(path: &str, is_html: bool) -> &'static str {
    const ALWAYS_REVALIDATE: [&str; 4] = [
        "/flutter_bootstrap.js",
        "/flutter_service_worker.js",
        "/version.json",
        "/manifest.json",
    ];
    if is_html || ALWAYS_REVALIDATE.contains(&path) {
        "no-cache"
    } else {
        "public, max-age=3600"
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
        write(
            dir.path(),
            "assets/assets/allQuestions.json",
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешак је приказан:", "HasImage": true}]"#,
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
        let response = router
            .clone()
            .oneshot(Request::builder().uri(path).body(Body::empty()).unwrap())
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

        let (status, headers, _) = get_path(&router, "/main.dart.wasm").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(headers[header::CONTENT_TYPE], "application/wasm");
        assert_eq!(headers[header::CACHE_CONTROL], "public, max-age=3600");

        // The entry point must never be served from a stale cache, or a deploy
        // takes an hour to reach anyone.
        let (_, headers, _) = get_path(&router, "/flutter_bootstrap.js").await;
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
    async fn health_check_answers_without_touching_the_bundle() {
        let dir = bundle();
        let (status, _, body) = get_path(&router(&dir), "/healthz").await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(body, "ok");
    }
}
