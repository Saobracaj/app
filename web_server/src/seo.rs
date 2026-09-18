//! The copy of the page a search engine can read.
//!
//! The app is compiled to WebAssembly and draws itself on a canvas: a crawler
//! that fetches `/question/7921` gets a `<head>`, a bootstrap script and no
//! words at all. Google renders JavaScript, but there is nothing in that
//! rendered DOM to index either — the text lives inside the canvas.
//!
//! So the server writes the page's content into the HTML itself: the question
//! with its options, a law article, the catalog — plus the links that connect
//! them, because a crawler discovers pages by following links and a canvas has
//! none. The block is the same content the app shows and it is served to
//! everybody (no user-agent sniffing — that would be cloaking); the app removes
//! it from the DOM as soon as it has painted its first frame, so for a person
//! it is what fills the screen while the bundle loads.
//!
//! What may go in is decided by the same rule the app and the backend enforce:
//! the questions and the law are free for everybody, the Russian translations
//! and the study notes only in the free categories
//! ([`crate::questions::FREE_CATEGORY_IDS`]). Nothing behind the subscription
//! is prerendered.

use serde_json::json;

use crate::meta::{self, default_description, pick, shorten, Lang, PageMeta, SITE_NAME};
use crate::questions::{Question, Questions};
use crate::route::{encode, Route};
use crate::translit;
use crate::zakon::{Article, Law};

/// Where the apps live; the home page links to them and names them in its
/// structured data. Mirrors `lib/core/store_links.dart`.
pub const PLAY_STORE_URL: &str = "https://play.google.com/store/apps/details?id=at.gleb.saobracaj";
pub const APP_STORE_URL: &str = "https://apps.apple.com/app/id6744607772";

/// The exam as the simulation reproduces it (`lib/test/practice/`): 41
/// questions, 45 minutes, 85 of 100 points to pass.
const EXAM_QUESTIONS: u32 = 41;
const EXAM_MINUTES: u32 = 45;
const EXAM_PASS_POINTS: u32 = 85;

/// How many questions of a block the catalog page links to. The rest are
/// reachable from any question of that block, which lists all of its siblings.
const CATALOG_SAMPLE: usize = 10;

/// How many sibling questions one question page links to.
const SIBLINGS: usize = 24;

/// The id of the injected block — the app removes it by this id.
pub const BLOCK_ID: &str = "seo-prerender";

/// Everything that goes into the served HTML for one request beyond `<head>`.
pub struct Prerender {
    /// The content block, ready to be placed before `</body>`.
    pub body: String,
    /// `application/ld+json` payloads for `<head>`.
    pub json_ld: Vec<String>,
}

/// Builds the prerendered copy of `route`, or `None` when the page has no
/// public content (a personal screen, a paywalled one, an unknown path).
pub fn prerender(
    route: &Route,
    meta: &PageMeta,
    lang: Lang,
    origin: &str,
    questions: &Questions,
    law: &Law,
) -> Option<Prerender> {
    if !meta.indexable {
        return None;
    }
    let (body, json_ld) = match route {
        Route::Home => (
            home(lang, questions),
            vec![
                website(meta),
                organization(origin),
                mobile_application(origin),
                faq_json_ld(lang, questions),
            ],
        ),
        Route::Questions => (catalog(lang, questions), vec![]),
        Route::Question { id } => question_page(*id, lang, origin, questions)?,
        Route::Zakon { chlan: None, .. } => (law_index(lang, law), vec![]),
        Route::Zakon {
            chlan: Some(chlan), ..
        } => law_article(chlan, lang, law, meta)?,
        Route::Konspekt {
            category: Some(category),
        } => konspekt(category, lang, questions)?,
        Route::Practice => (
            simple(
                &pick(lang, "Симулација испита", "Симуляция экзамена", "Exam simulation"),
                &pick(
                    lang,
                    "Пробни испит од 41 питања по правилима правог испита: исти распоред категорија, исти број поена, исто време.",
                    "Пробный экзамен из 41 вопроса по правилам настоящего: тот же расклад категорий, те же баллы, то же время.",
                    "A 41-question mock exam that follows the real rules: the same category profile, the same points, the same clock.",
                ),
                lang,
            ),
            vec![],
        ),
        Route::About => (
            simple(
                &pick(lang, "О апликацији", "О приложении", "About"),
                &default_description(lang),
                lang,
            ),
            vec![],
        ),
        Route::Tariffs => (
            simple(
                &pick(lang, "Претплата", "Подписка", "Subscription"),
                &pick(
                    lang,
                    "Питања и закон су бесплатни за све. Претплата отвара објашњења, конспекте и анализу питања у свим категоријама.",
                    "Вопросы и закон бесплатны для всех. Подписка открывает объяснения, конспекты и анализ вопросов во всех категориях.",
                    "The questions and the law are free for everybody. The subscription opens the explanations, the study notes and the question analysis in every category.",
                ),
                lang,
            ),
            vec![],
        ),
        Route::Konspekt { category: None } | Route::Invite | Route::Private => return None,
    };
    Some(Prerender {
        body: wrap(&body),
        json_ld,
    })
}

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

