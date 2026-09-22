//! The guides: long-form articles served as plain HTML under
//! `/vodic/<lang>/<slug>`.
//!
//! Everything else on the site is a screen of the app: the server prerenders
//! its content for a crawler, and the app takes over once it has painted. A
//! guide is the opposite — a document a person reads in the browser, with no
//! bundle to load and no screen behind it. So it is a complete page of its
//! own: the markdown from `web_server/guides/<lang>/<slug>.md`, rendered at
//! startup, in a layout that carries the same header, footer and app links as
//! the rest of the site.
//!
//! Why here and not a separate site: the same domain (one Search Console
//! property, one sitemap, links between the question pages and the guides),
//! the same deploy, and the same `Organization` in the structured data.
//!
//! The files are compiled into the binary (`include_dir`): the image copies
//! only the Flutter bundle and the server, and a guide is content the way the
//! landing copy in [`crate::seo`] is content — it changes with a release.
//!
//! # A guide file
//!
//! ```markdown
//! ---
//! title: Как получить водительские права в Сербии
//! description: Одна фраза для выдачи Google и для превью ссылки.
//! key: get-licence
//! published: 2026-09-22
//! updated: 2026-09-22
//! draft: false
//! ---
//!
//! Первый абзац.
//!
//! ## Первый раздел
//! ```
//!
//! * `title` and `description` go into `<title>`, the description tag and the
//!   Open Graph card; the body must not repeat the title as a `#` heading.
//! * `key` groups translations of one guide across languages (`hreflang`).
//! * `published` / `updated` — `YYYY-MM-DD`; `updated` is the sitemap's
//!   `<lastmod>`, so it must move when the text changes and only then.
//! * `draft: true` keeps the file out of the site entirely (no page, no
//!   sitemap, no link) — a way to commit work in progress.
//! * `## Sections` make the table of contents; `{#own-id}` after a heading
//!   fixes its anchor, otherwise one is derived from the text.
//! * `<!-- cta -->` on a line of its own places the app call-to-action block.
//! * A file whose name starts with `_` is a template or a note, not a guide.

use std::collections::HashMap;
use std::sync::OnceLock;

use include_dir::{include_dir, Dir};
use pulldown_cmark::{html, CowStr, Event, HeadingLevel, Options, Parser, Tag, TagEnd};
use serde_json::json;

use crate::meta::{pick, Lang, SITE_NAME};
use crate::seo::{esc, organization, APP_STORE_URL, PLAY_STORE_URL};

/// `web_server/guides/<lang>/<slug>.md`, baked into the binary.
static SOURCES: Dir = include_dir!("$CARGO_MANIFEST_DIR/guides");

/// The path the guides live under. Not a route of the app: `deepLinkPathFor`
/// (`lib/core/deep_links/deep_link_path.dart`) hands these to the browser and
/// the Apple site association excludes them, so a tapped guide link opens the
/// page and not the app.
pub const ROOT: &str = "vodic";

/// The guides shipped with this build, parsed once.
pub fn embedded() -> &'static Guides {
    static GUIDES: OnceLock<Guides> = OnceLock::new();
    GUIDES.get_or_init(|| {
        let mut sources = Vec::new();
        for dir in SOURCES.dirs() {
            let Some(lang) = dir
                .path()
                .file_name()
                .and_then(|name| name.to_str())
                .and_then(Lang::from_code)
            else {
                tracing::warn!(dir = %dir.path().display(), "guides: not a language directory, skipped");
                continue;
            };
            for file in dir.files() {
                let name = file.path().file_name().and_then(|n| n.to_str()).unwrap_or("");
                let Some(slug) = name.strip_suffix(".md") else {
                    continue;
                };
                if slug.starts_with('_') {
                    continue;
                }
                let Some(text) = file.contents_utf8() else {
                    tracing::warn!(file = %file.path().display(), "guides: not UTF-8, skipped");
                    continue;
                };
                sources.push((lang, slug.to_string(), text.to_string()));
            }
        }
        let guides = Guides::from_sources(sources);
        tracing::info!(guides = guides.all().len(), "loaded the guides");
        guides
    })
}

/// One rendered guide.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Guide {
    pub lang: Lang,
    pub slug: String,
    /// Groups the translations of one guide; `None` when it has none.
    pub key: Option<String>,
    pub title: String,
    pub description: String,
    /// `YYYY-MM-DD`.
    pub published: String,
    /// `YYYY-MM-DD`; never earlier than `published`.
    pub updated: String,
    /// The body as HTML, headings carrying their anchors.
    pub body: String,
    /// `(anchor, text)` of every `##` heading, in order.
    pub toc: Vec<(String, String)>,
    /// Words in the body — for the reading time.
    pub words: usize,
}

impl Guide {
    pub fn path(&self) -> String {
        format!("/{ROOT}/{}/{}", self.lang.code(), self.slug)
    }

    /// About 180 words a minute, never less than one.
    pub fn reading_minutes(&self) -> usize {
        (self.words / 180).max(1)
    }
}

/// Every published guide, in every language.
#[derive(Debug, Default, Clone)]
pub struct Guides {
    items: Vec<Guide>,
}

impl Guides {
    /// Parses `(language, slug, markdown)` triples. A file that cannot be
    /// parsed is logged and skipped rather than taking the site down with
    /// it; a draft is skipped silently.
    pub fn from_sources(sources: impl IntoIterator<Item = (Lang, String, String)>) -> Self {
        let mut items = Vec::new();
        for (lang, slug, text) in sources {
            match parse(lang, &slug, &text) {
                Ok(Some(guide)) => items.push(guide),
                Ok(None) => {}
                Err(error) => {
                    tracing::warn!(%slug, lang = lang.code(), %error, "guide skipped");
                }
            }
        }
        // Newest first; the slug as a tie-break keeps the order stable.
        items.sort_by(|a, b| {
            b.published
                .cmp(&a.published)
                .then_with(|| a.slug.cmp(&b.slug))
        });
        Self { items }
    }

