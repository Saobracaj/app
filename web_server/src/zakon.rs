//! The road-safety law, read out of the served bundle at startup.
//!
//! `assets/assets/parsed_zakon.json` is the same file the app renders on its
//! «Закон» screen: one entry per paragraph, tagged with the chapter and the
//! article it belongs to. Grouped by article it becomes ~380 pages worth of
//! text a search engine can actually index — the app's own screen is a canvas
//! and shows a crawler nothing.
//!
//! Only the Serbian text is used. The Russian translation is part of the
//! `russian_content` feature (premium), so it is not something to hand out to
//! crawlers.

use std::collections::HashMap;
use std::path::Path;

use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct RawEntry {
    chapter: Option<String>,
    /// `"0"` is the article's own heading ("Члан 12."), the rest are its
    /// paragraphs in order.
    paragraph: Option<String>,
    chlan: Option<String>,
    sr: String,
    #[serde(default, rename = "isTitle")]
    is_title: bool,
}

/// One article of the law.
#[derive(Debug, Clone, Default)]
pub struct Article {
    /// The article number as the app addresses it (`?chlan=2а` — the numbering
    /// has amended articles like `2а`, so it is a string, not a number).
    pub chlan: String,
    pub chapter: Option<String>,
    /// The heading ("Члан 2."), when the source carries one.
    pub heading: Option<String>,
    pub paragraphs: Vec<String>,
}

impl Article {
    /// The first line of substance — what a preview card and the meta
    /// description show.
    pub fn summary(&self) -> Option<&str> {
        self.paragraphs.first().map(String::as_str)
    }
}

/// The law, grouped into articles in the order they appear in the text.
#[derive(Debug, Default)]
pub struct Law {
    articles: Vec<Article>,
    /// Article number -> position in [`Law::articles`].
    index: HashMap<String, usize>,
    /// Chapter id -> its title ("I." -> "I. ОСНОВНЕ ОДРЕДБЕ").
    chapter_titles: Vec<(String, String)>,
}

impl Law {
    pub fn load(web_root: &Path) -> Self {
        let path = web_root
            .join("assets")
            .join("assets")
            .join("parsed_zakon.json");
        let raw = match std::fs::read_to_string(&path) {
            Ok(raw) => raw,
            Err(error) => {
                tracing::warn!(?path, %error, "no law file — the law pages are served without their text");
                return Self::default();
            }
        };
        let entries: Vec<RawEntry> = match serde_json::from_str(&raw) {
            Ok(entries) => entries,
            Err(error) => {
                tracing::warn!(?path, %error, "unreadable law file — the law pages are served without their text");
                return Self::default();
            }
        };
        Self::from_entries(entries)
    }

    fn from_entries(entries: Vec<RawEntry>) -> Self {
        let mut articles: Vec<Article> = Vec::new();
        let mut index: HashMap<String, usize> = HashMap::new();
        let mut chapter_titles: Vec<(String, String)> = Vec::new();

        for entry in entries {
            let text = clean(&entry.sr);
            let Some(chlan) = entry.chlan.filter(|c| !c.trim().is_empty()) else {
                // A chapter's own heading: the first chapter-tagged entry with
                // no article on it ("I. ОСНОВНЕ ОДРЕДБЕ").
                if let Some(chapter) = entry.chapter.filter(|_| !entry.is_title) {
                    if !text.is_empty() && !chapter_titles.iter().any(|(id, _)| *id == chapter) {
                        chapter_titles.push((chapter, text));
                    }
                }
                continue;
            };
            if text.is_empty() {
                continue;
            }

            let at = *index.entry(chlan.clone()).or_insert_with(|| {
                articles.push(Article {
                    chlan: chlan.clone(),
                    chapter: entry.chapter.clone(),
                    ..Article::default()
                });
                articles.len() - 1
            });
            let article = &mut articles[at];
            if entry.paragraph.as_deref() == Some("0") && article.heading.is_none() {
                article.heading = Some(text);
            } else {
                article.paragraphs.push(text);
            }
        }

        Self {
            articles,
            index,
            chapter_titles,
        }
    }

    pub fn article(&self, chlan: &str) -> Option<&Article> {
        self.index.get(chlan.trim()).map(|at| &self.articles[*at])
    }