fn home(lang: Lang, questions: &Questions) -> String {
    let count = questions.ids().len();
    let mut out = String::new();
    out.push_str(&format!("<h1>{}</h1>\n", esc(&meta::home_title(lang))));
    out.push_str(&format!("<p>{}</p>\n", esc(&intro(lang, count))));
    if lang == Lang::Sr {
        // The Latin spelling of what the page is about: a Serbian search is
        // typed in either script, and the bank itself is Cyrillic.
        out.push_str(&format!(
            "<p lang=\"sr-Latn\">{}</p>\n",
            esc(&format!(
                "Testovi za vozački ispit — {count} ispitnih pitanja sa odgovorima, simulacija \
                 teorijskog ispita, saobraćajni znakovi i Zakon o bezbednosti saobraćaja na \
                 putevima. Priprema za polaganje teorijskog dela vozačkog ispita B kategorije u \
                 auto školi, bilo gde u Srbiji: Beograd, Novi Sad, Niš, Kragujevac, Subotica."
            )),
        ));
    }
    out.push_str(&nav(lang));

    out.push_str(&format!(
        "<h2>{}</h2>\n<ul>\n",
        esc(&pick(
            lang,
            "Шта има на сајту",
            "Что есть на сайте",
            "What is here"
        ))
    ));
    for (href, label, text) in offer(lang, count) {
        out.push_str(&format!(
            "<li><a href=\"{href}\">{}</a> — {}</li>\n",
            esc(&label),
            esc(&text)
        ));
    }
    out.push_str("</ul>\n");

    out.push_str(&format!(
        "<h2>{}</h2>\n<p>{}</p>\n",
        esc(&pick(
            lang,
            "Како изгледа теоријски испит",
            "Как проходит теоретический экзамен в Сербии",
            "How the theory exam works",
        )),
        esc(&exam_rules(lang)),
    ));

    if !questions.categories().is_empty() {
        out.push_str(&format!(
            "<h2>{}</h2>\n<ul>\n",
            esc(&pick(
                lang,
                "Категорије питања",
                "Категории вопросов",
                "Question categories"
            ))
        ));
        for category in questions.categories() {
            let count = questions.in_category(&category.id).len();
            if count == 0 {
                continue;
            }
            let href = if is_free(&category.id) {
                format!("/konspekt?category={}", encode(&category.id))
            } else {
                "/questions".to_string()
            };
            out.push_str(&format!(
                "<li><a href=\"{href}\">{name}</a> — {count} {word}</li>\n",
                name = esc(category.name.trim()),
                word = esc(&pick(lang, "питања", "вопросов", "questions")),
            ));
        }
        out.push_str("</ul>\n");
    }

    out.push_str(&format!(
        "<h2>{}</h2>\n",
        esc(&pick(
            lang,
            "Честа питања",
            "Частые вопросы",
            "Frequently asked questions"
        ))
    ));
    for (question, answer) in faq(lang, questions) {
        out.push_str(&format!(
            "<h3>{}</h3>\n<p>{}</p>\n",
            esc(&question),
            esc(&answer)
        ));
    }

    out.push_str(&format!(
        "<h2>{}</h2>\n<p>{} <a href=\"{PLAY_STORE_URL}\">Google Play</a> · <a href=\"{APP_STORE_URL}\">App Store</a></p>\n",
        esc(&pick(lang, "Апликација", "Приложение", "The app")),
        esc(&pick(
            lang,
            "Иста питања и симулација, са напретком који се чува на телефону, без интернета:",
            "Те же вопросы и симуляция экзамена в приложении, прогресс сохраняется на телефоне, работает без интернета:",
            "The same questions and mock exam in the app, with your progress kept on the phone and no connection needed:",
        )),
    ));

    // The same page carries a short version of itself in the other two
    // languages. One address serves every language (the app picks it from
    // the browser), and a crawler asks for none — so without this the site
    // would be found for Serbian searches only. Each block is marked with
    // its language, and the FAQ in the structured data stays in the page's
    // own language.
    for other in [Lang::Sr, Lang::Ru, Lang::En] {
        if other == lang {
            continue;
        }
        out.push_str(&format!("<section lang=\"{}\">\n", other.code()));
        out.push_str(&format!("<h2>{}</h2>\n", esc(&meta::home_title(other))));
        out.push_str(&format!("<p>{}</p>\n", esc(&intro(other, count))));
        out.push_str(&format!("<p>{}</p>\n", esc(&exam_rules(other))));
        for (question, answer) in faq(other, questions) {
            out.push_str(&format!(
                "<h3>{}</h3>\n<p>{}</p>\n",
                esc(&question),
                esc(&answer)
            ));
        }
        out.push_str("</section>\n");
    }
    out
}

fn intro(lang: Lang, count: usize) -> String {
    pick(
        lang,
        &format!(
            "Saobraćaj је бесплатна припрема за теоријски део возачког испита у Србији: свих \
             {count} званичних испитних питања за Б категорију са тачним одговорима, симулација \
             испита по правилима правог, саобраћајни знакови и цео текст Закона о безбедности \
             саобраћаја на путевима уз питања на која се односи. Без регистрације, у прегледачу \
             или у апликацији за Android и iPhone."
        ),
        &format!(
            "Saobraćaj — бесплатная подготовка к теоретическому экзамену на водительские права в \
             Сербии: все {count} официальных экзаменационных вопроса категории B с правильными \
             ответами и переводом на русский, симуляция экзамена по правилам настоящего, дорожные \
             знаки и полный текст закона о безопасности дорожного движения рядом с вопросами, к \
             которым он относится. Экзамен в автошколе сдаётся на сербском, поэтому каждый вопрос \
             показан и в оригинале, и в переводе. Без регистрации, в браузере или в приложении для \
             Android и iPhone."
        ),
        &format!(
            "Saobraćaj is free practice for the theory part of the Serbian driving test: all {count} \
             official category B exam questions with the correct answers and an English translation, \
             a mock exam under the real rules, road signs and the full text of the road-traffic safety \
             law next to the questions it applies to. The exam is sat in Serbian, so every question is \
             shown in the original as well as in translation. No sign-up, in the browser or in the \
             Android and iPhone app."
        ),
    )
}

fn offer(lang: Lang, count: usize) -> Vec<(&'static str, String, String)> {
    vec![
        (
            "/questions",
            pick(lang, "Испитна питања", "Экзаменационные вопросы", "Exam questions"),
            pick(
                lang,
                &format!("свих {count} питања по категоријама и областима, свако са тачним одговором"),
                &format!("все {count} вопросов по категориям и темам, каждый с правильным ответом и переводом"),
                &format!("all {count} questions by category and topic, each with the correct answer and a translation"),
            ),
        ),
        (
            "/practice",
            pick(lang, "Симулација испита", "Симуляция экзамена", "Mock exam"),
            pick(
                lang,
                "пробни испит од 41 питања за 45 минута, бодује се као прави",
                "пробный экзамен из 41 вопроса на 45 минут, оценивается как настоящий",
                "a 41-question, 45-minute mock exam, scored like the real one",
            ),
        ),
        (
            "/zakon",
            pick(lang, "Закон о безбедности саобраћаја", "Закон о безопасности движения", "The road-traffic safety law"),
            pick(
                lang,
                "пун текст по члановима, свако питање води на члан на који се односи",
                "полный текст по статьям, от каждого вопроса — ссылка на статью, на которой он основан",
                "the full text by article, every question links to the article it is based on",
            ),
        ),
        (
            "/questions",
            pick(lang, "Саобраћајни знакови", "Дорожные знаки", "Road signs"),
            pick(
                lang,
                "сва питања о саобраћајној сигнализацији са сликама",
                "все вопросы о знаках и разметке с картинками",
                "every question on signs and markings, with the pictures",
            ),
        ),
    ]
}

