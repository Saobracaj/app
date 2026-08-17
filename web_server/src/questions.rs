//! The question bank, read out of the served bundle at startup.
//!
//! Two jobs depend on it. A link to a single question is the one link people
//! actually share, so its preview card should show the question instead of the
//! app's generic blurb; and a crawler that cannot run Flutter has to be handed
//! the question as HTML (see [`crate::seo`]). Both read the very files the app
//! itself loads (`assets/assets/allQuestions*.json`, `categories.json`), so
//! nothing has to be duplicated or kept in sync — the server just reads them
//! once on boot.

use std::collections::HashMap;
use std::path::Path;

use serde::Deserialize;

use crate::meta::Lang;

/// Categories that are free for everybody, content and all. Mirrors
/// `freeCategoryIds` in `lib/feature_flags/domain/app_feature.dart` (and
/// `FREE_CATEGORY_IDS` in the backend): only their material may be handed to a
/// crawler in full, everything else stays behind the subscription.
pub const FREE_CATEGORY_IDS: [&str; 3] = ["25", "26", "28"];

/// One answer option.
#[derive(Debug, Clone)]
pub struct Choice {
    pub text: String,
    pub is_correct: bool,
}

/// A question as the page needs it: the preview card uses the text and the
/// illustration, the prerendered page uses everything.
#[derive(Debug, Clone)]
pub struct Question {
    pub id: i64,
    pub text: String,
    pub choices: Vec<Choice>,
    /// Id of the illustration (`assets/img/<id>.jpeg`), when the question has one.
    pub image_id: Option<i64>,
    pub category_id: Option<String>,
    pub subcategory_id: Option<i64>,
}

impl Question {
    pub fn is_free(&self) -> bool {
        self.category_id
            .as_deref()
            .is_some_and(|id| FREE_CATEGORY_IDS.contains(&id.trim()))
    }
}

/// A question category with the blocks it is split into.
#[derive(Debug, Clone, Deserialize)]
pub struct Category {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub subcategories: Vec<Subcategory>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Subcategory {
    #[serde(rename = "Id")]
    pub id: i64,
    #[serde(rename = "Description")]
    pub description: String,
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
    #[serde(rename = "Choices", default)]
    choices: Vec<RawChoice>,
    #[serde(rename = "categoryId", default)]
    category_id: Option<String>,
    #[serde(rename = "subcategoryId", default)]
    subcategory_id: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct RawChoice {
    #[serde(rename = "Text")]
    text: String,
    /// Absent in the translated file — it carries texts only.
    #[serde(rename = "isCorrect", default)]
    is_correct: bool,
}

/// The question bank per language plus the category catalog. Missing files are
/// not fatal: the previews fall back to the app's generic description and the
/// pages are served without their prerendered copy.
#[derive(Debug, Default)]
pub struct Questions {
    serbian: HashMap<i64, Question>,
    russian: HashMap<i64, Question>,
    categories: Vec<Category>,
    /// Question ids per category, in the bank's own order.
    by_category: HashMap<String, Vec<i64>>,
    /// Question ids per block, in the bank's own order.
    by_subcategory: HashMap<i64, Vec<i64>>,
}

impl Questions {
    /// Reads the question files and the category catalog out of a
    /// `flutter build web` output tree.
    pub fn load(web_root: &Path) -> Self {
        let assets = web_root.join("assets").join("assets");
        let serbian: HashMap<i64, Question> = read_questions(&assets.join("allQuestions.json"));
        let russian = read_questions(&assets.join("allQuestions_ru.json"));
        let categories = read_categories(&assets.join("categories.json"));

        // The order the bank ships in is the order the app shows, so the "other
        // questions of this block" list matches what the user would see.
        let mut ordered: Vec<&Question> = serbian.values().collect();
        ordered.sort_by_key(|q| q.id);
        let mut by_category: HashMap<String, Vec<i64>> = HashMap::new();
        let mut by_subcategory: HashMap<i64, Vec<i64>> = HashMap::new();
        for question in ordered {
            if let Some(category) = question.category_id.as_deref() {
                by_category
                    .entry(category.to_string())
                    .or_default()
                    .push(question.id);
            }
            if let Some(subcategory) = question.subcategory_id {
                by_subcategory.entry(subcategory).or_default().push(question.id);
            }
        }

        Self {
            serbian,
            russian,
            categories,
            by_category,
            by_subcategory,
        }
    }

