//! What a page should look like when it is pasted somewhere — or crawled.
//!
//! Chat apps and social networks never run the Flutter app — they fetch the
//! HTML and read the Open Graph tags; a search engine reads the title, the
//! description and `robots` from the same `<head>`. Since the app is a single
//! page, every URL would otherwise get the same card ("saobracaj"). This module
//! turns a [`Route`] into a title/description/image plus the one address the
//! page should be indexed under, and [`crate::index_html`] writes them into the
//! served `index.html`.

use crate::questions::Questions;
use crate::route::Route;
use crate::zakon::Law;

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
        let Some(header) = header else {
            return Lang::Sr;
        };
        for entry in header.split(',') {
            let tag = entry
                .split(';')
                .next()
                .unwrap_or("")
                .trim()
                .to_ascii_lowercase();
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
    /// Absolute URL this page should be indexed under — the same one for every
    /// address that shows it (see [`Route::canonical_path`]).
    pub url: String,
    pub lang: Lang,
    /// Whether a search engine should keep the page at all. Personal screens
    /// (the account, a group, an invitation) and paywalled ones say no.
    pub indexable: bool,
}

pub const SITE_NAME: &str = "Saobraćaj";

pub fn pick(lang: Lang, sr: &str, ru: &str, en: &str) -> String {
    match lang {
        Lang::Sr => sr,
        Lang::Ru => ru,
        Lang::En => en,
    }
    .to_string()
}

pub fn default_description(lang: Lang) -> String {
    pick(
        lang,
        "Вежбање испитних теоријских питања из саобраћаја у Србији.",
        "Подготовка к теоретическому экзамену по правилам дорожного движения Сербии.",
        "Practice for the Serbian driving-theory exam.",
    )
}

/// The keyword-bearing title of the home page — what the site is, in the
/// words people search with. Cyrillic in the title, Latin in the description
/// ([`home_description`]): a Serbian search is typed in either script.
pub fn home_title(lang: Lang) -> String {
    pick(
        lang,
        "Тест за возачки испит: испитна питања са одговорима и симулација испита",
        "Экзамен на водительские права в Сербии: вопросы теста ПДД на русском",
        "Serbian driving theory test: exam questions with answers in English",
    )
}

pub fn home_description(lang: Lang, question_count: usize) -> String {
    pick(
        lang,
        &format!(
            "Testovi za vozački ispit (B kategorija): {question_count} zvaničnih ispitnih pitanja \
             sa tačnim odgovorima, simulacija teorijskog ispita od 41 pitanja, saobraćajni znakovi \
             i Zakon o bezbednosti saobraćaja. Besplatno, bez registracije."
        ),
        &format!(
            "Подготовка к теоретическому экзамену на права в Сербии: {question_count} официальных \
             вопросов с ответами и переводом на русский, симуляция экзамена (41 вопрос, 45 минут), \
             дорожные знаки и закон о безопасности движения. Автошкола в Белграде, Нови-Саде, Нише."
        ),
        &format!(
            "Prepare for the Serbian driving licence theory exam: {question_count} official \
             questions with answers translated into English, a mock exam (41 questions, 45 minutes), \
             road signs and the road-traffic safety law. Free, no sign-up."
        ),
    )
}