fn exam_rules(lang: Lang) -> String {
    pick(
        lang,
        &format!(
            "Теоријски испит за возачку дозволу полаже се у ауто-школи, на рачунару, и има \
             {EXAM_QUESTIONS} питање из свих области: основе безбедности, правила саобраћаја, \
             саобраћајна сигнализација, возило, возач, пут, превоз терета и лица, возачке дозволе, \
             поступање у случају незгоде. Питања носе различит број поена, укупно 100; за пролаз је \
             потребно најмање {EXAM_PASS_POINTS}. Време је {EXAM_MINUTES} минута. Симулација на \
             овом сајту прати исти распоред категорија, исто бодовање и исто време."
        ),
        &format!(
            "Теоретический экзамен на права (категория B) сдаётся в автошколе, на компьютере, и \
             состоит из {EXAM_QUESTIONS} вопросов по всем темам: основы безопасности, правила движения, \
             дорожные знаки и разметка, автомобиль, водитель, дорога, перевозка грузов и людей, \
             водительские удостоверения, действия при ДТП. Вопросы стоят разное число баллов, всего \
             100; для сдачи нужно набрать не меньше {EXAM_PASS_POINTS}. Время — {EXAM_MINUTES} минут. \
             Симуляция на этом сайте повторяет тот же набор категорий, ту же систему баллов и то же \
             время. Экзамен проходит на сербском языке — в автошколе Белграда, Нови-Сада, Ниша или \
             любого другого города; здесь можно готовиться с переводом на русский."
        ),
        &format!(
            "The theory exam for a category B licence is taken at a driving school, on a computer, \
             and has {EXAM_QUESTIONS} questions across every topic: safety basics, traffic rules, signs \
             and markings, the vehicle, the driver, the road, carrying goods and passengers, driving \
             licences, what to do after an accident. Questions carry different points, 100 in total; \
             at least {EXAM_PASS_POINTS} are needed to pass, in {EXAM_MINUTES} minutes. The mock exam \
             on this site follows the same category profile, the same scoring and the same clock. The \
             exam is sat in Serbian, at a driving school in Belgrade, Novi Sad, Niš or any other town; \
             here you can prepare with an English translation."
        ),
    )
}

fn faq(lang: Lang, questions: &Questions) -> Vec<(String, String)> {
    let count = questions.ids().len();
    vec![
        (
            pick(
                lang,
                "Колико питања има на теоријском испиту за возачку дозволу?",
                "Сколько вопросов на теоретическом экзамене на права в Сербии?",
                "How many questions are on the Serbian driving theory test?",
            ),
            pick(
                lang,
                &format!("{EXAM_QUESTIONS} питање за {EXAM_MINUTES} минута. Питања вреде од једног до више поена, укупно 100, а испит је положен са најмање {EXAM_PASS_POINTS} поена."),
                &format!("{EXAM_QUESTIONS} вопрос за {EXAM_MINUTES} минут. Вопросы стоят от одного до нескольких баллов, всего 100; экзамен сдан, если набрано не меньше {EXAM_PASS_POINTS}."),
                &format!("{EXAM_QUESTIONS} questions in {EXAM_MINUTES} minutes. Questions are worth one to several points, 100 in total, and {EXAM_PASS_POINTS} or more is a pass."),
            ),
        ),
        (
            pick(
                lang,
                "Да ли су ово иста питања као на испиту?",
                "Это те же вопросы, что на экзамене?",
                "Are these the same questions as on the exam?",
            ),
            pick(
                lang,
                &format!("Да. На сајту је свих {count} питања из званичне базе испитних питања за Б категорију коју користе ауто-школе у Србији, са тачним одговорима и сликама."),
                &format!("Да. На сайте все {count} вопросов из официальной базы экзаменационных вопросов категории B, по которой принимают экзамен автошколы Сербии, с правильными ответами и картинками."),
                &format!("Yes. The site has all {count} questions of the official category B question bank used by driving schools in Serbia, with the correct answers and the pictures."),
            ),
        ),
        (
            pick(
                lang,
                "Да ли је вежбање бесплатно?",
                "Подготовка бесплатная?",
                "Is it free?",
            ),
            pick(
                lang,
                "Питања са одговорима, симулација испита и текст закона су бесплатни и не траже регистрацију. Претплата отвара објашњења уз питања, конспекте по категоријама, анализу питања и превод на руски и енглески.",
                "Вопросы с ответами, симуляция экзамена и текст закона бесплатны и не требуют регистрации. Подписка открывает объяснения к вопросам, конспекты по категориям, анализ вопросов и перевод на русский и английский.",
                "The questions with answers, the mock exam and the law are free and need no account. A subscription opens the explanations, the study notes per category, the question analysis and the Russian and English translation.",
            ),
        ),
        (
            pick(
                lang,
                "Могу ли да вежбам на руском или енглеском?",
                "Можно ли готовиться на русском?",
                "Can I prepare in English?",
            ),
            pick(
                lang,
                "Да: интерфејс је на српском, руском и енглеском, а свако питање има превод. Испит се полаже на српском, па је уз превод увек и оригинални текст питања.",
                "Да: интерфейс на русском, а у каждого вопроса есть перевод на русский. Экзамен сдаётся на сербском, поэтому рядом с переводом всегда показан оригинальный текст вопроса — так вы узнаете его на экзамене.",
                "Yes: the interface is in English and every question has an English translation. The exam itself is in Serbian, so the original text is always shown next to the translation — that is what you will see on the day.",
            ),
        ),
        (
            pick(
                lang,
                "Где се полаже теоријски испит?",
                "Где сдают экзамен и как выбрать автошколу?",
                "Where is the exam taken?",
            ),
            pick(
                lang,
                "У ауто-школи у којој похађате обуку — у Београду, Новом Саду, Нишу, Крагујевцу или било ком другом граду у Србији. Овај сајт служи за припрему: вежбајте питања по областима и полажите симулацију док не будете сигурно прелазили 85 поена.",
                "В автошколе, где вы проходите обучение, — в Белграде, Нови-Саде, Нише, Крагуеваце или любом другом городе Сербии; теорию и практику сдают через автошколу, самостоятельно записаться на экзамен нельзя. Этот сайт нужен для подготовки: прорешайте вопросы по темам и сдавайте симуляцию, пока не будете стабильно набирать больше 85 баллов.",
                "At the driving school where you train — in Belgrade, Novi Sad, Niš, Kragujevac or any other town in Serbia; both the theory and the practical exam are taken through a school. This site is for the preparation: work through the questions by topic and take the mock exam until you pass 85 points every time.",
            ),
        ),
    ]
}

