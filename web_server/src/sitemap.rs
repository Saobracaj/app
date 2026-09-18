//! `robots.txt` and `sitemap.xml`.
//!
//! A crawler has two ways in: the links on the pages ([`crate::seo`]) and the
//! sitemap. The sitemap is the reliable one — it names every public address
//! outright, so the ~1500 questions and the ~380 law articles do not depend on
//! being walked to. Both files are built once at startup out of the bundle,
//! because the bundle is what a release changes.

use crate::dates::ContentDates;
use crate::questions::{Questions, FREE_CATEGORY_IDS};
use crate::route::encode;
use crate::zakon::Law;

/// One address of the sitemap.
struct Entry {
    path: String,
    /// `YYYY-MM-DD` — when the content behind the address last changed. Google
    /// uses it to decide what to recrawl, but only as long as it is honest
    /// (see [`crate::dates`]).
    lastmod: String,
    /// The question's illustration, when it has one: Google Images finds the
    /// road-sign questions through this.
    image: Option<String>,
}

/// Paths that must never be crawled: everything personal (the account, a group,
/// a list, the support chat), the admin screens, and the transient ones (a test
/// run has its questions in the query string — thousands of addresses showing
/// the same screen).
const DISALLOWED: [&str; 19] = [
    "/invite/",
    "/settings",
    "/login",
    "/register",
    "/resetPassword",
    "/confirmCode",
    "/deleteAccount",
    "/displayName",
    "/notifications",
    "/appearance",
    "/features",
    "/statistics",
    "/lists/",
    "/groups/",
    "/support",
    "/moderation",
    "/billing",
    "/testPush",
    "/start",
];

pub fn robots(origin: &str) -> String {
    let mut out = String::from("User-agent: *\n");
    for path in DISALLOWED {
        out.push_str(&format!("Disallow: {path}\n"));
    }
    // A test run and the exam simulation live under `/quest…`, which by prefix
    // also covers the catalog and every single question. The longer rule wins
    // (Google, Bing and Yandex all resolve it that way), so the two addresses
    // worth indexing are spelled out again.
    out.push_str("Disallow: /quest\n");
    out.push_str("Allow: /questions\n");
    out.push_str("Allow: /question/\n");
    out.push('\n');
    out.push_str(&format!("Sitemap: {origin}/sitemap.xml\n"));
    out
}

pub fn sitemap(origin: &str, questions: &Questions, law: &Law, dates: &ContentDates) -> String {
    let page = |path: &str, lastmod: &str| Entry {
        path: path.to_string(),
        lastmod: lastmod.to_string(),
        image: None,
    };
    let mut entries: Vec<Entry> = vec![
        page("/", &dates.pages),
        page("/questions", &dates.questions),
        page("/practice", &dates.pages),
        page("/zakon", &dates.law),
        page("/about", &dates.pages),
        page("/tariffs", &dates.pages),
    ];
    entries.extend(questions.ids().into_iter().map(|id| {
        Entry {
            path: format!("/question/{id}"),
            lastmod: dates.questions.clone(),
            image: questions
                .get(id, crate::meta::Lang::Sr)
                .and_then(|q| q.image_id)
                .map(|image_id| format!("{origin}/assets/assets/img/{image_id}.jpeg")),
        }
    }));
    // Only the free categories' notes: the rest is what the subscription is
    // for, and a paywalled page has no business in the index.
    entries.extend(
        FREE_CATEGORY_IDS
            .iter()
            .filter(|id| questions.category(id).is_some())
            .map(|id| {
                page(
                    &format!("/konspekt?category={}", encode(id)),
                    &dates.questions,
                )
            }),
    );
    entries.extend(law.articles().iter().map(|article| {
        let path = match article.chapter.as_deref() {
            Some(chapter) => format!(
                "/zakon?chapter={}&chlan={}",
                encode(chapter),
                encode(&article.chlan)
            ),
            None => format!("/zakon?chlan={}", encode(&article.chlan)),
        };
        page(&path, &dates.law)
    }));

    let mut out = String::with_capacity(entries.len() * 140);
    out.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    out.push_str(
        "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" \
         xmlns:image=\"http://www.google.com/schemas/sitemap-image/1.1\">\n",
    );
    for entry in entries {
        out.push_str(&format!(
            "  <url><loc>{}{}</loc><lastmod>{}</lastmod>",
            origin,
            xml(&entry.path),
            xml(&entry.lastmod)
        ));
        if let Some(image) = entry.image {
            out.push_str(&format!(
                "<image:image><image:loc>{}</image:loc></image:image>",
                xml(&image)
            ));
        }
        out.push_str("</url>\n");
    }
    out.push_str("</urlset>\n");
    out
}