/// Builds the meta for a parsed route.
pub fn resolve(
    route: &Route,
    origin: &str,
    lang: Lang,
    questions: &Questions,
    law: &Law,
) -> PageMeta {
    let url = format!("{origin}{}", route.canonical_path());
    let question_count = questions.ids().len();

    let (title, description, image) = match route {
        Route::Question { id } => question_meta(*id, lang, origin, questions),
        Route::Questions => (
            pick(
                lang,
                "Испитна питања за возачки испит по категоријама",
                "Вопросы экзамена на права в Сербии по категориям",
                "Serbian driving test questions by category",
            ),
            pick(
                lang,
                &format!(
                    "Свих {question_count} питања са теоријског испита за возачку дозволу, по \
                     категоријама и областима, са тачним одговорима. Ispitna pitanja za vozački \
                     ispit sa odgovorima."
                ),
                &format!(
                    "Все {question_count} вопросов теоретического экзамена на водительские права \
                     в Сербии по категориям и темам, с правильными ответами."
                ),
                &format!(
                    "All {question_count} questions of the Serbian driving theory exam, by category \
                     and topic, with the correct answers."
                ),
            ),
            None,
        ),
        Route::Zakon { chlan, .. } => zakon_meta(chlan.as_deref(), lang, law),
        Route::Konspekt { category } => konspekt_meta(category.as_deref(), lang, questions),
        Route::Invite => (
            // The group's name lives behind an authenticated API call, so the
            // card stays deliberately generic — an invite code is not something
            // to leak into a link preview either.
            pick(lang, "Позивница у групу", "Приглашение в группу", "Group invitation"),
            pick(
                lang,
                "Отворите позивницу да бисте се придружили групи у апликацији Saobraćaj.",
                "Откройте приглашение, чтобы вступить в группу в приложении Saobraćaj.",
                "Open the invitation to join a group in Saobraćaj.",
            ),
            None,
        ),
        Route::Practice => (
            pick(
                lang,
                "Симулација теоријског испита за возачку дозволу",
                "Симуляция теоретического экзамена на права в Сербии",
                "Serbian driving theory exam simulation",
            ),
            pick(
                lang,
                "Пробни испит по правилима правог: 41 питање, 45 минута, за пролаз треба 85 од \
                 100 поена. Simulacija teorijskog ispita za vozački ispit — besplatno, bez registracije.",
                "Пробный экзамен по правилам настоящего: 41 вопрос, 45 минут, для сдачи нужно 85 из \
                 100 баллов. Бесплатно, без регистрации.",
                "A mock exam that follows the real rules: 41 questions, 45 minutes, 85 of 100 points \
                 to pass. Free, no sign-up.",
            ),
            None,
        ),
        Route::About => (
            pick(
                lang,
                "О апликацији Saobraćaj — тестови за возачки испит",
                "О приложении Saobraćaj — тесты на права в Сербии",
                "About Saobraćaj — Serbian driving test practice",
            ),
            default_description(lang),
            None,
        ),
        Route::Tariffs => (
            pick(lang, "Претплата", "Подписка", "Subscription"),
            pick(
                lang,
                "Пун приступ објашњењима, конспектима и анализи питања.",
                "Полный доступ к объяснениям, конспектам и анализу вопросов.",
                "Full access to the explanations, the study notes and the analysis.",
            ),
            None,
        ),
        Route::Home => (home_title(lang), home_description(lang, question_count), None),
        Route::Private => (SITE_NAME.to_string(), default_description(lang), None),
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
        indexable: indexable(route),
    }
}

/// Whether the page belongs in a search index.
///
/// Two kinds of page do not: the personal ones (an account, a group, a test
/// run, an invitation — nothing there is public, and an indexed invite link is
/// a leak), and the ones whose content is the subscription's (`/konspekt` of a
/// paid category). The free categories' study notes are open to everybody, so
/// they stay in.
pub fn indexable(route: &Route) -> bool {
    match route {
        Route::Home
        | Route::Questions
        | Route::Question { .. }
        | Route::Zakon { .. }
        | Route::Practice
        | Route::About
        | Route::Tariffs => true,
        Route::Konspekt { category } => category
            .as_deref()
            .is_some_and(|id| crate::questions::FREE_CATEGORY_IDS.contains(&id.trim())),
        Route::Invite | Route::Private => false,
    }
}

/// The language a question's *content* may be shown in: the reader's, where
/// the category is free for everybody, and Serbian everywhere else — the
/// translations are what `russian_content` sells.
pub fn content_language(id: i64, lang: Lang, questions: &Questions) -> Lang {
    if questions.is_free(id) {
        lang
    } else {
        Lang::Sr
    }
}

/// The longest a question may be in `<title>`. Google shows about the first
/// 60 characters but ranks on the whole title, and for the road-sign
/// questions the part that matters — the name of the sign — comes after the
/// shared stem, so the cut is generous.
const TITLE_LIMIT: usize = 120;

