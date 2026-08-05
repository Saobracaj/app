//! What a shared link should look like when it is pasted somewhere.
//!
//! Chat apps and social networks never run the Flutter app — they fetch the
//! HTML and read the Open Graph tags. Since the app is a single page, every URL
//! would otherwise get the same card ("saobracaj"). This module turns a path
//! into a title/description/image, and [`crate::index_html`] writes them into
//! the served `index.html`.

use crate::questions::Questions;

/// The languages the app ships (`main.dart`: ru, en, sr).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Lang {
    Sr,
    Ru,
    En,
}

impl Lang {
    /// Picks a language from `Accept-Language`. Crawlers usually send nothing,
    /// and the content itself is Serbian — so Serbian is the default.
    pub fn from_accept_language(header: Option<&str>) -> Self {
        let Some(header) = header else { return Lang::Sr };
        for entry in header.split(',') {
            let tag = entry.split(';').next().unwrap_or("").trim().to_ascii_lowercase();
            match tag.split(['-', '_']).next().unwrap_or("") {
                "sr" | "hr" | "bs" => return Lang::Sr,
                "ru" | "uk" | "be" => return Lang::Ru,
                "en" => return Lang::En,
                _ => continue,
            }
        }
        Lang::Sr
    }

    /// The `og:locale` value.
    pub fn locale(self) -> &'static str {
        match self {
            Lang::Sr => "sr_RS",
            Lang::Ru => "ru_RU",
            Lang::En => "en_US",
        }
    }

    pub fn code(self) -> &'static str {
        match self {
            Lang::Sr => "sr",
            Lang::Ru => "ru",
            Lang::En => "en",
        }
    }
}

/// The tags rendered into `<head>` for one request.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PageMeta {
    pub title: String,
    pub description: String,
    /// Absolute URL of the preview image, when the page has a fitting one.
    pub image: Option<String>,
    /// Absolute URL of the page itself.
    pub url: String,
    pub lang: Lang,
}

const SITE_NAME: &str = "Saobraćaj";

fn pick(lang: Lang, sr: &str, ru: &str, en: &str) -> String {
    match lang {
        Lang::Sr => sr,
        Lang::Ru => ru,
        Lang::En => en,
    }
    .to_string()
}

fn default_description(lang: Lang) -> String {
    pick(
        lang,
        "Вежбање испитних теоријских питања из саобраћаја у Србији.",
        "Подготовка к теоретическому экзамену по правилам дорожного движения Сербии.",
        "Practice for the Serbian driving-theory exam.",
    )
}

/// Builds the meta for `path` (already percent-decoded, without the query).
pub fn resolve(
    path: &str,
    origin: &str,
    lang: Lang,
    questions: &Questions,
) -> PageMeta {
    let url = format!("{origin}{}", if path == "/" { "/" } else { path });
    let segments: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();

    let (title, description, image) = match segments.as_slice() {
        // A single question, wherever it is opened from — the discussion link
        // and the same question inside a konspekt.
        [.., "question", id] => question_meta(id, lang, origin, questions),
        // A group invitation. The group's name lives behind an authenticated
        // API call, so the card stays deliberately generic — an invite code is
        // not something to leak into a link preview either.
        ["invite", _token] => (
            pick(
                lang,
                "Позивница у групу",
                "Приглашение в группу",
                "Group invitation",
            ),
            pick(
                lang,
                "Отворите позивницу да бисте се придружили групи у апликацији Saobraćaj.",
                "Откройте приглашение, чтобы вступить в группу в приложении Saobraćaj.",
                "Open the invitation to join a group in Saobraćaj.",
            ),
            None,
        ),
        ["konspekt", ..] => (
            pick(lang, "Конспект", "Конспект", "Study notes"),
            pick(
                lang,
                "Кратак преглед градива по категоријама питања.",
                "Краткий конспект материала по категориям вопросов.",
                "A short summary of the material, by question category.",
            ),
            None,
        ),
        ["zakon", ..] => (
            pick(
                lang,
                "Закон о безбедности саобраћаја",
                "Закон о безопасности дорожного движения",
                "Road-safety law",
            ),
            pick(
                lang,
                "Текст закона уз питања на која се односи.",
                "Текст закона рядом с вопросами, к которым он относится.",
                "The law's text next to the questions it applies to.",
            ),
            None,
        ),
        ["practice", ..] | ["questPractice", ..] => (
            pick(lang, "Симулација испита", "Симуляция экзамена", "Exam simulation"),
            pick(
                lang,
                "Пробни испит по правилима правог испита.",
                "Пробный экзамен по правилам настоящего.",
                "A mock exam that follows the real rules.",
            ),
            None,
        ),
        _ => (SITE_NAME.to_string(), default_description(lang), None),
    };

    PageMeta {
        title: if title == SITE_NAME {
            title
        } else {
            format!("{title} — {SITE_NAME}")
        },
        description,
        image,
        url,
        lang,
    }
}

