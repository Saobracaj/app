//! Serves the Flutter web build of Saobraćaj at https://saobracaj.gleb.at.
//!
//! It is a static server with three jobs a plain one cannot do:
//!   * every unknown path returns the app (so `/invite/ABC-DEF-GHI` opens the
//!     invitation instead of a 404);
//!   * the shared link gets a real preview card — title, description and, for a
//!     question, the question itself with its illustration;
//!   * `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`
//!     are served with the content type Google and Apple insist on, which is
//!     what makes the same link open the installed app;
//!   * a search engine gets the page's content as HTML — the app draws itself
//!     on a canvas, so without it there is nothing to index (see [`seo`]) —
//!     plus `robots.txt` and a `sitemap.xml` of every public address.

mod config;
mod fingerprint;
mod index_html;
mod meta;
mod questions;
mod route;
mod seo;
mod server;
mod sitemap;
mod well_known;
mod zakon;

use std::sync::Arc;

use config::Config;
use server::AppState;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=info".into()),
        )
        .init();

    let config = Config::from_env();
    let addr = config.addr;
    tracing::info!(
        web_root = %config.web_root.display(),
        origin = %config.public_origin,
        isolation = ?config.cross_origin_isolation,
        "starting",
    );

    let state = Arc::new(AppState::load(config)?);
    if state.questions.is_empty() {
        // Not fatal, but it means link previews for questions are generic and
        // the question pages have nothing to show a crawler — usually a sign
        // the bundle was copied in without its assets.
        tracing::warn!("no question texts in the bundle; question links get the generic card");
    }
    if state.law.is_empty() {
        tracing::warn!("no law text in the bundle; the law pages are not indexable");
    }

    let listener = tokio::net::TcpListener::bind(addr).await?;
    tracing::info!(%addr, "listening");
    axum::serve(listener, server::app(state))
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

/// Lets `docker compose up -d` replace the container without dropping requests.
async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c().await.ok();
    };
    #[cfg(unix)]
    let terminate = async {
        if let Ok(mut signal) =
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        {
            signal.recv().await;
        }
    };
    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {}
        _ = terminate => {}
    }
    tracing::info!("shutting down");
}