fn question_meta(
    id: i64,
    lang: Lang,
    origin: &str,
    questions: &Questions,
) -> (String, String, Option<String>) {
    // The Russian text of a question is part of the `russian_content` feature.
    // The description is what a crawler reads (and stores), so outside the free
    // categories it stays in the language the exam is sat in — otherwise a
    // request with `Accept-Language: ru` would walk out with the whole
    // translated bank.
    let question = questions.get(id, content_language(id, lang, questions));

    let Some(question) = question else {
        return (
            pick(
                lang,
                &format!("Питање бр. {id}"),
                &format!("Вопрос № {id}"),
                &format!("Question #{id}"),
            ),
            default_description(lang),
            None,
        );
    };

    // The question itself is the title: that is the text a person searches
    // for, and «Питање бр. 7921» is not. The number stays in the description
    // for the people who have it from the official list.
    let title = shorten(&questions.headline(&question), TITLE_LIMIT);

    let correct: Vec<&str> = question
        .choices
        .iter()
        .filter(|c| c.is_correct)
        .map(|c| c.text.as_str())
        .collect();
    let category = question
        .category_id
        .as_deref()
        .and_then(|id| questions.category(id))
        .map(|c| c.name.trim().to_string());
    let mut description = String::new();
    if !correct.is_empty() {
        description.push_str(&pick(
            lang,
            "Тачан одговор: ",
            "Правильный ответ: ",
            "Correct answer: ",
        ));
        description.push_str(&correct.join("; "));
        if !description.ends_with(['.', '!', '?']) {
            description.push('.');
        }
        description.push(' ');
    }
    description.push_str(&pick(
        lang,
        &format!("Испитно питање бр. {id} за теоријски испит за возачку дозволу (Б категорија)"),
        &format!("Вопрос № {id} теоретического экзамена на водительские права в Сербии"),
        &format!("Question #{id} of the Serbian driving licence theory exam"),
    ));
    if let Some(category) = category {
        description.push_str(&pick(
            lang,
            " — категорија: ",
            " — категория: ",
            " — category: ",
        ));
        description.push_str(&category);
    }
    description.push('.');
    let description = truncate(&description);

    // Flutter serves the app's assets one level deeper than they sit in the
    // repository: `assets/img/7935.jpeg` -> `/assets/assets/img/7935.jpeg`.
    let image = question
        .image_id
        .map(|image_id| format!("{origin}/assets/assets/img/{image_id}.jpeg"));

    (title, description, image)
}

/// Cuts on a word boundary, with an ellipsis, when the text is longer than
/// `limit` characters.
pub fn shorten(value: &str, limit: usize) -> String {
    if value.chars().count() <= limit {
        return value.trim().to_string();
    }
    let cut: String = value.chars().take(limit).collect();
    let cut = cut
        .rsplit_once(' ')
        .map_or(cut.clone(), |(head, _)| head.to_string());
    format!("{}…", cut.trim_end_matches([' ', ',', ':', ';']))
}

fn zakon_meta(chlan: Option<&str>, lang: Lang, law: &Law) -> (String, String, Option<String>) {
    let article = chlan.and_then(|chlan| law.article(chlan));
    let Some(article) = article else {
        return (
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
        );
    };

    let heading = article
        .heading
        .clone()
        .unwrap_or_else(|| format!("Члан {}", article.chlan));
    let title = pick(
        lang,
        &format!("{heading} Закона о безбедности саобраћаја"),
        &format!("{heading} Закона о безопасности дорожного движения"),
        &format!("{heading} of the road-safety law"),
    );
    let description = article
        .summary()
        .map(truncate)
        .unwrap_or_else(|| default_description(lang));
    (title, description, None)
}

fn konspekt_meta(
    category: Option<&str>,
    lang: Lang,
    questions: &Questions,
) -> (String, String, Option<String>) {
    let name = category.and_then(|id| {
        questions
            .categories()
            .iter()
            .find(|c| c.id == id)
            .map(|c| c.name.clone())
    });
    let title = match &name {
        Some(name) => pick(
            lang,
            &format!("Конспект: {name}"),
            &format!("Конспект: {name}"),
            &format!("Study notes: {name}"),
        ),
        None => pick(lang, "Конспект", "Конспект", "Study notes"),
    };
    let description = match &name {
        Some(name) => pick(
            lang,
            &format!("Кратак преглед градива: {name}."),
            &format!("Краткий конспект материала: {name}."),
            &format!("A short summary of the material: {name}."),
        ),
        None => pick(
            lang,
            "Кратак преглед градива по категоријама питања.",
            "Краткий конспект материала по категориям вопросов.",
            "A short summary of the material, by question category.",
        ),
    };
    (title, description, None)
}

/// A description longer than this is cut off by every consumer anyway; cutting
/// it on a word boundary reads better than a snapped-off syllable.
fn truncate(value: &str) -> String {
    const LIMIT: usize = 200;
    if value.chars().count() <= LIMIT {
        return value.to_string();
    }
    let cut: String = value.chars().take(LIMIT).collect();
    let cut = match cut.rsplit_once(' ') {
        Some((head, _)) => head.to_string(),
        None => cut,
    };
    format!("{cut}…")
}

#[cfg(test)]
mod tests {
    use super::*;

    const ORIGIN: &str = "https://saobracaj.gleb.at";

    fn meta_for(path: &str, query: &str, lang: Lang, questions: &Questions) -> PageMeta {
        resolve(
            &Route::parse(path, query),
            ORIGIN,
            lang,
            questions,
            &Law::default(),
        )
    }