    pub fn all(&self) -> &[Guide] {
        &self.items
    }

    pub fn get(&self, lang: Lang, slug: &str) -> Option<&Guide> {
        self.items.iter().find(|g| g.lang == lang && g.slug == slug)
    }

    /// The guides in one language, newest first.
    pub fn in_language(&self, lang: Lang) -> Vec<&Guide> {
        self.items.iter().filter(|g| g.lang == lang).collect()
    }

    pub fn has_language(&self, lang: Lang) -> bool {
        self.items.iter().any(|g| g.lang == lang)
    }

    /// The same guide in the other languages (by `key`).
    pub fn translations<'a>(&'a self, guide: &'a Guide) -> Vec<&'a Guide> {
        let Some(key) = guide.key.as_deref() else {
            return Vec::new();
        };
        self.items
            .iter()
            .filter(|g| g.key.as_deref() == Some(key) && g.lang != guide.lang)
            .collect()
    }

    /// The latest `updated` among a language's guides — the index page's date.
    pub fn last_updated(&self, lang: Lang) -> Option<&str> {
        self.in_language(lang)
            .iter()
            .map(|g| g.updated.as_str())
            .max()
    }
}

/// Where a request under `/vodic` points.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GuidePath {
    /// `/vodic/ru` — the list of a language's guides.
    Index { lang: Lang },
    /// `/vodic/ru/<slug>`.
    Guide { lang: Lang, slug: String },
}

impl GuidePath {
    /// Parses a percent-decoded request path. `None` for anything that is not
    /// a guide address — including `/vodic` itself, which has no language.
    pub fn parse(path: &str) -> Option<Self> {
        let segments: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();
        match segments.as_slice() {
            [root, lang] if *root == ROOT => Some(GuidePath::Index {
                lang: Lang::from_code(lang)?,
            }),
            [root, lang, slug] if *root == ROOT => Some(GuidePath::Guide {
                lang: Lang::from_code(lang)?,
                slug: (*slug).to_string(),
            }),
            _ => None,
        }
    }

    /// The one spelling of the address: no trailing slash.
    pub fn canonical(&self) -> String {
        match self {
            GuidePath::Index { lang } => format!("/{ROOT}/{}", lang.code()),
            GuidePath::Guide { lang, slug } => format!("/{ROOT}/{}/{slug}", lang.code()),
        }
    }
}

pub fn index_path(lang: Lang) -> String {
    GuidePath::Index { lang }.canonical()
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

/// `Ok(None)` for a draft.
fn parse(lang: Lang, slug: &str, text: &str) -> Result<Option<Guide>, String> {
    let (front, body) = split_front_matter(text)?;
    let field = |name: &str| -> Result<String, String> {
        front
            .get(name)
            .filter(|v| !v.is_empty())
            .cloned()
            .ok_or_else(|| format!("front matter lacks `{name}`"))
    };
    if front.get("draft").is_some_and(|v| v == "true") {
        return Ok(None);
    }
    let published = field("published")?;
    let updated = front
        .get("updated")
        .filter(|v| !v.is_empty())
        .cloned()
        .unwrap_or_else(|| published.clone());
    for (name, value) in [("published", &published), ("updated", &updated)] {
        if !is_date(value) {
            return Err(format!("`{name}` is not YYYY-MM-DD: {value}"));
        }
    }
    if updated < published {
        return Err(format!(
            "`updated` ({updated}) precedes `published` ({published})"
        ));
    }
    if !slug
        .bytes()
        .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
    {
        return Err(format!(
            "slug must be lower-case ASCII letters, digits and dashes: {slug}"
        ));
    }

    let rendered = render_markdown(body, lang);
    Ok(Some(Guide {
        lang,
        slug: slug.to_string(),
        key: front.get("key").filter(|v| !v.is_empty()).cloned(),
        title: field("title")?,
        description: field("description")?,
        published,
        updated,
        body: rendered.html,
        toc: rendered.toc,
        words: rendered.words,
    }))
}

/// The `key: value` block between the two `---` lines, and what follows it.
fn split_front_matter(text: &str) -> Result<(HashMap<String, String>, &str), String> {
    let text = text.trim_start_matches('\u{feff}');
    let rest = text
        .strip_prefix("---")
        .and_then(|rest| {
            rest.strip_prefix("\r\n")
                .or_else(|| rest.strip_prefix('\n'))
        })
        .ok_or("the file must start with a `---` front matter block")?;
    let mut fields = HashMap::new();
    let mut offset = 0;
    for line in rest.split_inclusive('\n') {
        offset += line.len();
        let line = line.trim_end_matches(['\r', '\n']);
        if line.trim() == "---" {
            return Ok((fields, &rest[offset..]));
        }
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (name, value) = line
            .split_once(':')
            .ok_or_else(|| format!("front matter line without a colon: {line}"))?;
        let value = value.trim();
        let value = value
            .strip_prefix('"')
            .and_then(|v| v.strip_suffix('"'))
            .or_else(|| value.strip_prefix('\'').and_then(|v| v.strip_suffix('\'')))
            .unwrap_or(value);
        fields.insert(name.trim().to_string(), value.to_string());
    }
    Err("the front matter block is not closed with `---`".to_string())
}

fn is_date(value: &str) -> bool {
    let bytes = value.as_bytes();
    bytes.len() == 10
        && bytes[4] == b'-'
        && bytes[7] == b'-'
        && bytes
            .iter()
            .enumerate()
            .all(|(at, b)| at == 4 || at == 7 || b.is_ascii_digit())
}

struct Rendered {
    html: String,
    toc: Vec<(String, String)>,
    words: usize,
}

/// The call-to-action placeholder, as pulldown-cmark hands it through.
const CTA_MARKER: &str = "<!-- cta -->";

/// Markdown to HTML: `##`/`###` headings get anchors (kept when the author
/// wrote `{#id}`), the `##` ones make the table of contents, and the words
/// are counted on the way.
fn render_markdown(markdown: &str, lang: Lang) -> Rendered {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_HEADING_ATTRIBUTES);
    options.insert(Options::ENABLE_SMART_PUNCTUATION);
    let events: Vec<Event> = Parser::new_ext(markdown, options).collect();

    let mut out: Vec<Event> = Vec::with_capacity(events.len());
    let mut toc = Vec::new();
    let mut taken: Vec<String> = Vec::new();
    let mut words = 0;
    let mut at = 0;
    while at < events.len() {
        match &events[at] {
            Event::Start(Tag::Heading {
                level,
                id,
                classes,
                attrs,
            }) if matches!(level, HeadingLevel::H2 | HeadingLevel::H3) => {
                // The heading's text is everything up to its end tag.
                let end = events[at..]
                    .iter()
                    .position(|e| matches!(e, Event::End(TagEnd::Heading(_))))
                    .map(|offset| at + offset)
                    .unwrap_or(events.len());
                let text: String = events[at + 1..end]
                    .iter()
                    .filter_map(|e| match e {
                        Event::Text(t) | Event::Code(t) => Some(t.as_ref()),
                        _ => None,
                    })
                    .collect();
                let anchor = match id {
                    Some(id) => id.to_string(),
                    None => anchor_for(&text, lang),
                };
                let anchor = unique(anchor, &taken);
                taken.push(anchor.clone());
                if *level == HeadingLevel::H2 {
                    toc.push((anchor.clone(), text.trim().to_string()));
                }
                words += text.split_whitespace().count();
                out.push(Event::Start(Tag::Heading {
                    level: *level,
                    id: Some(CowStr::from(anchor)),
                    classes: classes.clone(),
                    attrs: attrs.clone(),
                }));
                out.extend(events[at + 1..end].iter().cloned());
                if end < events.len() {
                    out.push(events[end].clone());
                }
                at = end + 1;
            }
            event => {
                if let Event::Text(t) = event {
                    words += t.split_whitespace().count();
                }
                out.push(event.clone());
                at += 1;
            }
        }
    }

    let mut html_out = String::with_capacity(markdown.len() * 2);
    html::push_html(&mut html_out, out.into_iter());
    Rendered {
        html: html_out,
        toc,
        words,
    }
}

