//! Runtime configuration, read from the environment.
//!
//! Everything has a working default, so the container starts with no
//! environment at all; the deploy sets only what differs from production.

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;

/// How much cross-origin isolation to demand from the browser.
///
/// Isolation (`COOP: same-origin` + `COEP`) unlocks `SharedArrayBuffer`, which
/// buys the multi-threaded Skia renderer and drift's fastest OPFS storage
/// implementation. It also breaks two things this app relies on: Firebase's
/// sign-in popup (killed by `COOP: same-origin`) and any cross-origin resource
/// that doesn't send CORP/CORS headers. Hence the default is `Off`: drift falls
/// back to a slower-but-correct OPFS/IndexedDB implementation on its own, and
/// social sign-in keeps working.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CrossOriginIsolation {
    Off,
    /// `COEP: credentialless` — cross-origin subresources load without
    /// credentials instead of being blocked outright.
    Credentialless,
    /// `COEP: require-corp` — the strictest mode; every cross-origin
    /// subresource must opt in explicitly.
    RequireCorp,
}

impl CrossOriginIsolation {
    fn parse(raw: &str) -> Self {
        match raw.trim().to_ascii_lowercase().as_str() {
            "credentialless" => Self::Credentialless,
            "require-corp" | "require_corp" | "on" | "true" => Self::RequireCorp,
            _ => Self::Off,
        }
    }

    /// The value of the `Cross-Origin-Embedder-Policy` header, if any.
    pub fn coep_header(self) -> Option<&'static str> {
        match self {
            Self::Off => None,
            Self::Credentialless => Some("credentialless"),
            Self::RequireCorp => Some("require-corp"),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Config {
    /// Directory holding the `flutter build web` output.
    pub web_root: PathBuf,
    pub addr: SocketAddr,
    /// Origin the site is reached at, used for `og:url` / `canonical`.
    pub public_origin: String,
    pub cross_origin_isolation: CrossOriginIsolation,
}

impl Config {
    pub fn from_env() -> Self {
        let web_root = env_or("WEB_ROOT", "/srv/web").into();
        let port: u16 = env_var("PORT")
            .and_then(|p| p.parse().ok())
            .unwrap_or(8080);
        let host: IpAddr = env_var("HOST")
            .and_then(|h| h.parse().ok())
            .unwrap_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
        let public_origin = env_or("PUBLIC_ORIGIN", "https://saobracaj.gleb.at")
            .trim_end_matches('/')
            .to_string();
        let cross_origin_isolation =
            CrossOriginIsolation::parse(&env_or("CROSS_ORIGIN_ISOLATION", "off"));

        Self {
            web_root,
            addr: SocketAddr::new(host, port),
            public_origin,
            cross_origin_isolation,
        }
    }
}

fn env_var(key: &str) -> Option<String> {
    std::env::var(key).ok().filter(|v| !v.trim().is_empty())
}

fn env_or(key: &str, default: &str) -> String {
    env_var(key).unwrap_or_else(|| default.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn isolation_defaults_to_off_for_anything_unrecognised() {
        assert_eq!(CrossOriginIsolation::parse(""), CrossOriginIsolation::Off);
        assert_eq!(CrossOriginIsolation::parse("off"), CrossOriginIsolation::Off);
        assert_eq!(CrossOriginIsolation::parse("nonsense"), CrossOriginIsolation::Off);
    }

    #[test]
    fn isolation_reads_the_two_real_modes() {
        assert_eq!(
            CrossOriginIsolation::parse("Credentialless").coep_header(),
            Some("credentialless"),
        );
        assert_eq!(
            CrossOriginIsolation::parse("require-corp").coep_header(),
            Some("require-corp"),
        );
        assert_eq!(CrossOriginIsolation::Off.coep_header(), None);
    }
}