    fn bank() -> Questions {
        let dir = tempfile::tempdir().unwrap();
        let assets = dir.path().join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(
            assets.join("allQuestions.json"),
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешак је приказан:", "HasImage": true, "categoryId": "25"},
                {"qcId": 13, "qId": 13, "Text": "Плаћено питање", "categoryId": "27"}]"#,
        )
        .unwrap();
        std::fs::write(
            assets.join("allQuestions_ru.json"),
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешеход показан:"},
                {"qcId": 13, "qId": 13, "Text": "Платный вопрос"}]"#,
        )
        .unwrap();
        std::fs::write(
            assets.join("categories.json"),
            r#"[{"id": "25", "name": "Основе безбедности", "subcategories": []},
                {"id": "27", "name": "Трајање управљања", "subcategories": []}]"#,
        )
        .unwrap();
        Questions::load(dir.path())
    }

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
        let meta = meta_for("/", "", Lang::Sr, &Questions::default());
        assert!(meta.title.starts_with("Тест за возачки испит"));
        assert!(meta.title.ends_with("— Saobraćaj"));
        assert!(meta.description.contains("vozački ispit"));
        assert_eq!(meta.url, "https://saobracaj.gleb.at/");
        assert!(meta.image.is_none());
        assert!(meta.indexable);

        // The same address in the reader's language.
        let ru = meta_for("/", "", Lang::Ru, &Questions::default());
        assert!(ru.title.contains("Сербии"));
        assert_eq!(ru.url, "https://saobracaj.gleb.at/");
    }

    #[test]
    fn an_invite_card_never_shows_the_code_and_is_never_indexed() {
        let meta = meta_for("/invite/ABC-DEF-GHI", "", Lang::Ru, &Questions::default());
        assert_eq!(meta.title, "Приглашение в группу — Saobraćaj");
        assert!(!meta.description.contains("ABC"));
        assert!(!meta.indexable);
        // The address itself must not survive into the canonical link either.
        assert_eq!(meta.url, "https://saobracaj.gleb.at/");
    }

    #[test]
    fn a_question_card_carries_the_question_and_its_illustration() {
        let questions = bank();
        let meta = meta_for("/question/11", "", Lang::Sr, &questions);

        assert_eq!(meta.title, "Пешак је приказан: — Saobraćaj");
        assert!(meta.description.starts_with("Испитно питање бр. 11"));
        assert!(meta.description.contains("Основе безбедности"));
        assert_eq!(
            meta.image.as_deref(),
            Some("https://saobracaj.gleb.at/assets/assets/img/42.jpeg"),
        );
        assert!(meta.indexable);

        // The same question opened from a konspekt is the same card and the
        // same canonical address.
        let nested = meta_for("/konspekt/question/11", "", Lang::Sr, &questions);
        assert_eq!(nested.title, meta.title);
        assert_eq!(nested.url, meta.url);
    }

    #[test]
    fn an_unknown_question_still_gets_a_sensible_card() {
        let meta = meta_for("/question/999", "", Lang::Ru, &Questions::default());
        assert_eq!(meta.title, "Вопрос № 999 — Saobraćaj");
        assert_eq!(meta.description, default_description(Lang::Ru));
        assert!(meta.image.is_none());
    }

    #[test]
    fn a_translation_is_only_shown_where_it_is_free() {
        let questions = bank();

        // Category 25 is free — translations and all.
        let free = meta_for("/question/11", "", Lang::Ru, &questions);
        assert_eq!(free.title, "Пешеход показан: — Saobraćaj");

        // Category 27 is not: `Accept-Language: ru` must not turn the crawler
        // into a way of walking out with the translated bank.
        let paid = meta_for("/question/13", "", Lang::Ru, &questions);
        assert_eq!(paid.title, "Плаћено питање — Saobraćaj");
        assert!(!paid.description.contains("Платный"));
        // The interface language still follows the reader.
        assert!(paid.description.contains("Вопрос № 13"));
    }

    #[test]
    fn private_screens_are_kept_out_of_the_index() {
        for path in ["/settings/profile", "/groups/7/feed", "/login", "/support"] {
            assert!(
                !meta_for(path, "", Lang::Sr, &Questions::default()).indexable,
                "{path}"
            );
        }
    }

    #[test]
    fn only_the_free_categories_notes_may_be_indexed() {
        let questions = bank();

        let free = meta_for("/konspekt", "category=25", Lang::Ru, &questions);
        assert_eq!(free.title, "Конспект: Основе безбедности — Saobraćaj");
        assert!(free.indexable);

        // Paid material is not something to hand to a crawler.
        assert!(!meta_for("/konspekt", "category=27", Lang::Ru, &questions).indexable);
    }

    #[test]
    fn a_law_article_gets_its_own_title_and_first_paragraph() {
        let dir = tempfile::tempdir().unwrap();
        let assets = dir.path().join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(
            assets.join("parsed_zakon.json"),
            r#"[{"chapter": "I", "chlan": "2", "paragraph": "0", "sr": "Члан 2.", "ru": "Статья 2."},
                {"chapter": "I", "chlan": "2", "paragraph": "1", "sr": "Контролу саобраћаја врши Министарство.", "ru": "…"}]"#,
        )
        .unwrap();
        let law = Law::load(dir.path());

        let meta = resolve(
            &Route::parse("/zakon", "chapter=I&chlan=2"),
            ORIGIN,
            Lang::Sr,
            &Questions::default(),
            &law,
        );

        assert_eq!(
            meta.title,
            "Члан 2. Закона о безбедности саобраћаја — Saobraćaj"
        );
        assert_eq!(meta.description, "Контролу саобраћаја врши Министарство.");
        assert_eq!(
            meta.url,
            "https://saobracaj.gleb.at/zakon?chapter=I&chlan=2"
        );
        assert!(meta.indexable);
    }

    #[test]
    fn the_correct_answer_leads_the_description() {
        let dir = tempfile::tempdir().unwrap();
        let assets = dir.path().join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(
            assets.join("allQuestions.json"),
            r#"[{"qcId": 7921, "qId": 7921, "Text": "Непосредно регулисање саобраћаја на путевима врше:", "categoryId": "25",
                 "Choices": [{"Text": "инспектори", "isCorrect": false}, {"Text": "униформисани полицијски службеници", "isCorrect": true}]},
                {"qcId": 2, "qId": 2, "Text": "Веома дугачко питање које се протеже далеко преко границе наслова, наставља се и наставља без краја, и мора бити скраћено на реч а не на слог, зар не?",
                 "Choices": []}]"#,
        )
        .unwrap();
        let questions = Questions::load(dir.path());

        let meta = meta_for("/question/7921", "", Lang::Sr, &questions);
        assert_eq!(
            meta.title,
            "Непосредно регулисање саобраћаја на путевима врше: — Saobraćaj"
        );
        assert_eq!(
            meta.description,
            "Тачан одговор: униформисани полицијски службеници. Испитно питање бр. 7921 за теоријски испит за возачку дозволу (Б категорија)."
        );

        let long = meta_for("/question/2", "", Lang::En, &questions);
        assert!(long.title.chars().count() <= TITLE_LIMIT + " — Saobraćaj".chars().count() + 1);
        assert!(long.title.contains("…"));
        assert_eq!(
            long.description,
            "Question #2 of the Serbian driving licence theory exam."
        );
    }

    #[test]
    fn questions_that_share_a_text_are_told_apart_by_their_answer() {
        let dir = tempfile::tempdir().unwrap();
        let assets = dir.path().join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(
            assets.join("allQuestions.json"),
            r#"[{"qcId": 1, "qId": 1, "Text": "Саобраћајни знак приказан на слици означава:", "HasImage": true,
                 "Choices": [{"Text": "забрану саобраћаја у оба смера", "isCorrect": true}, {"Text": "пут са првенством пролаза", "isCorrect": false}]},
                {"qcId": 2, "qId": 2, "Text": "Саобраћајни знак приказан на слици означава:", "HasImage": true,
                 "Choices": [{"Text": "забрану саобраћаја у оба смера", "isCorrect": false}, {"Text": "пут са првенством пролаза", "isCorrect": true}]},
                {"qcId": 3, "qId": 3, "Text": "Једино питање са овим текстом", "Choices": [{"Text": "да", "isCorrect": true}]}]"#,
        )
        .unwrap();
        let questions = Questions::load(dir.path());

        let first = meta_for("/question/1", "", Lang::Sr, &questions);
        let second = meta_for("/question/2", "", Lang::Sr, &questions);
        assert_eq!(
            first.title,
            "Саобраћајни знак приказан на слици означава: забрану саобраћаја у оба смера — Saobraćaj"
        );
        assert_ne!(first.title, second.title);
        // A question of its own keeps its plain text.
        let alone = meta_for("/question/3", "", Lang::Sr, &questions);
        assert_eq!(alone.title, "Једино питање са овим текстом — Saobraćaj");
    }

    #[test]
    fn a_long_description_is_cut_on_a_word() {
        let long = "реч ".repeat(100);
        let cut = truncate(&long);
        assert!(cut.chars().count() <= 201);
        assert!(cut.ends_with('…'));
    }
}