    /// The question for `id` in `lang`.
    ///
    /// Text comes from the translation when there is one — there is no English
    /// translation of the questions, and a Serbian question is far better than
    /// none. Everything the translated file does not carry (the illustration,
    /// which option is the correct one, the category) comes from the original.
    pub fn get(&self, id: i64, lang: Lang) -> Option<Question> {
        let original = self.serbian.get(&id);
        let translated = match lang {
            Lang::Ru => self.russian.get(&id),
            Lang::Sr | Lang::En => None,
        };
        let source = translated.or(original)?;
        let Some(original) = original else {
            return Some(source.clone());
        };
        Some(Question {
            id,
            text: source.text.clone(),
            // The translation lists the options in the original's order, so the
            // answer key is taken by position.
            choices: source
                .choices
                .iter()
                .enumerate()
                .map(|(at, choice)| Choice {
                    text: choice.text.clone(),
                    is_correct: original
                        .choices
                        .get(at)
                        .map_or(choice.is_correct, |c| c.is_correct),
                })
                .collect(),
            image_id: original.image_id,
            category_id: original.category_id.clone(),
            subcategory_id: original.subcategory_id,
        })
    }

    /// Whether everything attached to this question (translations included) is
    /// open to everybody — see [`FREE_CATEGORY_IDS`].
    pub fn is_free(&self, id: i64) -> bool {
        self.serbian.get(&id).is_some_and(Question::is_free)
    }

    pub fn categories(&self) -> &[Category] {
        &self.categories
    }

    pub fn category(&self, id: &str) -> Option<&Category> {
        let id = id.trim();
        self.categories.iter().find(|c| c.id == id)
    }

    /// Question ids of one block, in the order the app shows them.
    pub fn in_subcategory(&self, subcategory_id: i64) -> &[i64] {
        self.by_subcategory
            .get(&subcategory_id)
            .map_or(&[][..], Vec::as_slice)
    }

    /// Question ids of one category, in the order the app shows them.
    pub fn in_category(&self, category_id: &str) -> &[i64] {
        self.by_category
            .get(category_id)
            .map_or(&[][..], Vec::as_slice)
    }

    /// Every question id in the bank, ascending — what the sitemap lists.
    pub fn ids(&self) -> Vec<i64> {
        let mut ids: Vec<i64> = self.serbian.keys().copied().collect();
        ids.sort_unstable();
        ids
    }