fn unique(anchor: String, taken: &[String]) -> String {
    if !taken.contains(&anchor) {
        return anchor;
    }
    (2..)
        .map(|n| format!("{anchor}-{n}"))
        .find(|candidate| !taken.contains(candidate))
        .unwrap_or(anchor)
}

/// An anchor out of a heading: Latin letters, digits and dashes. Cyrillic is
/// transliterated so the address stays readable when it is copied — the
/// Russian way for a Russian guide (`ч` → `ch`), the Serbian way for a
/// Serbian one (`ч` → `c`, as in the Latin script without diacritics).
fn anchor_for(text: &str, lang: Lang) -> String {
    let mut out = String::with_capacity(text.len());
    let mut dash = true;
    for ch in text.chars().flat_map(|c| c.to_lowercase()) {
        let mapped: &str = match ch {
            'a'..='z' | '0'..='9' => {
                out.push(ch);
                dash = false;
                continue;
            }
            // Letters the two alphabets share but spell differently in Latin.
            'ж' if lang == Lang::Sr => "z",
            'ч' if lang == Lang::Sr => "c",
            'ш' if lang == Lang::Sr => "s",
            'ц' if lang == Lang::Sr => "c",
            'а' => "a",
            'б' => "b",
            'в' => "v",
            'г' => "g",
            'д' => "d",
            'е' => "e",
            'ё' => "yo",
            'ж' => "zh",
            'з' => "z",
            'и' => "i",
            'й' => "y",
            'к' => "k",
            'л' => "l",
            'м' => "m",
            'н' => "n",
            'о' => "o",
            'п' => "p",
            'р' => "r",
            'с' => "s",
            'т' => "t",
            'у' => "u",
            'ф' => "f",
            'х' => "h",
            'ц' => "c",
            'ч' => "ch",
            'ш' => "sh",
            'щ' => "sch",
            'ъ' | 'ь' => "",
            'ы' => "y",
            'э' => "e",
            'ю' => "yu",
            'я' => "ya",
            // Serbian Cyrillic and the Latin letters with diacritics.
            'ђ' | 'đ' => "dj",
            'ј' => "j",
            'љ' => "lj",
            'њ' => "nj",
            'ћ' | 'ć' => "c",
            'џ' => "dz",
            'č' => "c",
            'š' => "s",
            'ž' => "z",
            _ => {
                if !dash {
                    out.push('-');
                    dash = true;
                }
                continue;
            }
        };
        out.push_str(mapped);
        dash = mapped.is_empty() && dash;
    }
    let trimmed = out.trim_matches('-').to_string();
    if trimmed.is_empty() {
        "section".to_string()
    } else {
        trimmed
    }
}

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