fn catalog(lang: Lang, questions: &Questions) -> String {
    let mut out = String::new();
    out.push_str(&format!(
        "<h1>{}</h1>\n<p>{}</p>\n",
        esc(&pick(
            lang,
            "Испитна питања",
            "Экзаменационные вопросы",
            "Exam questions"
        )),
        esc(&pick(
            lang,
            "Све категорије званичних питања са теоријског испита, са тачним одговорима.",
            "Все категории официальных вопросов теоретического экзамена с правильными ответами.",
            "Every category of the official theory-exam questions, with the correct answers.",
        )),
    ));

    for category in questions.categories() {
        out.push_str(&format!("<section>\n<h2>{}</h2>\n", esc(&category.name)));
        if is_free(&category.id) {
            out.push_str(&format!(
                "<p><a href=\"/konspekt?category={id}\">{label}</a></p>\n",
                id = encode(&category.id),
                label = esc(&pick(
                    lang,
                    "Конспект категорије",
                    "Конспект категории",
                    "Study notes"
                )),
            ));
        }
        for subcategory in &category.subcategories {
            let ids = questions.in_subcategory(subcategory.id);
            if ids.is_empty() {
                continue;
            }
            out.push_str(&format!(
                "<h3>{}</h3>\n",
                esc(subcategory.description.trim())
            ));
            out.push_str(&question_list(
                ids.iter().take(CATALOG_SAMPLE).copied(),
                lang,
                questions,
            ));
            if ids.len() > CATALOG_SAMPLE {
                out.push_str(&format!(
                    "<p>{} {}</p>\n",
                    ids.len(),
                    esc(&pick(
                        lang,
                        "питања укупно",
                        "вопросов всего",
                        "questions in total"
                    )),
                ));
            }
        }
        out.push_str("</section>\n");
    }
    out
}

fn question_page(
    id: i64,
    lang: Lang,
    origin: &str,
    questions: &Questions,
) -> Option<(String, Vec<String>)> {
    let content_lang = meta::content_language(id, lang, questions);
    let question = questions.get(id, content_lang)?;
    let category = question
        .category_id
        .as_deref()
        .and_then(|id| questions.category(id));

    let mut out = String::new();
    out.push_str(&breadcrumbs(&[
        ("/", SITE_NAME.to_string()),
        ("/questions", pick(lang, "Питања", "Вопросы", "Questions")),
    ]));
    out.push_str("<article>\n");
    // The question is the heading — it is what people search for. The
    // number, the exam and the category follow as the lead.
    out.push_str(&format!("<h1>{}</h1>\n", esc(&question.text)));
    let subcategory = category.and_then(|category| {
        question.subcategory_id.and_then(|id| {
            category
                .subcategories
                .iter()
                .find(|s| s.id == id)
                .map(|s| s.description.trim().trim_end_matches(';').to_string())
        })
    });
    let mut lead = pick(
        lang,
        &format!("Испитно питање бр. {id} · теоријски испит за возачку дозволу (Б категорија)"),
        &format!(
            "Вопрос № {id} · теоретический экзамен на водительские права в Сербии (категория B)"
        ),
        &format!("Question #{id} · Serbian driving licence theory exam (category B)"),
    );
    if let Some(category) = category {
        lead.push_str(&format!(" · {}", category.name.trim()));
    }
    if let Some(subcategory) = &subcategory {
        lead.push_str(&format!(" · {subcategory}"));
    }
    out.push_str(&format!("<p>{}</p>\n", esc(&lead)));

    if let Some(image_id) = question.image_id {
        out.push_str(&format!(
            "<img src=\"/assets/assets/img/{image_id}.jpeg\" alt=\"{alt}\" loading=\"lazy\">\n",
            alt = esc(&pick(
                lang,
                &format!("Илустрација уз питање бр. {id}"),
                &format!("Иллюстрация к вопросу № {id}"),
                &format!("Illustration for question #{id}"),
            )),
        ));
    }

    if !question.choices.is_empty() {
        out.push_str(&format!(
            "<h2>{}</h2>\n<ul>\n",
            esc(&pick(lang, "Одговори", "Ответы", "Answers"))
        ));
        for choice in &question.choices {
            let mark = if choice.is_correct {
                format!(
                    " — <strong>{}</strong>",
                    esc(&pick(
                        lang,
                        "тачан одговор",
                        "правильный ответ",
                        "correct answer"
                    ))
                )
            } else {
                String::new()
            };
            out.push_str(&format!("<li>{}{mark}</li>\n", esc(&choice.text)));
        }
        out.push_str("</ul>\n");
        let correct: Vec<&str> = question
            .choices
            .iter()
            .filter(|c| c.is_correct)
            .map(|c| c.text.as_str())
            .collect();
        if !correct.is_empty() {
            out.push_str(&format!(
                "<p><strong>{}</strong> {}</p>\n",
                esc(&pick(
                    lang,
                    "Тачан одговор:",
                    "Правильный ответ:",
                    "Correct answer:"
                )),
                esc(&correct.join("; ")),
            ));
        }
    }

    // The same question in Latin script, for the searches typed that way.
    // Only the Serbian text: a Russian translation is Cyrillic too, and
    // transliterating it would produce nonsense.
    if content_lang == Lang::Sr && translit::has_cyrillic(&question.text) {
        out.push_str("<section lang=\"sr-Latn\">\n<h2>Latinicom</h2>\n");
        out.push_str(&format!(
            "<p>{}</p>\n",
            esc(&translit::to_latin(&question.text))
        ));
        if !question.choices.is_empty() {
            out.push_str("<ul>\n");
            for choice in &question.choices {
                let mark = if choice.is_correct {
                    " — <strong>tačan odgovor</strong>"
                } else {
                    ""
                };
                out.push_str(&format!(
                    "<li>{}{mark}</li>\n",
                    esc(&translit::to_latin(&choice.text))
                ));
            }
            out.push_str("</ul>\n");
        }
        out.push_str("</section>\n");
    }

    if let Some(category) = category {
        if is_free(&category.id) {
            out.push_str(&format!(
                "<p><a href=\"/konspekt?category={id}\">{label}</a></p>\n",
                id = encode(&category.id),
                label = esc(&pick(
                    lang,
                    "Конспект ове категорије",
                    "Конспект этой категории",
                    "Study notes for this category",
                )),
            ));
        }
    }
    out.push_str("</article>\n");

    // The sibling list is what makes the bank crawlable at all: from one
    // question every other question of the same block is one link away.
    if let Some(subcategory_id) = question.subcategory_id {
        let siblings: Vec<i64> = questions
            .in_subcategory(subcategory_id)
            .iter()
            .copied()
            .filter(|other| *other != id)
            .take(SIBLINGS)
            .collect();
        if !siblings.is_empty() {
            out.push_str(&format!(
                "<h2>{}</h2>\n",
                esc(&pick(
                    lang,
                    "Друга питања из ове области",
                    "Другие вопросы этой темы",
                    "Other questions on this topic",
                ))
            ));
            out.push_str(&question_list(siblings.into_iter(), lang, questions));
        }
    }
    out.push_str(&nav(lang));

    Some((
        out,
        vec![
            question_json_ld(&question, lang),
            breadcrumb_json_ld(&shorten(&questions.headline(&question), 70), lang, origin),
        ],
    ))
}

