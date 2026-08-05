//! The two files that let a `https://saobracaj.gleb.at/...` link open the app
//! instead of the browser.
//!
//! Both are compiled into the binary rather than shipped in the Flutter bundle:
//! `flutter build web` does not reliably copy a dot-directory out of `web/`, and
//! Apple's file has no extension, so a static file server would guess its type
//! wrong. Here the content type is ours to state.
//!
//! Neither file is a secret — Google and Apple fetch them anonymously, and both
//! only contain identifiers that ship inside the published apps anyway.

use axum::http::header;
use axum::response::{IntoResponse, Response};

const ASSETLINKS: &str = include_str!("../well_known/assetlinks.json");
const APPLE_APP_SITE_ASSOCIATION: &str = include_str!("../well_known/apple-app-site-association");

/// `/.well-known/assetlinks.json` — Android App Links verification.
pub async fn assetlinks() -> Response {
    json(ASSETLINKS)
}

/// `/.well-known/apple-app-site-association` — iOS Universal Links.
///
/// Apple requires `application/json` and no redirect; nginx passes this path
/// straight through, so what we return here is what Apple sees.
pub async fn apple_app_site_association() -> Response {
    json(APPLE_APP_SITE_ASSOCIATION)
}

fn json(body: &'static str) -> Response {
    (
        [
            (header::CONTENT_TYPE, "application/json"),
            // Both platforms re-fetch these; an hour is short enough to fix a
            // mistake the same day and long enough to be free.
            (header::CACHE_CONTROL, "public, max-age=3600"),
        ],
        body,
    )
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn assetlinks_names_the_published_android_package() {
        let parsed: serde_json::Value = serde_json::from_str(ASSETLINKS).unwrap();
        let target = &parsed[0]["target"];
        // The applicationId from android/app/build.gradle.kts — NOT the
        // namespace, which differs (`at.gleb.saobracaj.saobracaj`).
        assert_eq!(target["package_name"], "at.gleb.saobracaj");
        let fingerprints = target["sha256_cert_fingerprints"].as_array().unwrap();
        assert!(!fingerprints.is_empty());
        for fingerprint in fingerprints {
            let value = fingerprint.as_str().unwrap();
            assert_eq!(value.split(':').count(), 32, "SHA-256 is 32 bytes: {value}");
            assert_eq!(value.to_ascii_uppercase(), value, "must be upper case: {value}");
        }
    }

    #[test]
    fn apple_file_names_the_team_prefixed_app_id_and_covers_invites() {
        let parsed: serde_json::Value = serde_json::from_str(APPLE_APP_SITE_ASSOCIATION).unwrap();
        let details = &parsed["applinks"]["details"][0];
        assert_eq!(details["appIDs"][0], "BHH5379JU2.at.gleb.saobracaj.saobracaj");
        let paths: Vec<&str> = details["components"]
            .as_array()
            .unwrap()
            .iter()
            .map(|c| c["/"].as_str().unwrap())
            .collect();
        assert!(paths.contains(&"/invite/*"), "invite links are the point: {paths:?}");
    }
}