fn question_meta(
    id: &str,
    lang: Lang,
    origin: &str,
    questions: &Questions,
) -> (String, String, Option<String>) {
    let numeric = id.parse::<i64>().ok();
    let preview = numeric.and_then(|id| questions.get(id, lang));

    let title = match numeric {
        Some(id) => pick(
            lang,
            &format!("Питање бр. {id}"),
            &format!("Вопрос № {id}"),
            &format!("Question #{id}"),
        ),
        None => pick(lang, "Питање", "Вопрос", "Question"),
    };
    let description = preview
        .as_ref()
        .map(|p| p.text.clone())
        .unwrap_or_else(|| default_description(lang));
    // Flutter serves the app's assets one level deeper than they sit in the
    // repository: `assets/img/7935.jpeg` -> `/assets/assets/img/7935.jpeg`.
    let image = preview
        .and_then(|p| p.image_id)
        .map(|image_id| format!("{origin}/assets/assets/img/{image_id}.jpeg"));

    (title, description, image)
}

#[cfg(test)]
mod tests {
    use super::*;

    const ORIGIN: &str = "https://saobracaj.gleb.at";

    #[test]
    fn accept_language_picks_a_supported_language() {
        assert_eq!(Lang::from_accept_language(None), Lang::Sr);
        assert_eq!(Lang::from_accept_language(Some("ru-RU,ru;q=0.9")), Lang::Ru);
        assert_eq!(Lang::from_accept_language(Some("en-GB,en;q=0.8")), Lang::En);
        assert_eq!(Lang::from_accept_language(Some("sr-Latn-RS")), Lang::Sr);
        // Unsupported languages fall back to the language of the content.
        assert_eq!(Lang::from_accept_language(Some("de,fr;q=0.7")), Lang::Sr);
        // The first *supported* entry wins, not the first entry.
        assert_eq!(Lang::from_accept_language(Some("de,ru;q=0.7")), Lang::Ru);
    }

    #[test]
    fn the_root_gets_the_app_card() {
        let meta = resolve("/", ORIGIN, Lang::Sr, &Questions::default());
        assert_eq!(meta.title, "Saobraćaj");
        assert_eq!(meta.url, "https://saobracaj.gleb.at/");
        assert!(meta.image.is_none());
    }

    #[test]
    fn an_invite_card_never_shows_the_code() {
        let meta = resolve("/invite/ABC-DEF-GHI", ORIGIN, Lang::Ru, &Questions::default());
        assert_eq!(meta.title, "Приглашение в группу — Saobraćaj");
        assert!(!meta.description.contains("ABC"));
        assert_eq!(meta.url, "https://saobracaj.gleb.at/invite/ABC-DEF-GHI");
    }

    #[test]
    fn a_question_card_carries_the_question_and_its_illustration() {
        let dir = tempfile::tempdir().unwrap();
        let assets = dir.path().join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(
            assets.join("allQuestions.json"),
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешак је приказан:", "HasImage": true}]"#,
        )
        .unwrap();
        let questions = Questions::load(dir.path());

        let meta = resolve("/question/11", ORIGIN, Lang::Sr, &questions);
        assert_eq!(meta.title, "Питање бр. 11 — Saobraćaj");
        assert_eq!(meta.description, "Пешак је приказан:");
        assert_eq!(
            meta.image.as_deref(),
            Some("https://saobracaj.gleb.at/assets/assets/img/42.jpeg"),
        );

        // The same question opened from a konspekt is the same card.
        let nested = resolve("/konspekt/question/11", ORIGIN, Lang::Sr, &questions);
        assert_eq!(nested.title, meta.title);
        assert_eq!(nested.description, meta.description);
    }

    #[test]
    fn an_unknown_question_still_gets_a_sensible_card() {
        let meta = resolve("/question/999", ORIGIN, Lang::Ru, &Questions::default());
        assert_eq!(meta.title, "Вопрос № 999 — Saobraćaj");
        assert_eq!(meta.description, default_description(Lang::Ru));
        assert!(meta.image.is_none());
    }

    #[test]
    fn unknown_paths_get_the_app_card() {
        let meta = resolve("/whatever/else", ORIGIN, Lang::En, &Questions::default());
        assert_eq!(meta.title, "Saobraćaj");
        assert_eq!(meta.description, default_description(Lang::En));
    }
}