fn law_index(lang: Lang, law: &Law) -> String {
    let mut out = String::new();
    out.push_str(&format!(
        "<h1>{}</h1>\n<p>{}</p>\n",
        esc(&pick(
            lang,
            "Закон о безбедности саобраћаја на путевима",
            "Закон о безопасности дорожного движения",
            "The Serbian road-safety law",
        )),
        esc(&pick(
            lang,
            "Пун текст закона по члановима, уз питања на која се односи.",
            "Полный текст закона по статьям, рядом с вопросами, к которым он относится.",
            "The law's full text, article by article, next to the questions it applies to.",
        )),
    ));

    let mut current: Option<&str> = None;
    let mut open = false;
    for article in law.articles() {
        let chapter = article.chapter.as_deref();
        if chapter != current {
            if open {
                out.push_str("</ul>\n");
            }
            if let Some(title) = chapter.and_then(|id| chapter_title(law, id)) {
                out.push_str(&format!("<h2>{}</h2>\n", esc(&title)));
            }
            out.push_str("<ul>\n");
            current = chapter;
            open = true;
        }
        out.push_str(&format!(
            "<li><a href=\"{href}\">{heading}</a>{summary}</li>\n",
            href = esc(&article_href(article)),
            heading = esc(article.heading.as_deref().unwrap_or(&article.chlan)),
            summary = article
                .summary()
                .map(|s| format!(" — {}", esc(&shorten(s, 90))))
                .unwrap_or_default(),
        ));
    }
    if open {
        out.push_str("</ul>\n");
    }
    out
}

fn law_article(
    chlan: &str,
    lang: Lang,
    law: &Law,
    meta: &PageMeta,
) -> Option<(String, Vec<String>)> {
    let at = law
        .articles()
        .iter()
        .position(|a| a.chlan == chlan.trim())?;
    let article = &law.articles()[at];

    let mut out = String::new();
    out.push_str(&breadcrumbs(&[
        ("/", SITE_NAME.to_string()),
        (
            "/zakon",
            pick(
                lang,
                "Закон о безбедности саобраћаја",
                "Закон о безопасности дорожного движения",
                "Road-safety law",
            ),
        ),
    ]));
    out.push_str("<article>\n");
    out.push_str(&format!(
        "<h1>{}</h1>\n",
        esc(article.heading.as_deref().unwrap_or(&article.chlan))
    ));
    if let Some(title) = article
        .chapter
        .as_deref()
        .and_then(|id| chapter_title(law, id))
    {
        out.push_str(&format!("<p>{}</p>\n", esc(&title)));
    }
    for paragraph in &article.paragraphs {
        out.push_str(&format!("<p>{}</p>\n", esc(paragraph)));
    }
    out.push_str("</article>\n<ul>\n");
    if at > 0 {
        out.push_str(&neighbour(lang, &law.articles()[at - 1], true));
    }
    if let Some(next) = law.articles().get(at + 1) {
        out.push_str(&neighbour(lang, next, false));
    }
    out.push_str(&format!(
        "<li><a href=\"/zakon\">{}</a></li>\n</ul>\n",
        esc(&pick(
            lang,
            "Цео текст закона",
            "Полный текст закона",
            "The whole law"
        ))
    ));
    out.push_str(&nav(lang));

    let body = article.paragraphs.join(" ");
    let json_ld = serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "Article",
        "headline": meta.title,
        "inLanguage": "sr",
        "articleBody": shorten(&body, 5000),
        "url": meta.url,
        "isPartOf": {
            "@type": "Legislation",
            "name": "Закон о безбедности саобраћаја на путевима",
        },
    }))
    .ok();
    Some((out, json_ld.into_iter().collect()))
}

fn konspekt(category_id: &str, lang: Lang, questions: &Questions) -> Option<(String, Vec<String>)> {
    let category = questions.category(category_id)?;
    let mut out = String::new();
    out.push_str(&format!(
        "<h1>{}</h1>\n<p>{}</p>\n",
        esc(&pick(
            lang,
            &format!("Конспект: {}", category.name),
            &format!("Конспект: {}", category.name),
            &format!("Study notes: {}", category.name),
        )),
        esc(&pick(
            lang,
            "Градиво ове категорије и питања на која се односи.",
            "Материал этой категории и вопросы, к которым он относится.",
            "The material of this category and the questions it covers.",
        )),
    ));
    if !category.subcategories.is_empty() {
        out.push_str(&format!(
            "<h2>{}</h2>\n<ul>\n",
            esc(&pick(lang, "Области", "Разделы", "Topics"))
        ));
        for subcategory in &category.subcategories {
            out.push_str(&format!(
                "<li>{}</li>\n",
                esc(subcategory.description.trim())
            ));
        }
        out.push_str("</ul>\n");
    }
    let ids = questions.in_category(&category.id);
    if !ids.is_empty() {
        out.push_str(&format!(
            "<h2>{}</h2>\n",
            esc(&pick(
                lang,
                "Питања ове категорије",
                "Вопросы этой категории",
                "Questions in this category",
            ))
        ));
        out.push_str(&question_list(ids.iter().copied(), lang, questions));
    }
    out.push_str(&nav(lang));
    Some((out, vec![]))
}