    pub fn is_empty(&self) -> bool {
        self.serbian.is_empty() && self.russian.is_empty()
    }
}

fn read_questions(path: &Path) -> HashMap<i64, Question> {
    let Some(parsed) = read_json::<Vec<RawQuestion>>(path) else {
        return HashMap::new();
    };
    parsed
        .into_iter()
        .map(|q| {
            (
                q.qc_id,
                Question {
                    id: q.qc_id,
                    // The source text carries hard line breaks; a preview card
                    // wants one line.
                    text: one_line(&q.text),
                    choices: q
                        .choices
                        .into_iter()
                        .map(|c| Choice {
                            text: one_line(&c.text),
                            is_correct: c.is_correct,
                        })
                        .collect(),
                    image_id: q.has_image.then_some(q.q_id),
                    category_id: q.category_id,
                    subcategory_id: q.subcategory_id,
                },
            )
        })
        .collect()
}

fn read_categories(path: &Path) -> Vec<Category> {
    read_json::<Vec<Category>>(path).unwrap_or_default()
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> Option<T> {
    let raw = match std::fs::read_to_string(path) {
        Ok(raw) => raw,
        Err(error) => {
            tracing::warn!(?path, %error, "missing bundle file — pages fall back to the generic card");
            return None;
        }
    };
    match serde_json::from_str(&raw) {
        Ok(parsed) => Some(parsed),
        Err(error) => {
            tracing::warn!(?path, %error, "unreadable bundle file — pages fall back to the generic card");
            None
        }
    }
}

fn one_line(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
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
    fn reads_texts_image_ids_and_options() {
        let dir = tempfile::tempdir().unwrap();
        write_bundle(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 1, "qId": 42, "Text": "Пешак је приказан\nна сликама:", "HasImage": true,
                 "categoryId": "25", "subcategoryId": 91,
                 "Choices": [{"Text": "тачно", "isCorrect": true}, {"Text": "нетачно", "isCorrect": false}]},
                {"qcId": 2, "qId": 2, "Text": "Друго питање", "HasImage": false, "categoryId": "27", "subcategoryId": 91}]"#,
        );

        let questions = Questions::load(dir.path());

        let first = questions.get(1, Lang::Sr).unwrap();
        assert_eq!(first.text, "Пешак је приказан на сликама:");
        assert_eq!(first.image_id, Some(42));
        assert_eq!(first.choices.len(), 2);
        assert!(first.choices[0].is_correct);
        assert_eq!(first.category_id.as_deref(), Some("25"));
        assert_eq!(questions.get(2, Lang::Sr).unwrap().image_id, None);
        assert!(questions.get(999, Lang::Sr).is_none());

        // Category 25 is free for everybody, 27 is not.
        assert!(questions.is_free(1));
        assert!(!questions.is_free(2));

        assert_eq!(questions.in_subcategory(91), &[1, 2]);
        assert_eq!(questions.in_category("25"), &[1]);
        assert_eq!(questions.ids(), vec![1, 2]);
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
    fn a_translation_keeps_the_originals_illustration_and_answer_key() {
        let dir = tempfile::tempdir().unwrap();
        write_bundle(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 1, "qId": 42, "Text": "Оригинал", "HasImage": true, "categoryId": "25",
                 "Choices": [{"Text": "тачно", "isCorrect": true}, {"Text": "нетачно"}]}]"#,
        );
        // The translated file has texts only — no HasImage, no isCorrect.
        write_bundle(
            dir.path(),
            "allQuestions_ru.json",
            r#"[{"qcId": 1, "qId": 1, "Text": "Перевод", "Choices": [{"Text": "верно"}, {"Text": "неверно"}]}]"#,
        );

        let question = Questions::load(dir.path()).get(1, Lang::Ru).unwrap();

        assert_eq!(question.text, "Перевод");
        assert_eq!(question.image_id, Some(42));
        assert_eq!(question.category_id.as_deref(), Some("25"));
        assert_eq!(question.choices[0].text, "верно");
        assert!(question.choices[0].is_correct);
        assert!(!question.choices[1].is_correct);
    }

    #[test]
    fn reads_the_category_catalog() {
        let dir = tempfile::tempdir().unwrap();
        write_bundle(
            dir.path(),
            "categories.json",
            r#"[{"id": "25", "name": "Основе", "subcategories": [{"Id": 91, "Description": "Основне одредбе"}]}]"#,
        );

        let questions = Questions::load(dir.path());
        let category = &questions.categories()[0];

        assert_eq!(category.id, "25");
        assert_eq!(category.name, "Основе");
        assert_eq!(category.subcategories[0].id, 91);
    }

    #[test]
    fn a_missing_bundle_is_not_fatal() {
        let dir = tempfile::tempdir().unwrap();
        let questions = Questions::load(dir.path());
        assert!(questions.is_empty());
        assert!(questions.categories().is_empty());
        assert!(questions.in_subcategory(91).is_empty());
    }
}
