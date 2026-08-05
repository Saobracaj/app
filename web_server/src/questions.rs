//! The question texts, read out of the served bundle at startup.
//!
//! A link to a single question is the one link people actually share, so its
//! preview card should show the question instead of the app's generic blurb.
//! The texts are already in the bundle we serve (`assets/assets/allQuestions*.json`,
//! the very files the app itself loads), so nothing has to be duplicated or
//! kept in sync — the server just reads them once on boot.

use std::collections::HashMap;
use std::path::Path;

use serde::Deserialize;

use crate::meta::Lang;

/// What a preview card needs about one question.
#[derive(Debug, Clone)]
pub struct QuestionPreview {
    pub text: String,
    /// Id of the illustration (`assets/img/<id>.jpeg`), when the question has one.
    pub image_id: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct RawQuestion {
    /// The id the app routes by (`/question/:id`).
    #[serde(rename = "qcId")]
    qc_id: i64,
    /// The id the illustration is named after — not always the same as `qcId`.
    #[serde(rename = "qId")]
    q_id: i64,
    #[serde(rename = "Text")]
    text: String,
    #[serde(rename = "HasImage", default)]
    has_image: bool,
}

/// Question texts per language. Missing files are not fatal: the previews just
/// fall back to the app's generic description.
#[derive(Debug, Default)]
pub struct Questions {
    serbian: HashMap<i64, QuestionPreview>,
    russian: HashMap<i64, QuestionPreview>,
}

impl Questions {
    /// Reads the two question files out of a `flutter build web` output tree.
    pub fn load(web_root: &Path) -> Self {
        let assets = web_root.join("assets").join("assets");
        Self {
            serbian: read_file(&assets.join("allQuestions.json")),
            russian: read_file(&assets.join("allQuestions_ru.json")),
        }
    }

    /// The preview for `id` in `lang`.
    ///
    /// Text comes from the translation when there is one — there is no English
    /// translation of the questions, and a Serbian question is far better than
    /// none. The illustration always comes from the original: the translated
    /// file carries only texts, no `HasImage`.
    pub fn get(&self, id: i64, lang: Lang) -> Option<QuestionPreview> {
        let original = self.serbian.get(&id);
        let translated = match lang {
            Lang::Ru => self.russian.get(&id),
            Lang::Sr | Lang::En => None,
        };
        let text = translated.or(original)?.text.clone();
        Some(QuestionPreview {
            text,
            image_id: original.and_then(|q| q.image_id),
        })
    }

    pub fn is_empty(&self) -> bool {
        self.serbian.is_empty() && self.russian.is_empty()
    }
}

fn read_file(path: &Path) -> HashMap<i64, QuestionPreview> {
    let raw = match std::fs::read_to_string(path) {
        Ok(raw) => raw,
        Err(error) => {
            tracing::warn!(?path, %error, "no question file — previews will be generic");
            return HashMap::new();
        }
    };
    let parsed: Vec<RawQuestion> = match serde_json::from_str(&raw) {
        Ok(parsed) => parsed,
        Err(error) => {
            tracing::warn!(?path, %error, "unreadable question file — previews will be generic");
            return HashMap::new();
        }
    };
    parsed
        .into_iter()
        .map(|q| {
            (
                q.qc_id,
                QuestionPreview {
                    // The source text carries hard line breaks; a preview card
                    // wants one line.
                    text: q.text.split_whitespace().collect::<Vec<_>>().join(" "),
                    image_id: q.has_image.then_some(q.q_id),
                },
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_bundle(dir: &Path, name: &str, body: &str) {
        let assets = dir.join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(assets.join(name), body).unwrap();
    }

    #[test]
    fn reads_texts_and_image_ids() {
        let dir = tempfile::tempdir().unwrap();
        write_bundle(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 1, "qId": 42, "Text": "Пешак је приказан\nна сликама:", "HasImage": true},
                {"qcId": 2, "qId": 2, "Text": "Друго питање", "HasImage": false}]"#,
        );

        let questions = Questions::load(dir.path());

        let first = questions.get(1, Lang::Sr).unwrap();
        assert_eq!(first.text, "Пешак је приказан на сликама:");
        assert_eq!(first.image_id, Some(42));
        assert_eq!(questions.get(2, Lang::Sr).unwrap().image_id, None);
        assert!(questions.get(999, Lang::Sr).is_none());
    }

    #[test]
    fn russian_falls_back_to_the_serbian_original() {
        let dir = tempfile::tempdir().unwrap();
        write_bundle(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 1, "qId": 1, "Text": "Оригинал"}, {"qcId": 2, "qId": 2, "Text": "Само српски"}]"#,
        );
        write_bundle(
            dir.path(),
            "allQuestions_ru.json",
            r#"[{"qcId": 1, "qId": 1, "Text": "Перевод"}]"#,
        );

        let questions = Questions::load(dir.path());

        assert_eq!(questions.get(1, Lang::Ru).unwrap().text, "Перевод");
        assert_eq!(questions.get(2, Lang::Ru).unwrap().text, "Само српски");
        assert_eq!(questions.get(1, Lang::En).unwrap().text, "Оригинал");
    }

    #[test]
    fn a_translation_keeps_the_originals_illustration() {
        let dir = tempfile::tempdir().unwrap();
        write_bundle(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 1, "qId": 42, "Text": "Оригинал", "HasImage": true}]"#,
        );
        // The translated file has texts only — no HasImage, no qId to speak of.
        write_bundle(
            dir.path(),
            "allQuestions_ru.json",
            r#"[{"qcId": 1, "qId": 1, "Text": "Перевод"}]"#,
        );

        let preview = Questions::load(dir.path()).get(1, Lang::Ru).unwrap();

        assert_eq!(preview.text, "Перевод");
        assert_eq!(preview.image_id, Some(42));
    }

    #[test]
    fn a_missing_bundle_is_not_fatal() {
        let dir = tempfile::tempdir().unwrap();
        assert!(Questions::load(dir.path()).is_empty());
    }
}