/// The complete HTML of one guide.
pub fn page(guide: &Guide, guides: &Guides, origin: &str) -> String {
    let lang = guide.lang;
    let url = format!("{origin}{}", guide.path());
    let index = index_path(lang);
    let translations = guides.translations(guide);

    let mut head = String::new();
    head.push_str(&format!(
        "<meta property=\"og:type\" content=\"article\">\n\
         <meta property=\"article:published_time\" content=\"{}\">\n\
         <meta property=\"article:modified_time\" content=\"{}\">\n",
        esc(&guide.published),
        esc(&guide.updated),
    ));
    if !translations.is_empty() {
        head.push_str(&format!(
            "<link rel=\"alternate\" hreflang=\"{}\" href=\"{}\">\n",
            lang.code(),
            esc(&url)
        ));
        for other in &translations {
            head.push_str(&format!(
                "<link rel=\"alternate\" hreflang=\"{}\" href=\"{origin}{}\">\n",
                other.lang.code(),
                esc(&other.path())
            ));
        }
    }
    for payload in [
        article_json_ld(guide, origin),
        breadcrumb_json_ld(
            &[
                (format!("{origin}/"), SITE_NAME.to_string()),
                (format!("{origin}{index}"), guides_label(lang)),
                (url.clone(), guide.title.clone()),
            ],
            lang,
        ),
        organization(origin),
    ] {
        head.push_str(&format!(
            "<script type=\"application/ld+json\">{}</script>\n",
            payload.replace("</", "<\\/")
        ));
    }

    let mut body = String::new();
    body.push_str(&breadcrumbs(&[
        ("/".to_string(), pick(lang, "Почетна", "Главная", "Home")),
        (index.clone(), guides_label(lang)),
    ]));
    body.push_str("<article>\n");
    body.push_str(&format!("<h1>{}</h1>\n", esc(&guide.title)));
    body.push_str(&format!(
        "<p class=\"lead\">{}</p>\n",
        esc(&guide.description)
    ));
    body.push_str(&format!(
        "<p class=\"meta\">{}: <time datetime=\"{}\">{}</time> · {}</p>\n",
        esc(&pick(lang, "Ажурирано", "Обновлено", "Updated")),
        esc(&guide.updated),
        esc(&human_date(lang, &guide.updated)),
        esc(&reading_time(lang, guide.reading_minutes())),
    ));
    let cta = cta(lang);
    let mut content = if guide.body.contains(CTA_MARKER) {
        guide.body.replace(CTA_MARKER, &cta)
    } else {
        format!("{}{cta}", guide.body)
    };
    if guide.toc.len() >= 2 {
        let mut toc = format!(
            "<nav class=\"toc\" aria-label=\"{0}\"><h2>{0}</h2>\n<ol>\n",
            esc(&pick(lang, "Садржај", "Содержание", "Contents"))
        );
        for (anchor, text) in &guide.toc {
            toc.push_str(&format!(
                "<li><a href=\"#{}\">{}</a></li>\n",
                esc(anchor),
                esc(text)
            ));
        }
        toc.push_str("</ol></nav>\n");
        // After the opening paragraph: the answer comes first, the map of
        // the rest second.
        match content.find("</p>\n") {
            Some(at) => content.insert_str(at + "</p>\n".len(), &toc),
            None => content.insert_str(0, &toc),
        }
    }
    body.push_str(&content);
    body.push_str("</article>\n");

    if !translations.is_empty() {
        body.push_str(&format!(
            "<p class=\"alternates\">{}: ",
            esc(&pick(
                lang,
                "Овај водич на другим језицима",
                "Этот гайд на других языках",
                "This guide in other languages"
            ))
        ));
        let links: Vec<String> = translations
            .iter()
            .map(|other| {
                format!(
                    "<a href=\"{}\" hreflang=\"{}\">{}</a>",
                    esc(&other.path()),
                    other.lang.code(),
                    esc(&language_name(other.lang))
                )
            })
            .collect();
        body.push_str(&links.join(" · "));
        body.push_str("</p>\n");
    }

    let others: Vec<&Guide> = guides
        .in_language(lang)
        .into_iter()
        .filter(|g| g.slug != guide.slug)
        .collect();
    if !others.is_empty() {
        body.push_str(&format!(
            "<section class=\"more\"><h2>{}</h2>\n<ul>\n",
            esc(&pick(lang, "Још водича", "Другие гайды", "More guides"))
        ));
        for other in others {
            body.push_str(&format!(
                "<li><a href=\"{}\">{}</a> — {}</li>\n",
                esc(&other.path()),
                esc(&other.title),
                esc(&other.description)
            ));
        }
        body.push_str("</ul></section>\n");
    }

    layout(
        lang,
        &Head {
            title: format!("{} — {SITE_NAME}", guide.title),
            description: guide.description.clone(),
            url,
            extra: head,
        },
        &body,
        origin,
    )
}

/// The list of one language's guides.
pub fn index(lang: Lang, guides: &Guides, origin: &str) -> String {
    let url = format!("{origin}{}", index_path(lang));
    let title = pick(
        lang,
        "Водичи: возачка дозвола у Србији",
        "Гайды: водительские права в Сербии",
        "Guides: a driving licence in Serbia",
    );
    let description = pick(
        lang,
        "Како се полаже возачки испит у Србији, колико кошта, како изгледа теоријски испит — водичи корак по корак.",
        "Как сдать на права в Сербии, сколько это стоит, как проходит теоретический экзамен, что делать с российскими правами — пошаговые гайды на русском.",
        "How the Serbian driving test works, what it costs, how to exchange a foreign licence — step-by-step guides in English.",
    );
    let mut head = String::new();
    head.push_str(&format!(
        "<script type=\"application/ld+json\">{}</script>\n",
        breadcrumb_json_ld(
            &[
                (format!("{origin}/"), SITE_NAME.to_string()),
                (url.clone(), guides_label(lang)),
            ],
            lang,
        )
        .replace("</", "<\\/")
    ));
    head.push_str(&format!(
        "<script type=\"application/ld+json\">{}</script>\n",
        organization(origin).replace("</", "<\\/")
    ));

    let mut body = String::new();
    body.push_str(&breadcrumbs(&[(
        "/".to_string(),
        pick(lang, "Почетна", "Главная", "Home"),
    )]));
    body.push_str(&format!("<h1>{}</h1>\n", esc(&title)));
    body.push_str(&format!("<p class=\"lead\">{}</p>\n", esc(&description)));
    body.push_str("<ul class=\"guides\">\n");
    for guide in guides.in_language(lang) {
        body.push_str(&format!(
            "<li><a href=\"{}\">{}</a><p>{}</p><p class=\"meta\">{} · {}</p></li>\n",
            esc(&guide.path()),
            esc(&guide.title),
            esc(&guide.description),
            esc(&human_date(lang, &guide.updated)),
            esc(&reading_time(lang, guide.reading_minutes())),
        ));
    }
    body.push_str("</ul>\n");
    body.push_str(&cta(lang));

    layout(
        lang,
        &Head {
            title: format!("{title} — {SITE_NAME}"),
            description,
            url,
            extra: head,
        },
        &body,
        origin,
    )
}

