//! Rewriting `index.html` for one request.
//!
//! The bundle ships a single `index.html` with a generic title. For every
//! request we hand out a copy of it with the title, the description and the
//! Open Graph tags of the page that was actually asked for (see
//! [`crate::meta`]). Only `<head>` is touched — the Flutter bootstrap below it
//! is served byte for byte.

use crate::meta::PageMeta;

/// Labels the injected block in the served HTML, so "where did this tag come
/// from" is answerable from `view-source:` alone.
const MARKER: &str = "<!-- saobracaj_web: link preview -->";

/// Returns `index.html` with the page's own `<head>` metadata.
pub fn render(template: &str, meta: &PageMeta) -> String {
    let mut html = replace_title(template, &meta.title);
    html = strip_description(&html);
    html = set_html_lang(&html, meta.lang.code());

    let tags = tags_for(meta);
    match html.find("</head>") {
        Some(at) => {
            html.insert_str(at, &tags);
            html
        }
        // A template without a </head> is not something we can improve on;
        // serve it untouched rather than guess.
        None => html,
    }
}

fn tags_for(meta: &PageMeta) -> String {
    let mut tags = format!(
        "  {MARKER}\n\
         \x20 <meta name=\"description\" content=\"{description}\">\n\
         \x20 <link rel=\"canonical\" href=\"{url}\">\n\
         \x20 <meta property=\"og:type\" content=\"website\">\n\
         \x20 <meta property=\"og:site_name\" content=\"Saobraćaj\">\n\
         \x20 <meta property=\"og:locale\" content=\"{locale}\">\n\
         \x20 <meta property=\"og:title\" content=\"{title}\">\n\
         \x20 <meta property=\"og:description\" content=\"{description}\">\n\
         \x20 <meta property=\"og:url\" content=\"{url}\">\n",
        title = escape(&meta.title),
        description = escape(&meta.description),
        url = escape(&meta.url),
        locale = meta.lang.locale(),
    );
    match &meta.image {
        Some(image) => {
            tags.push_str(&format!(
                "  <meta property=\"og:image\" content=\"{image}\">\n\
                 \x20 <meta name=\"twitter:card\" content=\"summary_large_image\">\n",
                image = escape(image),
            ));
        }
        // Without an image a large card renders as an empty grey box, so ask
        // for the small one.
        None => tags.push_str("  <meta name=\"twitter:card\" content=\"summary\">\n"),
    }
    tags.push_str(&format!(
        "  <meta name=\"twitter:title\" content=\"{title}\">\n\
         \x20 <meta name=\"twitter:description\" content=\"{description}\">\n",
        title = escape(&meta.title),
        description = escape(&meta.description),
    ));
    tags
}

fn replace_title(html: &str, title: &str) -> String {
    let Some(open) = html.find("<title>") else {
        return html.to_string();
    };
    let Some(close) = html[open..].find("</title>").map(|at| open + at) else {
        return html.to_string();
    };
    let mut out = String::with_capacity(html.len() + title.len());
    out.push_str(&html[..open + "<title>".len()]);
    out.push_str(&escape(title));
    out.push_str(&html[close..]);
    out
}

/// Drops the template's own `<meta name="description">`; ours replaces it.
fn strip_description(html: &str) -> String {
    let lower = html.to_ascii_lowercase();
    let Some(start) = lower.find("<meta name=\"description\"") else {
        return html.to_string();
    };
    let Some(end) = html[start..].find('>').map(|at| start + at + 1) else {
        return html.to_string();
    };
    let mut out = String::with_capacity(html.len());
    out.push_str(&html[..start]);
    out.push_str(html[end..].trim_start_matches([' ', '\t']));
    out
}

/// Sets `<html lang="…">` so screen readers and search engines get the language
/// the page is actually served in.
fn set_html_lang(html: &str, code: &str) -> String {
    let Some(start) = html.find("<html") else {
        return html.to_string();
    };
    let Some(end) = html[start..].find('>').map(|at| start + at) else {
        return html.to_string();
    };
    if html[start..end].contains("lang=") {
        return html.to_string();
    }
    let mut result = html.to_string();
    result.insert_str(end, &format!(" lang=\"{code}\""));
    result
}

/// Minimal escaping for text that ends up inside a double-quoted attribute.
fn escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::meta::Lang;

    const TEMPLATE: &str = r#"<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="description" content="Стандардни опис.">
  <title>saobracaj</title>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
"#;

    fn meta(title: &str, description: &str, image: Option<&str>) -> PageMeta {
        PageMeta {
            title: title.to_string(),
            description: description.to_string(),
            image: image.map(str::to_string),
            url: "https://saobracaj.gleb.at/question/11".to_string(),
            lang: Lang::Sr,
        }
    }

    #[test]
    fn writes_the_pages_own_title_and_description() {
        let html = render(TEMPLATE, &meta("Питање бр. 11", "Пешак је приказан:", None));

        assert!(html.contains("<title>Питање бр. 11</title>"));
        assert!(html.contains(r#"<meta property="og:title" content="Питање бр. 11">"#));
        assert!(html.contains(r#"<meta property="og:description" content="Пешак је приказан:">"#));
        assert!(html.contains(r#"<link rel="canonical" href="https://saobracaj.gleb.at/question/11">"#));
        assert!(html.contains(r#"<html lang="sr">"#));
        // The template's own description is gone — exactly one remains.
        assert!(!html.contains("Стандардни опис."));
        assert_eq!(html.matches("name=\"description\"").count(), 1);
        // Everything below <head> is untouched.
        assert!(html.contains(r#"<script src="flutter_bootstrap.js" async></script>"#));
        assert!(html.contains(r#"<base href="/">"#));
    }

    #[test]
    fn an_image_upgrades_the_card() {
        let with_image = render(
            TEMPLATE,
            &meta("Питање", "Опис", Some("https://saobracaj.gleb.at/a.jpeg")),
        );
        assert!(with_image.contains(r#"<meta property="og:image" content="https://saobracaj.gleb.at/a.jpeg">"#));
        assert!(with_image.contains(r#"content="summary_large_image""#));

        let without = render(TEMPLATE, &meta("Питање", "Опис", None));
        assert!(!without.contains("og:image"));
        assert!(without.contains(r#"content="summary""#));
    }

    #[test]
    fn quotes_in_a_question_cannot_break_out_of_the_attribute() {
        let html = render(TEMPLATE, &meta(r#"A "quoted" <title>"#, "1 & 2", None));

        assert!(html.contains(r#"content="A &quot;quoted&quot; &lt;title&gt;""#));
        assert!(html.contains(r#"content="1 &amp; 2""#));
    }

    #[test]
    fn a_template_without_a_head_is_served_as_is() {
        let html = render("<h1>hi</h1>", &meta("t", "d", None));
        assert_eq!(html, "<h1>hi</h1>");
    }
}
