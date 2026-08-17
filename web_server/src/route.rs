//! What address the browser (or the crawler) actually asked for.
//!
//! The app is a single page: every route below is a path routemaster knows
//! (`lib/routes.dart`), not a file. Parsing it once, here, keeps the metadata
//! ([`crate::meta`]), the prerendered copy ([`crate::seo`]) and the sitemap
//! ([`crate::sitemap`]) from each having their own idea of what `/question/11`
//! is.

/// The addresses worth telling apart.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Route {
    /// `/`, `/index.html`, `/home` — the same screen, one canonical address.
    Home,
    /// `/questions` — the category catalog.
    Questions,
    /// A single question, wherever it is opened from.
    Question { id: i64 },
    /// The law: the whole text, or one article (`/zakon?chapter=I&chlan=2`).
    Zakon {
        chapter: Option<String>,
        chlan: Option<String>,
    },
    /// A category's study notes (`/konspekt?category=25`).
    Konspekt { category: Option<String> },
    /// `/practice` — the exam simulation.
    Practice,
    /// `/about`.
    About,
    /// `/tariffs` — the subscription offer (web only).
    Tariffs,
    /// A group invitation. Public in the sense that anyone with the link can
    /// open it, private in the sense that it must never be indexed.
    Invite,
    /// Everything personal or transient: the account, a test run, a group, a
    /// list, the support chat, the admin screens, an unknown path.
    Private,
}

impl Route {
    /// Parses the request path and query.
    ///
    /// `path` is percent-decoded and `query` is the raw query string.
    pub fn parse(path: &str, query: &str) -> Self {
        let segments: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();
        match segments.as_slice() {
            [] | ["index.html"] | ["home"] => Route::Home,
            ["questions"] => Route::Questions,
            // `/question/11` and `/konspekt/question/11` are the same question;
            // the canonical address below folds them into one.
            [.., "question", id] => match id.parse::<i64>() {
                Ok(id) => Route::Question { id },
                Err(_) => Route::Private,
            },
            ["zakon"] => Route::Zakon {
                chapter: param(query, "chapter"),
                chlan: param(query, "chlan"),
            },
            ["konspekt"] => Route::Konspekt {
                category: param(query, "category"),
            },
            ["practice"] => Route::Practice,
            ["about"] => Route::About,
            ["tariffs"] => Route::Tariffs,
            ["invite", ..] => Route::Invite,
            _ => Route::Private,
        }
    }

    /// The one address this page should be indexed under, relative to the
    /// origin. Two paths that show the same thing (`/question/11` and
    /// `/konspekt/question/11`; `/` and `/home`) share one canonical URL, and
    /// only the parameters that change the content survive into it.
    pub fn canonical_path(&self) -> String {
        match self {
            Route::Home | Route::Private | Route::Invite => "/".to_string(),
            Route::Questions => "/questions".to_string(),
            Route::Question { id } => format!("/question/{id}"),
            Route::Zakon { chapter, chlan } => match (chapter, chlan) {
                (Some(chapter), Some(chlan)) => {
                    format!("/zakon?chapter={}&chlan={}", encode(chapter), encode(chlan))
                }
                (None, Some(chlan)) => format!("/zakon?chlan={}", encode(chlan)),
                _ => "/zakon".to_string(),
            },
            Route::Konspekt { category } => match category {
                Some(category) => format!("/konspekt?category={}", encode(category)),
                None => "/questions".to_string(),
            },
            Route::Practice => "/practice".to_string(),
            Route::About => "/about".to_string(),
            Route::Tariffs => "/tariffs".to_string(),
        }
    }
}

/// The percent-decoded value of one query parameter, if it is there and not
/// empty.
pub fn param(query: &str, name: &str) -> Option<String> {
    query
        .split('&')
        .filter_map(|pair| pair.split_once('='))
        .find(|(key, _)| *key == name)
        .map(|(_, value)| decode(value))
        .filter(|value| !value.trim().is_empty())
}

/// `%D0%B0` -> `а`, `+` -> a space. Invalid sequences are kept verbatim rather
/// than dropped: a mangled address should still be recognisable in the logs.
pub fn decode(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut at = 0;
    while at < bytes.len() {
        match bytes[at] {
            b'%' if at + 2 < bytes.len() => {
                match u8::from_str_radix(&value[at + 1..at + 3], 16) {
                    Ok(byte) => {
                        out.push(byte);
                        at += 3;
                    }
                    Err(_) => {
                        out.push(b'%');
                        at += 1;
                    }
                }
            }
            b'+' => {
                out.push(b' ');
                at += 1;
            }
            byte => {
                out.push(byte);
                at += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// Percent-encodes a query parameter value. Everything outside the unreserved
/// set goes through, because the article numbering is Cyrillic (`2а`).
pub fn encode(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for byte in value.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                out.push(*byte as char)
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_home_screen_answers_to_three_addresses() {
        for path in ["/", "/index.html", "/home"] {
            assert_eq!(Route::parse(path, ""), Route::Home, "{path}");
        }
        assert_eq!(Route::parse("/home", "").canonical_path(), "/");
    }

    #[test]
    fn a_question_is_the_same_page_wherever_it_is_opened_from() {
        let direct = Route::parse("/question/11", "comments=1");
        let from_konspekt = Route::parse("/konspekt/question/11", "");

        assert_eq!(direct, Route::Question { id: 11 });
        assert_eq!(from_konspekt, direct);
        // The discussion parameters do not make a second address out of it.
        assert_eq!(direct.canonical_path(), "/question/11");
    }

    #[test]
    fn a_law_article_keeps_the_parameters_that_pick_it() {
        let article = Route::parse("/zakon", "chapter=I&chlan=2%D0%B0&paragraph=3");
        assert_eq!(
            article,
            Route::Zakon {
                chapter: Some("I".to_string()),
                chlan: Some("2а".to_string()),
            }
        );
        // The paragraph only scrolls, so it is not part of the address.
        assert_eq!(article.canonical_path(), "/zakon?chapter=I&chlan=2%D0%B0");
        assert_eq!(Route::parse("/zakon", "").canonical_path(), "/zakon");
    }

    #[test]
    fn personal_and_transient_addresses_are_told_apart() {
        assert_eq!(Route::parse("/invite/ABC-DEF", ""), Route::Invite);
        for path in [
            "/settings/profile",
            "/login",
            "/groups/7/feed",
            "/lists/abc",
            "/support/threads/1",
            "/quest",
            "/whatever",
            "/question/not-a-number",
        ] {
            assert_eq!(Route::parse(path, ""), Route::Private, "{path}");
        }
    }

    #[test]
    fn a_konspekt_without_a_category_shows_nothing_of_its_own() {
        assert_eq!(
            Route::parse("/konspekt", "category=25&section=manevri"),
            Route::Konspekt {
                category: Some("25".to_string())
            }
        );
        // The app redirects it to the catalog, so that is where it points.
        assert_eq!(
            Route::parse("/konspekt", "").canonical_path(),
            "/questions"
        );
    }

    #[test]
    fn query_values_survive_a_round_trip() {
        assert_eq!(decode("2%D0%B0"), "2а");
        assert_eq!(decode("a+b"), "a b");
        assert_eq!(decode("100%"), "100%");
        assert_eq!(encode("2а"), "2%D0%B0");
        assert_eq!(encode("I"), "I");
        assert_eq!(param("a=1&b=2", "b").as_deref(), Some("2"));
        assert_eq!(param("a=1&b=", "b"), None);
        assert_eq!(param("a=1", "c"), None);
    }
}