/// A guide that is not there. Served with a 404 so it never gets indexed,
/// and with the site's own layout so the reader is not stranded.
pub fn not_found(lang: Lang, origin: &str) -> String {
    let body = format!(
        "<h1>{}</h1>\n<p>{} <a href=\"{}\">{}</a>.</p>\n",
        esc(&pick(
            lang,
            "Страна није пронађена",
            "Страница не найдена",
            "Page not found"
        )),
        esc(&pick(
            lang,
            "Овај водич не постоји или је премештен. Погледајте",
            "Такого гайда нет или он переехал. Посмотрите",
            "There is no such guide, or it has moved. See",
        )),
        esc(&index_path(lang)),
        esc(&pick(lang, "све водиче", "все гайды", "all guides")),
    );
    layout(
        lang,
        &Head {
            title: format!(
                "{} — {SITE_NAME}",
                pick(
                    lang,
                    "Страна није пронађена",
                    "Страница не найдена",
                    "Page not found"
                )
            ),
            description: String::new(),
            url: format!("{origin}{}", index_path(lang)),
            extra: "<meta name=\"robots\" content=\"noindex\">\n".to_string(),
        },
        &body,
        origin,
    )
}

fn guides_label(lang: Lang) -> String {
    pick(lang, "Водичи", "Гайды", "Guides")
}

fn language_name(lang: Lang) -> String {
    match lang {
        Lang::Sr => "Srpski",
        Lang::Ru => "Русский",
        Lang::En => "English",
    }
    .to_string()
}

fn reading_time(lang: Lang, minutes: usize) -> String {
    match lang {
        Lang::Sr => format!("{minutes} min čitanja"),
        Lang::Ru => format!("{minutes} мин чтения"),
        Lang::En => format!("{minutes} min read"),
    }
}

/// `2026-09-22` -> «22 сентября 2026». Falls back to the raw value.
pub fn human_date(lang: Lang, date: &str) -> String {
    let mut parts = date.split('-');
    let (Some(year), Some(month), Some(day)) = (parts.next(), parts.next(), parts.next()) else {
        return date.to_string();
    };
    let Ok(month) = month.parse::<usize>() else {
        return date.to_string();
    };
    if !(1..=12).contains(&month) {
        return date.to_string();
    }
    let day = day.trim_start_matches('0');
    let ru = [
        "января",
        "февраля",
        "марта",
        "апреля",
        "мая",
        "июня",
        "июля",
        "августа",
        "сентября",
        "октября",
        "ноября",
        "декабря",
    ];
    let sr = [
        "januar",
        "februar",
        "mart",
        "april",
        "maj",
        "jun",
        "jul",
        "avgust",
        "septembar",
        "oktobar",
        "novembar",
        "decembar",
    ];
    let en = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
    ];
    match lang {
        Lang::Ru => format!("{day} {} {year}", ru[month - 1]),
        Lang::Sr => format!("{day}. {} {year}.", sr[month - 1]),
        Lang::En => format!("{day} {} {year}", en[month - 1]),
    }
}

fn breadcrumbs(trail: &[(String, String)]) -> String {
    let mut out = String::from("<nav class=\"crumbs\" aria-label=\"breadcrumb\">");
    for (at, (href, label)) in trail.iter().enumerate() {
        if at > 0 {
            out.push_str(" › ");
        }
        out.push_str(&format!("<a href=\"{}\">{}</a>", esc(href), esc(label)));
    }
    out.push_str("</nav>\n");
    out
}

/// The app block: what the reader came for is in the app, and it is free.
fn cta(lang: Lang) -> String {
    format!(
        "<aside class=\"cta\">\n<p><strong>{}</strong></p>\n<p>{}</p>\n\
         <p class=\"links\"><a href=\"/\">{}</a> · <a href=\"{PLAY_STORE_URL}\">Google Play</a> · <a href=\"{APP_STORE_URL}\">App Store</a></p>\n</aside>\n",
        esc(&pick(
            lang,
            "Вежбајте испитна питања у апликацији Saobraćaj",
            "Готовьтесь к теории в приложении Saobraćaj",
            "Practise the exam questions in the Saobraćaj app",
        )),
        esc(&pick(
            lang,
            "Сва званична питања за Б категорију са тачним одговорима, симулација испита по правилима правог и закон уз свако питање. Бесплатно, без регистрације.",
            "Все официальные вопросы категории B с правильными ответами и переводом на русский, симуляция экзамена по правилам настоящего и закон рядом с каждым вопросом. Бесплатно, без регистрации.",
            "Every official category B question with the correct answer and an English translation, a mock exam under the real rules and the law next to each question. Free, no sign-up.",
        )),
        esc(&pick(lang, "Отвори у прегледачу", "Открыть в браузере", "Open in the browser")),
    )
}

fn article_json_ld(guide: &Guide, origin: &str) -> String {
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "Article",
        "headline": guide.title,
        "description": guide.description,
        "inLanguage": guide.lang.code(),
        "datePublished": guide.published,
        "dateModified": guide.updated,
        "mainEntityOfPage": format!("{origin}{}", guide.path()),
        "author": {"@id": format!("{origin}/#organization")},
        "publisher": {"@id": format!("{origin}/#organization")},
        "wordCount": guide.words,
    }))
    .unwrap_or_default()
}

fn breadcrumb_json_ld(trail: &[(String, String)], lang: Lang) -> String {
    let items: Vec<_> = trail
        .iter()
        .enumerate()
        .map(|(at, (url, name))| {
            json!({
                "@type": "ListItem",
                "position": at + 1,
                "name": name,
                "item": url,
            })
        })
        .collect();
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "inLanguage": lang.code(),
        "itemListElement": items,
    }))
    .unwrap_or_default()
}

struct Head {
    title: String,
    description: String,
    url: String,
    /// Extra tags for `<head>`: alternates, article dates, structured data.
    extra: String,
}