fn simple(heading: &str, text: &str, lang: Lang) -> String {
    format!(
        "<h1>{}</h1>\n<p>{}</p>\n{}",
        esc(heading),
        esc(text),
        nav(lang)
    )
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// The block as it is written into the page, with the script that takes it out
/// again once the app has painted.
fn wrap(body: &str) -> String {
    format!(
        "<div id=\"{BLOCK_ID}\" style=\"max-width:44rem;margin:0 auto;padding:1.5rem;font-family:system-ui,sans-serif;line-height:1.5\">\n\
         {body}</div>\n\
         <script>\n\
         // Пока грузится бандл, страницу заполняет её же содержимое в HTML —\n\
         // оно и уходит в поисковый индекс. Первый кадр приложения его убирает.\n\
         (function () {{\n\
         \x20 var drop = function () {{\n\
         \x20   var block = document.getElementById('{BLOCK_ID}');\n\
         \x20   if (block) block.remove();\n\
         \x20 }};\n\
         \x20 window.addEventListener('flutter-first-frame', drop);\n\
         \x20 document.addEventListener('flutter-first-frame', drop);\n\
         }})();\n\
         </script>\n"
    )
}

fn nav(lang: Lang) -> String {
    let items = [
        ("/", pick(lang, "Почетна", "Главная", "Home")),
        ("/questions", pick(lang, "Питања", "Вопросы", "Questions")),
        (
            "/practice",
            pick(
                lang,
                "Симулација испита",
                "Симуляция экзамена",
                "Exam simulation",
            ),
        ),
        ("/zakon", pick(lang, "Закон", "Закон", "The law")),
        (
            "/about",
            pick(lang, "О апликацији", "О приложении", "About"),
        ),
    ];
    let mut out = String::from("<nav><ul>\n");
    for (href, label) in items {
        out.push_str(&format!(
            "<li><a href=\"{href}\">{}</a></li>\n",
            esc(&label)
        ));
    }
    out.push_str("</ul></nav>\n");
    out
}

fn breadcrumbs(trail: &[(&str, String)]) -> String {
    let mut out = String::from("<nav>");
    for (at, (href, label)) in trail.iter().enumerate() {
        if at > 0 {
            out.push_str(" › ");
        }
        out.push_str(&format!("<a href=\"{href}\">{}</a>", esc(label)));
    }
    out.push_str("</nav>\n");
    out
}

fn question_list(ids: impl Iterator<Item = i64>, lang: Lang, questions: &Questions) -> String {
    let mut out = String::from("<ul>\n");
    for id in ids {
        let text = questions
            .get(id, meta::content_language(id, lang, questions))
            .map(|q| shorten(&questions.headline(&q), 120))
            .unwrap_or_else(|| format!("#{id}"));
        out.push_str(&format!(
            "<li><a href=\"/question/{id}\">{}</a></li>\n",
            esc(&text)
        ));
    }
    out.push_str("</ul>\n");
    out
}

fn neighbour(lang: Lang, article: &Article, previous: bool) -> String {
    let label = if previous {
        pick(
            lang,
            "Претходни члан",
            "Предыдущая статья",
            "Previous article",
        )
    } else {
        pick(lang, "Следећи члан", "Следующая статья", "Next article")
    };
    format!(
        "<li><a href=\"{href}\">{label}: {heading}</a></li>\n",
        href = esc(&article_href(article)),
        label = esc(&label),
        heading = esc(article.heading.as_deref().unwrap_or(&article.chlan)),
    )
}

fn article_href(article: &Article) -> String {
    match article.chapter.as_deref() {
        Some(chapter) => format!(
            "/zakon?chapter={}&chlan={}",
            encode(chapter),
            encode(&article.chlan)
        ),
        None => format!("/zakon?chlan={}", encode(&article.chlan)),
    }
}

fn chapter_title(law: &Law, chapter: &str) -> Option<String> {
    law.chapter_titles()
        .iter()
        .find(|(id, _)| id == chapter)
        .map(|(_, title)| title.clone())
}

fn is_free(category_id: &str) -> bool {
    crate::questions::FREE_CATEGORY_IDS.contains(&category_id.trim())
}

// ---------------------------------------------------------------------------
// Structured data
// ---------------------------------------------------------------------------

fn question_json_ld(question: &Question, lang: Lang) -> String {
    let accepted: Vec<_> = question
        .choices
        .iter()
        .filter(|c| c.is_correct)
        .map(|c| json!({"@type": "Answer", "text": c.text}))
        .collect();
    let suggested: Vec<_> = question
        .choices
        .iter()
        .filter(|c| !c.is_correct)
        .map(|c| json!({"@type": "Answer", "text": c.text}))
        .collect();
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "Quiz",
        "about": {"@type": "Thing", "name": "Возачки испит — теорија"},
        "hasPart": {
            "@type": "Question",
            "eduQuestionType": "Multiple choice",
            "name": question.text,
            "text": question.text,
            "inLanguage": if question.is_free() { lang.code() } else { Lang::Sr.code() },
            "acceptedAnswer": accepted,
            "suggestedAnswer": suggested,
        },
    }))
    .unwrap_or_default()
}

fn breadcrumb_json_ld(name: &str, lang: Lang, origin: &str) -> String {
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": 1, "name": SITE_NAME, "item": format!("{origin}/")},
            {
                "@type": "ListItem",
                "position": 2,
                "name": pick(lang, "Питања", "Вопросы", "Questions"),
                "item": format!("{origin}/questions"),
            },
            {"@type": "ListItem", "position": 3, "name": name},
        ],
    }))
    .unwrap_or_default()
}