fn xml(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('\'', "&apos;")
        .replace('"', "&quot;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    const ORIGIN: &str = "https://saobracaj.gleb.at";

    fn write(root: &Path, name: &str, body: &str) {
        let assets = root.join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(assets.join(name), body).unwrap();
    }

    fn bundle() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        write(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 11, "qId": 42, "Text": "Прво", "HasImage": true, "categoryId": "25"},
                {"qcId": 12, "qId": 12, "Text": "Друго", "categoryId": "27"}]"#,
        );
        write(
            dir.path(),
            "categories.json",
            r#"[{"id": "25", "name": "Основе", "subcategories": []},
                {"id": "27", "name": "Трајање", "subcategories": []}]"#,
        );
        write(
            dir.path(),
            "parsed_zakon.json",
            r#"[{"chapter": "I", "chlan": "2а", "paragraph": "0", "sr": "Члан 2а", "ru": "Статья 2а"}]"#,
        );
        dir
    }

    fn dates() -> ContentDates {
        ContentDates {
            questions: "2026-08-16".to_string(),
            law: "2026-07-23".to_string(),
            pages: "2026-09-18".to_string(),
        }
    }

    #[test]
    fn the_sitemap_names_every_public_address_with_its_date() {
        let dir = bundle();
        let map = sitemap(
            ORIGIN,
            &Questions::load(dir.path()),
            &Law::load(dir.path()),
            &dates(),
        );

        assert!(map.contains("<loc>https://saobracaj.gleb.at/</loc><lastmod>2026-09-18</lastmod>"));
        assert!(map.contains(
            "<loc>https://saobracaj.gleb.at/question/11</loc><lastmod>2026-08-16</lastmod>"
        ));
        assert!(map.contains("<loc>https://saobracaj.gleb.at/question/12</loc>"));
        // A question's illustration is listed for image search.
        assert!(map.contains(
            "<image:image><image:loc>https://saobracaj.gleb.at/assets/assets/img/42.jpeg</image:loc></image:image>"
        ));
        // A Cyrillic article number survives into a valid URL, and the
        // parameter separator is escaped as XML wants it.
        assert!(map.contains(
            "<loc>https://saobracaj.gleb.at/zakon?chapter=I&amp;chlan=2%D0%B0</loc><lastmod>2026-07-23</lastmod>"
        ));
        // Free notes are listed, paid ones are not.
        assert!(map.contains("/konspekt?category=25"));
        assert!(!map.contains("/konspekt?category=27"));
    }

    #[test]
    fn a_missing_bundle_still_produces_a_valid_sitemap() {
        let dir = tempfile::tempdir().unwrap();
        let map = sitemap(
            ORIGIN,
            &Questions::load(dir.path()),
            &Law::load(dir.path()),
            &dates(),
        );
        assert!(map.starts_with("<?xml"));
        assert!(map.contains("<loc>https://saobracaj.gleb.at/questions</loc>"));
        assert!(map.trim_end().ends_with("</urlset>"));
    }

    #[test]
    fn robots_keeps_the_private_screens_out_and_the_questions_in() {
        let txt = robots(ORIGIN);

        assert!(txt.contains("Disallow: /invite/"));
        assert!(txt.contains("Disallow: /settings"));
        // `/quest` would swallow the catalog by prefix; the longer rule wins.
        assert!(txt.contains("Disallow: /quest\n"));
        assert!(txt.contains("Allow: /questions"));
        assert!(txt.contains("Allow: /question/"));
        assert!(txt.contains("Sitemap: https://saobracaj.gleb.at/sitemap.xml"));
    }
}