/// The document around a page: `<head>`, the site header and footer, the
/// styles. Self-contained on purpose — no bundle, no external stylesheet —
/// so the page is complete in one response and reads the same everywhere.
fn layout(lang: Lang, head: &Head, body: &str, origin: &str) -> String {
    let nav = [
        ("/".to_string(), pick(lang, "Почетна", "Главная", "Home")),
        (
            "/questions".to_string(),
            pick(lang, "Питања", "Вопросы", "Questions"),
        ),
        (
            "/practice".to_string(),
            pick(
                lang,
                "Симулација испита",
                "Симуляция экзамена",
                "Exam simulation",
            ),
        ),
        (index_path(lang), guides_label(lang)),
    ];
    let nav_html: Vec<String> = nav
        .iter()
        .map(|(href, label)| format!("<a href=\"{}\">{}</a>", esc(href), esc(label)))
        .collect();
    let description_tag = if head.description.is_empty() {
        String::new()
    } else {
        format!(
            "<meta name=\"description\" content=\"{}\">\n",
            esc(&head.description)
        )
    };
    format!(
        "<!DOCTYPE html>\n\
         <html lang=\"{lang_code}\">\n\
         <head>\n\
         <meta charset=\"utf-8\">\n\
         <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n\
         <title>{title}</title>\n\
         {description_tag}\
         <link rel=\"canonical\" href=\"{url}\">\n\
         <link rel=\"icon\" href=\"/favicon.png\">\n\
         <meta property=\"og:site_name\" content=\"{site}\">\n\
         <meta property=\"og:locale\" content=\"{locale}\">\n\
         <meta property=\"og:title\" content=\"{title}\">\n\
         <meta property=\"og:description\" content=\"{description}\">\n\
         <meta property=\"og:url\" content=\"{url}\">\n\
         <meta property=\"og:image\" content=\"{origin}/icons/Icon-512.png\">\n\
         <meta name=\"twitter:card\" content=\"summary\">\n\
         {extra}\
         <style>{css}</style>\n\
         </head>\n\
         <body>\n\
         <header class=\"top\"><a class=\"brand\" href=\"/\">{site}</a><nav>{nav}</nav></header>\n\
         <main>\n{body}</main>\n\
         <footer><p>{site} · <a href=\"/about\">{about}</a> · <a href=\"{play}\">Google Play</a> · <a href=\"{apple}\">App Store</a></p></footer>\n\
         </body>\n\
         </html>\n",
        lang_code = lang.code(),
        title = esc(&head.title),
        url = esc(&head.url),
        site = esc(SITE_NAME),
        locale = lang.locale(),
        description = esc(&head.description),
        extra = head.extra,
        css = CSS,
        nav = nav_html.join(""),
        about = esc(&pick(lang, "О апликацији", "О приложении", "About")),
        play = PLAY_STORE_URL,
        apple = APP_STORE_URL,
    )
}

/// The brand blue is the exam header's (`lib/theme/exam_theme.dart`).
const CSS: &str = "\
:root{--bg:#fff;--fg:#1c1c1e;--muted:#5f6368;--accent:#2c6aa0;--line:#e3e6ea;--box:#f3f6f9}\
@media(prefers-color-scheme:dark){:root{--bg:#121417;--fg:#e8eaed;--muted:#9aa0a6;--accent:#8ab4f8;--line:#2c3136;--box:#1c2024}}\
*{box-sizing:border-box}\
body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.6 system-ui,-apple-system,'Segoe UI',Roboto,sans-serif}\
a{color:var(--accent)}\
.top{display:flex;flex-wrap:wrap;gap:.5rem 1.25rem;align-items:center;padding:.75rem 1.25rem;border-bottom:1px solid var(--line)}\
.top .brand{font-weight:700;text-decoration:none;color:var(--fg);font-size:1.1rem}\
.top nav{display:flex;flex-wrap:wrap;gap:1rem;font-size:.95rem}\
.top nav a{text-decoration:none}\
main{max-width:44rem;margin:0 auto;padding:1.5rem 1.25rem 3rem}\
.crumbs{font-size:.9rem;color:var(--muted);margin-bottom:1rem}\
h1{font-size:2rem;line-height:1.2;margin:0 0 .75rem}\
h2{font-size:1.4rem;line-height:1.3;margin:2.25rem 0 .75rem}\
h3{font-size:1.1rem;margin:1.5rem 0 .5rem}\
.lead{font-size:1.15rem;color:var(--muted);margin:0 0 .5rem}\
.meta{font-size:.9rem;color:var(--muted)}\
.toc{background:var(--box);border-radius:.75rem;padding:1rem 1.25rem;margin:1.5rem 0}\
.toc h2{font-size:1rem;margin:0 0 .5rem}\
.toc ol{margin:0;padding-left:1.25rem}\
.toc a{text-decoration:none}\
article img{max-width:100%;height:auto}\
table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.95rem}\
th,td{border:1px solid var(--line);padding:.5rem .6rem;text-align:left;vertical-align:top}\
th{background:var(--box)}\
blockquote{margin:1rem 0;padding:.5rem 1rem;border-left:4px solid var(--accent);background:var(--box)}\
code{font-size:.9em;background:var(--box);padding:.1em .3em;border-radius:.25rem}\
.cta{background:var(--box);border-radius:.75rem;padding:1.25rem 1.5rem;margin:2rem 0}\
.cta p{margin:.25rem 0}\
.cta .links{margin-top:.75rem}\
.guides{list-style:none;padding:0;margin:1.5rem 0}\
.guides li{padding:1rem 0;border-top:1px solid var(--line)}\
.guides li>a{font-size:1.2rem;font-weight:600;text-decoration:none}\
.guides p{margin:.25rem 0}\
.more ul{padding-left:1.25rem}\
.alternates{font-size:.95rem}\
footer{border-top:1px solid var(--line);padding:1rem 1.25rem;font-size:.9rem;color:var(--muted);text-align:center}\
";

#[cfg(test)]
mod tests {
    use super::*;

    const ORIGIN: &str = "https://saobracaj.gleb.at";

