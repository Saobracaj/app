#!/usr/bin/env bash
# Writes sitemap-dates.json into the web bundle: the date of the last commit
# that touched each source the sitemap's pages are built from. The web server
# puts these into <lastmod> (web_server/src/dates.rs) — dates that come from
# the content, not from the deploy, are the only ones Google keeps trusting.
#
# Needs the full history (actions/checkout with fetch-depth: 0): on a shallow
# clone every file was "last changed" in the one commit there is.
#
#   tool/sitemap_dates.sh            # -> build/web/sitemap-dates.json
#   tool/sitemap_dates.sh some/path  # -> that file
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-build/web/sitemap-dates.json}"

last() { git log -1 --format=%cs -- "$@"; }   # committer date, YYYY-MM-DD

questions="$(last assets/allQuestions.json assets/allQuestions_ru.json assets/categories.json)"
law="$(last assets/parsed_zakon.json)"
pages="$(last web_server/src)"

mkdir -p "$(dirname "$out")"
printf '{"questions":"%s","law":"%s","pages":"%s"}\n' "$questions" "$law" "$pages" > "$out"
echo "sitemap dates: $(cat "$out")"