    pub fn articles(&self) -> &[Article] {
        &self.articles
    }

    pub fn chapter_titles(&self) -> &[(String, String)] {
        &self.chapter_titles
    }

    pub fn is_empty(&self) -> bool {
        self.articles.is_empty()
    }
}

/// Turns one source line into plain text.
///
/// The law ships as markdown: bold runs, escaped asterisks, footnote markers
/// and the occasional link into another article. None of that survives into an
/// attribute or a paragraph as-is, and the meaning is in the words.
pub fn clean(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    let mut rest = value;
    while let Some(at) = rest.find('[') {
        // `[текст](zakon?...)` -> `текст`; anything else stays as it is.
        let (before, from_bracket) = rest.split_at(at);
        let Some(close) = from_bracket.find(']') else {
            break;
        };
        if !from_bracket[close + 1..].starts_with('(') {
            out.push_str(before);
            out.push_str(&from_bracket[..close + 1]);
            rest = &from_bracket[close + 1..];
            continue;
        }
        let Some(end) = from_bracket[close..].find(')').map(|to| close + to) else {
            break;
        };
        out.push_str(before);
        out.push_str(&from_bracket[1..close]);
        rest = &from_bracket[end + 1..];
    }
    out.push_str(rest);

    let out = out.replace("<sup>", "").replace("</sup>", "");
    let out = out.replace("**", "").replace("\\*", "*").replace('\\', "");
    out.split_whitespace().collect::<Vec<_>>().join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(chapter: Option<&str>, chlan: Option<&str>, paragraph: Option<&str>, sr: &str) -> RawEntry {
        RawEntry {
            chapter: chapter.map(str::to_string),
            paragraph: paragraph.map(str::to_string),
            chlan: chlan.map(str::to_string),
            sr: sr.to_string(),
            is_title: false,
        }
    }

    fn law() -> Law {
        Law::from_entries(vec![
            entry(None, None, None, "**ЗАКОН**"),
            entry(Some("I"), None, None, "I. ОСНОВНЕ ОДРЕДБЕ"),
            entry(Some("I"), Some("1"), Some("0"), "Члан 1."),
            entry(Some("I"), Some("1"), Some("1"), "**Овим законом уређују се**"),
            entry(Some("I"), Some("1"), Some("2"), "Друга алинеја."),
            entry(Some("I"), Some("2а"), Some("0"), "**Члан 2а<sup>\\*</sup>**"),
            entry(Some("I"), Some("2а"), Some("1"), "Текст члана 2а."),
        ])
    }

    #[test]
    fn groups_the_paragraphs_into_articles() {
        let law = law();

        let first = law.article("1").unwrap();
        assert_eq!(first.heading.as_deref(), Some("Члан 1."));
        assert_eq!(first.paragraphs, ["Овим законом уређују се", "Друга алинеја."]);
        assert_eq!(first.chapter.as_deref(), Some("I"));
        assert_eq!(first.summary(), Some("Овим законом уређују се"));

        // The numbering is not integers: amended articles carry a letter.
        assert_eq!(law.article("2а").unwrap().heading.as_deref(), Some("Члан 2а*"));
        assert_eq!(law.articles().len(), 2);
        assert!(law.article("999").is_none());
    }

    #[test]
    fn keeps_the_chapter_headings_once_each() {
        let law = law();
        assert_eq!(
            law.chapter_titles(),
            [("I".to_string(), "I. ОСНОВНЕ ОДРЕДБЕ".to_string())]
        );
    }

    #[test]
    fn markdown_is_reduced_to_the_words() {
        assert_eq!(clean("**Члан 2а<sup>\\*</sup>**"), "Члан 2а*");
        assert_eq!(clean("Из [статьей 2](zakon?chapter=I&chlan=2) следует"), "Из статьей 2 следует");
        assert_eq!(clean("  два   размака\nи перевод "), "два размака и перевод");
    }

    #[test]
    fn a_missing_file_is_not_fatal() {
        let dir = tempfile::tempdir().unwrap();
        let law = Law::load(dir.path());
        assert!(law.is_empty());
        assert!(law.article("1").is_none());
    }
}