    const SAMPLE: &str = "---\n\
title: Как получить права в Сербии\n\
description: Пошаговый гайд.\n\
key: get-licence\n\
published: 2026-09-01\n\
updated: 2026-09-22\n\
---\n\
\n\
Вводный абзац с **жирным** текстом.\n\
\n\
## Автошкола и документы\n\
\n\
Текст раздела.\n\
\n\
### Что взять с собой\n\
\n\
Список.\n\
\n\
<!-- cta -->\n\
\n\
## Экзамен по теории {#teoriya}\n\
\n\
| Что | Сколько |\n\
|---|---|\n\
| Вопросов | 41 |\n\
\n\
## Автошкола и документы\n\
\n\
Повтор заголовка.\n";

    fn guides() -> Guides {
        Guides::from_sources([
            (Lang::Ru, "kak-poluchit-prava".to_string(), SAMPLE.to_string()),
            (
                Lang::Ru,
                "skolko-stoit".to_string(),
                "---\ntitle: Сколько стоит\ndescription: Цены.\npublished: 2026-09-10\n---\n\n## Итого\n\nТекст.\n"
                    .to_string(),
            ),
            (
                Lang::En,
                "how-to-get-a-licence".to_string(),
                "---\ntitle: How to get a licence\ndescription: Step by step.\nkey: get-licence\npublished: 2026-09-05\n---\n\nText.\n"
                    .to_string(),
            ),
            (
                Lang::Ru,
                "chernovik".to_string(),
                "---\ntitle: Черновик\ndescription: Ещё не готов.\npublished: 2026-09-20\ndraft: true\n---\n\nТекст.\n"
                    .to_string(),
            ),
        ])
    }

    #[test]
    fn the_front_matter_becomes_the_guides_metadata() {
        let guides = guides();
        let guide = guides.get(Lang::Ru, "kak-poluchit-prava").unwrap();
        assert_eq!(guide.title, "Как получить права в Сербии");
        assert_eq!(guide.description, "Пошаговый гайд.");
        assert_eq!(guide.key.as_deref(), Some("get-licence"));
        assert_eq!(guide.published, "2026-09-01");
        assert_eq!(guide.updated, "2026-09-22");
        assert_eq!(guide.path(), "/vodic/ru/kak-poluchit-prava");
        // `updated` defaults to `published`.
        assert_eq!(
            guides.get(Lang::Ru, "skolko-stoit").unwrap().updated,
            "2026-09-10"
        );
    }

    #[test]
    fn headings_get_anchors_and_the_second_level_makes_the_contents() {
        let guides = guides();
        let guide = guides.get(Lang::Ru, "kak-poluchit-prava").unwrap();
        assert_eq!(
            guide.toc,
            vec![
                (
                    "avtoshkola-i-dokumenty".to_string(),
                    "Автошкола и документы".to_string()
                ),
                ("teoriya".to_string(), "Экзамен по теории".to_string()),
                (
                    "avtoshkola-i-dokumenty-2".to_string(),
                    "Автошкола и документы".to_string()
                ),
            ]
        );
        assert!(guide.body.contains("<h2 id=\"avtoshkola-i-dokumenty\">"));
        assert!(guide.body.contains("<h3 id=\"chto-vzyat-s-soboy\">"));
        assert!(guide.body.contains("<h2 id=\"teoriya\">"));
        assert!(guide.body.contains("<strong>жирным</strong>"));
        assert!(guide.body.contains("<table>"));
        assert!(guide.words > 10);
    }

    #[test]
    fn a_draft_is_not_a_guide_and_the_rest_are_newest_first() {
        let guides = guides();
        assert!(guides.get(Lang::Ru, "chernovik").is_none());
        let slugs: Vec<&str> = guides
            .in_language(Lang::Ru)
            .iter()
            .map(|g| g.slug.as_str())
            .collect();
        assert_eq!(slugs, vec!["skolko-stoit", "kak-poluchit-prava"]);
        assert!(guides.has_language(Lang::En));
        assert!(!guides.has_language(Lang::Sr));
        assert_eq!(guides.last_updated(Lang::Ru), Some("2026-09-22"));
    }

    #[test]
    fn a_broken_file_is_skipped_rather_than_fatal() {
        let guides = Guides::from_sources([
            (
                Lang::Ru,
                "no-front-matter".to_string(),
                "# Just text\n".to_string(),
            ),
            (
                Lang::Ru,
                "no-title".to_string(),
                "---\ndescription: x\npublished: 2026-01-01\n---\n".to_string(),
            ),
            (
                Lang::Ru,
                "bad-date".to_string(),
                "---\ntitle: t\ndescription: d\npublished: 22.09.2026\n---\n".to_string(),
            ),
            (
                Lang::Ru,
                "Bad_Slug".to_string(),
                "---\ntitle: t\ndescription: d\npublished: 2026-01-01\n---\n".to_string(),
            ),
            (
                Lang::Ru,
                "backwards".to_string(),
                "---\ntitle: t\ndescription: d\npublished: 2026-02-01\nupdated: 2026-01-01\n---\n"
                    .to_string(),
            ),
            (
                Lang::Ru,
                "fine".to_string(),
                "---\ntitle: t\ndescription: d\npublished: 2026-01-01\n---\nok\n".to_string(),
            ),
        ]);
        let slugs: Vec<&str> = guides.all().iter().map(|g| g.slug.as_str()).collect();
        assert_eq!(slugs, vec!["fine"]);
    }

    #[test]
    fn translations_are_found_by_key() {
        let guides = guides();
        let ru = guides.get(Lang::Ru, "kak-poluchit-prava").unwrap();
        let en = guides.get(Lang::En, "how-to-get-a-licence").unwrap();
        assert_eq!(guides.translations(ru), vec![en]);
        assert!(guides
            .translations(guides.get(Lang::Ru, "skolko-stoit").unwrap())
            .is_empty());
    }