/// The publisher — what a knowledge panel for «Saobraćaj app» is built from:
/// the logo, and the same-entity links that tie the site to the store
/// listings and the source.
pub const GITHUB_URL: &str = "https://github.com/Saobracaj";

fn organization(origin: &str) -> String {
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "Organization",
        "@id": format!("{origin}/#organization"),
        "name": SITE_NAME,
        "url": format!("{origin}/"),
        // 512 px, square: Google asks for at least 112 px and a logo that
        // reads on white.
        "logo": format!("{origin}/icons/Icon-512.png"),
        "sameAs": [PLAY_STORE_URL, APP_STORE_URL, GITHUB_URL],
    }))
    .unwrap_or_default()
}

/// The app card (Google's «Software app» rich result — the one type of card
/// still shown for a site like this). Free, so `offers` carries a zero
/// price; a rating is deliberately absent — an `aggregateRating` has to be
/// backed by real reviews on the page, and inventing one is a manual action.
fn mobile_application(origin: &str) -> String {
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "MobileApplication",
        "name": SITE_NAME,
        "url": format!("{origin}/"),
        "applicationCategory": "EducationalApplication",
        "operatingSystem": "Android, iOS",
        "inLanguage": ["sr", "ru", "en"],
        "installUrl": [PLAY_STORE_URL, APP_STORE_URL],
        "downloadUrl": [PLAY_STORE_URL, APP_STORE_URL],
        "image": format!("{origin}/icons/Icon-512.png"),
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "RSD"},
        "publisher": {"@id": format!("{origin}/#organization")},
    }))
    .unwrap_or_default()
}

fn faq_json_ld(lang: Lang, questions: &Questions) -> String {
    let entries: Vec<_> = faq(lang, questions)
        .into_iter()
        .map(|(question, answer)| {
            json!({
                "@type": "Question",
                "name": question,
                "acceptedAnswer": {"@type": "Answer", "text": answer},
            })
        })
        .collect();
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "inLanguage": lang.code(),
        "mainEntity": entries,
    }))
    .unwrap_or_default()
}

