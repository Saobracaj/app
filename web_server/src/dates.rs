//! When the content was last changed — for `<lastmod>` in the sitemap.
//!
//! Google reads `lastmod` only from sitemaps whose dates turn out to be true:
//! a sitemap that stamps every address with the deploy date is dropped as
//! noise. So the dates here come from the content, not the clock:
//!
//! * the build writes `sitemap-dates.json` into the bundle with the date of
//!   the last commit that touched each source file (see the `build-web` job);
//! * without that file — a local `flutter build web` — the date is the file's
//!   own modification time, which is the best a checkout can say.

use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Deserialize;

/// `YYYY-MM-DD` per group of pages.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContentDates {
    /// `/question/:id`, `/questions`, `/konspekt` — the question bank.
    pub questions: String,
    /// `/zakon` and its articles.
    pub law: String,
    /// `/`, `/practice`, `/about`, `/tariffs` — the copy of
    /// those pages lives in this server's source.
    pub pages: String,
}

#[derive(Debug, Deserialize, Default)]
struct RawDates {
    questions: Option<String>,
    law: Option<String>,
    pages: Option<String>,
}

impl ContentDates {
    /// Reads `sitemap-dates.json` out of the bundle, filling any blank from the
    /// modification time of the file that group of pages is built from.
    pub fn load(web_root: &Path) -> Self {
        let raw: RawDates = std::fs::read_to_string(web_root.join("sitemap-dates.json"))
            .ok()
            .and_then(|text| serde_json::from_str(&text).ok())
            .unwrap_or_default();
        let assets = web_root.join("assets").join("assets");
        let today = || format_date(SystemTime::now());
        Self {
            questions: raw
                .questions
                .filter(|d| is_date(d))
                .unwrap_or_else(|| mtime(&assets.join("allQuestions.json")).unwrap_or_else(today)),
            law: raw
                .law
                .filter(|d| is_date(d))
                .unwrap_or_else(|| mtime(&assets.join("parsed_zakon.json")).unwrap_or_else(today)),
            pages: raw
                .pages
                .filter(|d| is_date(d))
                .unwrap_or_else(|| mtime(&web_root.join("index.html")).unwrap_or_else(today)),
        }
    }
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

fn mtime(path: &Path) -> Option<String> {
    std::fs::metadata(path)
        .and_then(|m| m.modified())
        .ok()
        .map(format_date)
}

/// `SystemTime` -> `YYYY-MM-DD` (UTC). Civil-from-days, as in Howard Hinnant's
/// date algorithms; enough to avoid a calendar dependency for one field.
pub fn format_date(time: SystemTime) -> String {
    let secs = time
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let days = secs.div_euclid(86_400);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}-{m:02}-{d:02}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn epoch_seconds_become_a_calendar_date() {
        assert_eq!(format_date(UNIX_EPOCH), "1970-01-01");
        // 2026-09-18T00:00:00Z
        assert_eq!(
            format_date(UNIX_EPOCH + Duration::from_secs(1_789_689_600)),
            "2026-09-18"
        );
        // The last second of a leap day.
        assert_eq!(
            format_date(UNIX_EPOCH + Duration::from_secs(1_709_251_199)),
            "2024-02-29"
        );
    }

    #[test]
    fn the_build_file_wins_and_a_missing_one_falls_back_to_mtime() {
        let dir = tempfile::tempdir().unwrap();
        let assets = dir.path().join("assets").join("assets");
        std::fs::create_dir_all(&assets).unwrap();
        std::fs::write(assets.join("allQuestions.json"), "[]").unwrap();
        std::fs::write(dir.path().join("index.html"), "<html></html>").unwrap();

        let fallback = ContentDates::load(dir.path());
        assert!(is_date(&fallback.questions));
        assert!(is_date(&fallback.law));
        assert!(is_date(&fallback.pages));

        std::fs::write(
            dir.path().join("sitemap-dates.json"),
            r#"{"questions": "2026-08-16", "law": "not a date", "pages": "2026-09-18"}"#,
        )
        .unwrap();
        let dates = ContentDates::load(dir.path());
        assert_eq!(dates.questions, "2026-08-16");
        assert_eq!(dates.pages, "2026-09-18");
        // A value that is not a date is ignored rather than served.
        assert!(is_date(&dates.law));
        assert_ne!(dates.law, "not a date");
    }
}