    #[test]
    fn guide_addresses_are_parsed_and_spelled_one_way() {
        assert_eq!(
            GuidePath::parse("/vodic/ru/kak-poluchit-prava/"),
            Some(GuidePath::Guide {
                lang: Lang::Ru,
                slug: "kak-poluchit-prava".to_string()
            })
        );
        assert_eq!(
            GuidePath::parse("/vodic/en"),
            Some(GuidePath::Index { lang: Lang::En })
        );
        assert_eq!(
            GuidePath::parse("/vodic/en").unwrap().canonical(),
            "/vodic/en"
        );
        assert_eq!(GuidePath::parse("/vodic"), None);
        assert_eq!(GuidePath::parse("/vodic/de/x"), None);
        assert_eq!(GuidePath::parse("/vodic/ru/a/b"), None);
        assert_eq!(GuidePath::parse("/question/11"), None);
    }

    #[test]
    fn the_page_is_a_complete_document_with_its_metadata() {
        let guides = guides();
        let guide = guides.get(Lang::Ru, "kak-poluchit-prava").unwrap();
        let html = page(guide, &guides, ORIGIN);

        assert!(html.starts_with("<!DOCTYPE html>\n<html lang=\"ru\">"));
        assert!(html.contains("<title>Как получить права в Сербии — Saobraćaj</title>"));
        assert!(html.contains("<link rel=\"canonical\" href=\"https://saobracaj.gleb.at/vodic/ru/kak-poluchit-prava\">"));
        assert!(html.contains("<meta property=\"og:type\" content=\"article\">"));
        assert!(html.contains("<h1>Как получить права в Сербии</h1>"));
        assert!(html.contains("Обновлено: <time datetime=\"2026-09-22\">22 сентября 2026</time>"));
        assert!(html.contains("<nav class=\"toc\""));
        // The call-to-action sits where the marker was, once.
        assert_eq!(html.matches("class=\"cta\"").count(), 1);
        assert!(!html.contains(CTA_MARKER));
        assert!(html.find("class=\"cta\"").unwrap() < html.find("id=\"teoriya\"").unwrap());
        // Structured data and the language alternates.
        assert!(html.contains("\"@type\":\"Article\""));
        assert!(html.contains("\"@type\":\"BreadcrumbList\""));
        assert!(html.contains("\"@type\":\"Organization\""));
        assert!(html.contains("<link rel=\"alternate\" hreflang=\"en\" href=\"https://saobracaj.gleb.at/vodic/en/how-to-get-a-licence\">"));
        assert!(html.contains("<link rel=\"alternate\" hreflang=\"ru\" href=\"https://saobracaj.gleb.at/vodic/ru/kak-poluchit-prava\">"));
        // The other guide of the language is linked; the draft is not.
        assert!(html.contains("href=\"/vodic/ru/skolko-stoit\""));
        assert!(!html.contains("chernovik"));
        // No Flutter bootstrap: this is a document, not the app.
        assert!(!html.contains("flutter_bootstrap"));
    }

    #[test]
    fn a_guide_without_the_marker_gets_the_call_to_action_at_the_end() {
        let guides = guides();
        let guide = guides.get(Lang::Ru, "skolko-stoit").unwrap();
        let html = page(guide, &guides, ORIGIN);
        assert_eq!(html.matches("class=\"cta\"").count(), 1);
        assert!(html.find("Повтор").is_none());
        assert!(html.find("id=\"itogo\"").unwrap() < html.find("class=\"cta\"").unwrap());
        // One guide, one language: no alternates, no "more" section.
        assert!(!html.contains("hreflang"));
    }

    #[test]
    fn the_index_lists_a_languages_guides() {
        let guides = guides();
        let html = index(Lang::Ru, &guides, ORIGIN);
        assert!(html.contains("<h1>Гайды: водительские права в Сербии</h1>"));
        assert!(html.contains("href=\"/vodic/ru/kak-poluchit-prava\""));
        assert!(html.contains("href=\"/vodic/ru/skolko-stoit\""));
        assert!(!html.contains("how-to-get-a-licence"));
        assert!(
            html.contains("<link rel=\"canonical\" href=\"https://saobracaj.gleb.at/vodic/ru\">")
        );
    }

    #[test]
    fn anchors_are_ascii_and_readable() {
        assert_eq!(
            anchor_for("Экзамен по теории: 41 вопрос", Lang::Ru),
            "ekzamen-po-teorii-41-vopros"
        );
        assert_eq!(
            anchor_for("Что взять с собой", Lang::Ru),
            "chto-vzyat-s-soboy"
        );
        assert_eq!(
            anchor_for("Šta je probna vozačka dozvola?", Lang::Sr),
            "sta-je-probna-vozacka-dozvola"
        );
        assert_eq!(
            anchor_for("Пробна возачка дозвола", Lang::Sr),
            "probna-vozacka-dozvola"
        );
        assert_eq!(
            anchor_for("How much does it cost?", Lang::En),
            "how-much-does-it-cost"
        );
        assert_eq!(anchor_for("!!!", Lang::Ru), "section");
    }

    #[test]
    fn text_in_a_guide_cannot_break_out_of_the_markup() {
        let guides = Guides::from_sources([(
            Lang::Ru,
            "x".to_string(),
            "---\ntitle: <script>alert(1)</script>\ndescription: \"a & b\"\npublished: 2026-01-01\n---\n\ntext\n"
                .to_string(),
        )]);
        let html = page(guides.get(Lang::Ru, "x").unwrap(), &guides, ORIGIN);
        // Escaped between tags and in attributes; in the structured data the
        // closing tag is broken up, so the JSON cannot end the script element.
        assert!(!html.contains("<script>alert(1)</script>"));
        assert!(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"));
        assert!(html.contains("alert(1)<\\/script>"));
        assert!(html.contains("content=\"a &amp; b\""));
    }

    #[test]
    fn dates_read_naturally_in_each_language() {
        assert_eq!(human_date(Lang::Ru, "2026-09-02"), "2 сентября 2026");
        assert_eq!(human_date(Lang::Sr, "2026-09-02"), "2. septembar 2026.");
        assert_eq!(human_date(Lang::En, "2026-12-25"), "25 December 2026");
        assert_eq!(human_date(Lang::Ru, "soon"), "soon");
    }
}