fn website(meta: &PageMeta) -> String {
    serde_json::to_string(&json!({
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": SITE_NAME,
        "url": meta.url,
        "description": meta.description,
        "inLanguage": ["sr", "ru", "en"],
    }))
    .unwrap_or_default()
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

/// Escaping for text that ends up between tags.
pub fn esc(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    const ORIGIN: &str = "https://saobracaj.gleb.at";

    fn bundle() -> tempfile::TempDir {
        let dir = tempfile::tempdir().unwrap();
        write(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешак је приказан:", "HasImage": true,
                 "categoryId": "25", "subcategoryId": 91,
                 "Choices": [{"Text": "на слици А", "isCorrect": true}, {"Text": "на слици Б", "isCorrect": false}]},
                {"qcId": 12, "qId": 12, "Text": "Друго питање из исте области", "categoryId": "25", "subcategoryId": 91,
                 "Choices": [{"Text": "да", "isCorrect": true}]},
                {"qcId": 13, "qId": 13, "Text": "Плаћено питање", "categoryId": "27", "subcategoryId": 120,
                 "Choices": [{"Text": "да", "isCorrect": true}]}]"#,
        );
        write(
            dir.path(),
            "allQuestions_ru.json",
            r#"[{"qcId": 11, "qId": 42, "Text": "Пешеход показан:", "Choices": [{"Text": "на рисунке А"}, {"Text": "на рисунке Б"}]},
                {"qcId": 13, "qId": 13, "Text": "Платный вопрос", "Choices": [{"Text": "да"}]}]"#,
        );
        write(
            dir.path(),
            "categories.json",
            r#"[{"id": "25", "name": "Основе безбедности", "subcategories": [{"Id": 91, "Description": "Основне одредбе"}]},
                {"id": "27", "name": "Трајање управљања", "subcategories": [{"Id": 120, "Description": "Радно време"}]}]"#,
        );
        write(
            dir.path(),
            "parsed_zakon.json",
            r#"[{"chapter": "I", "chlan": null, "paragraph": null, "sr": "I. ОСНОВНЕ ОДРЕДБЕ", "ru": "I."},
                {"chapter": "I", "chlan": "1", "paragraph": "0", "sr": "Члан 1.", "ru": "Статья 1."},
                {"chapter": "I", "chlan": "1", "paragraph": "1", "sr": "Овим законом уређује се систем безбедности.", "ru": "…"},
                {"chapter": "I", "chlan": "2", "paragraph": "0", "sr": "Члан 2.", "ru": "Статья 2."},
                {"chapter": "I", "chlan": "2", "paragraph": "1", "sr": "Контролу саобраћаја врши Министарство.", "ru": "…"}]"#,
        );
        dir
    }

    fn write(root: &Path, name: &str, body: &str) {
        let assets = root.join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(assets.join(name), body).unwrap();
    }

    fn render(path: &str, query: &str, lang: Lang) -> Option<Prerender> {
        let dir = bundle();
        let questions = Questions::load(dir.path());
        let law = Law::load(dir.path());
        let route = Route::parse(path, query);
        let meta = meta::resolve(&route, ORIGIN, lang, &questions, &law);
        prerender(&route, &meta, meta.lang, ORIGIN, &questions, &law)
    }

    #[test]
    fn a_question_page_carries_the_question_its_answers_and_its_neighbours() {
        let page = render("/question/11", "", Lang::Sr).unwrap();

        assert!(page.body.contains("<h1>Пешак је приказан:</h1>"));
        assert!(page.body.contains("Испитно питање бр. 11"));
        assert!(page
            .body
            .contains("на слици А — <strong>тачан одговор</strong>"));
        assert!(page
            .body
            .contains("<strong>Тачан одговор:</strong> на слици А"));
        // The Latin copy, for the searches typed in Latin.
        assert!(page.body.contains("<section lang=\"sr-Latn\">"));
        assert!(page.body.contains("Pešak je prikazan:"));
        assert!(page
            .body
            .contains("na slici A — <strong>tačan odgovor</strong>"));
        // The breadcrumb names the question, not a number.
        assert!(page.json_ld[1].contains("Пешак је приказан:"));
        assert!(page.body.contains("/assets/assets/img/42.jpeg"));
        assert!(page.body.contains("Основе безбедности"));
        // The bank stays crawlable: from one question the rest of its block is
        // one link away.
        assert!(page.body.contains("href=\"/question/12\""));
        assert!(page.body.contains("Друго питање из исте области"));
        // The free category's notes are linked; the answer key is in the
        // structured data.
        assert!(page.body.contains("/konspekt?category=25"));
        assert!(page.json_ld[0].contains("\"acceptedAnswer\""));
        assert!(page.json_ld[0].contains("на слици А"));
        // And the block takes itself out once the app has painted.
        assert!(page.body.contains("flutter-first-frame"));
    }

    #[test]
    fn a_paid_categorys_question_is_prerendered_in_serbian_only() {
        // Category 25 is free, so its Russian translation may be indexed…
        let free = render("/question/11", "", Lang::Ru).unwrap();
        assert!(free.body.contains("Пешеход показан:"));

        // …category 27 is not: the translation is part of the subscription.
        let paid = render("/question/13", "", Lang::Ru).unwrap();
        assert!(paid.body.contains("Плаћено питање"));
        assert!(!paid.body.contains("Платный вопрос"));
        // The question itself is free content, so the page is still there.
        assert!(paid.body.contains("<h1>Плаћено питање</h1>"));
        assert!(paid.body.contains("Вопрос № 13"));
        // A translated question gets no Latin copy — it is not Serbian.
        assert!(!free.body.contains("Latinicom"));
    }

    #[test]
    fn the_home_page_is_a_landing_in_three_languages() {
        let sr = render("/", "", Lang::Sr).unwrap();
        assert!(sr.body.contains("<h1>Тест за возачки испит"));
        assert!(sr.body.contains("Testovi za vozački ispit"));
        assert!(sr.body.contains("Честа питања"));
        assert!(sr.body.contains(PLAY_STORE_URL));
        // The Russian and English copy ride along on the same page…
        assert!(sr.body.contains("<section lang=\"ru\">"));
        assert!(sr.body.contains("автошколе"));
        assert!(sr.body.contains("<section lang=\"en\">"));
        assert!(sr.body.contains("Serbian driving theory test"));
        // Categories link where their questions are; empty ones are skipped.
        assert!(sr
            .body
            .contains("href=\"/konspekt?category=25\">Основе безбедности</a> — 2 питања"));
        assert_eq!(sr.json_ld.len(), 4);
        assert!(sr.json_ld[1].contains("\"Organization\""));
        assert!(sr.json_ld[1].contains("https://saobracaj.gleb.at/icons/Icon-512.png"));
        assert!(sr.json_ld[1].contains(GITHUB_URL));
        assert!(sr.json_ld[2].contains("\"MobileApplication\""));
        assert!(sr.json_ld[2].contains("\"price\":\"0\""));
        assert!(!sr.json_ld[2].contains("aggregateRating"));
        assert!(sr.json_ld[3].contains("FAQPage"));

        // …and a Russian reader gets the Russian page first, Serbian after.
        let ru = render("/", "", Lang::Ru).unwrap();
        assert!(ru
            .body
            .contains("<h1>Экзамен на водительские права в Сербии"));
        assert!(ru.json_ld[3].contains("\"inLanguage\":\"ru\""));
        assert!(ru.body.contains("<section lang=\"sr\">"));
        assert!(!ru.body.contains("lang=\"sr-Latn\""));
    }

    #[test]
    fn the_catalog_links_into_every_block() {
        let page = render("/questions", "", Lang::Sr).unwrap();

        assert!(page.body.contains("Основне одредбе"));
        assert!(page.body.contains("href=\"/question/11\""));
        assert!(page.body.contains("href=\"/question/13\""));
        // Only the free category offers its notes.
        assert!(page.body.contains("/konspekt?category=25"));
        assert!(!page.body.contains("/konspekt?category=27"));
    }

    #[test]
    fn the_law_is_an_index_of_articles_and_a_page_per_article() {
        let index = render("/zakon", "", Lang::Sr).unwrap();
        assert!(index.body.contains("I. ОСНОВНЕ ОДРЕДБЕ"));
        assert!(index.body.contains("href=\"/zakon?chapter=I&amp;chlan=1\""));

        let article = render("/zakon", "chapter=I&chlan=2", Lang::Sr).unwrap();
        assert!(article.body.contains("<h1>Члан 2.</h1>"));
        assert!(article
            .body
            .contains("Контролу саобраћаја врши Министарство."));
        // Its neighbours keep the text walkable.
        assert!(article.body.contains("Претходни члан"));
        assert!(article.json_ld[0].contains("\"Article\""));

        // An article number nobody has has no page of its own.
        assert!(render("/zakon", "chlan=999", Lang::Sr).is_none());
    }

    #[test]
    fn nothing_private_or_paid_is_prerendered() {
        for (path, query) in [
            ("/settings/profile", ""),
            ("/invite/ABC-DEF", ""),
            ("/groups/7/feed", ""),
            ("/konspekt", "category=27"),
        ] {
            assert!(render(path, query, Lang::Sr).is_none(), "{path}?{query}");
        }
    }

    #[test]
    fn a_free_categorys_notes_list_its_questions() {
        let page = render("/konspekt", "category=25", Lang::Ru).unwrap();
        assert!(page.body.contains("Конспект: Основе безбедности"));
        assert!(page.body.contains("href=\"/question/11\""));
        assert!(!page.body.contains("href=\"/question/13\""));
    }

    #[test]
    fn a_question_cannot_break_out_of_the_markup() {
        let dir = tempfile::tempdir().unwrap();
        write(
            dir.path(),
            "allQuestions.json",
            r#"[{"qcId": 1, "qId": 1, "Text": "<script>alert(1)</script> & друго",
                 "Choices": [{"Text": "<b>да</b>", "isCorrect": true}]}]"#,
        );
        let questions = Questions::load(dir.path());
        let law = Law::default();
        let route = Route::parse("/question/1", "");
        let meta = meta::resolve(&route, ORIGIN, Lang::Sr, &questions, &law);

        let page = prerender(&route, &meta, Lang::Sr, ORIGIN, &questions, &law).unwrap();

        assert!(!page.body.contains("<script>alert(1)</script>"));
        assert!(page
            .body
            .contains("&lt;script&gt;alert(1)&lt;/script&gt; &amp; друго"));
        assert!(page.body.contains("&lt;b&gt;да&lt;/b&gt;"));
    }
}
