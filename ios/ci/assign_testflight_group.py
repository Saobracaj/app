#!/usr/bin/env python3
"""Attach the freshly uploaded TestFlight build to an internal beta group.

`altool --upload-app` only delivers the binary: the build lands in App Store
Connect with no group at all, so nobody ever sees it in the TestFlight app.
The internal group "Saobracai internal" cannot be used for that — it was
created with "Enable automatic distribution" (Xcode uploads only, manual
assignment is disabled forever) — hence the manually managed group this
script targets.

The script waits until App Store Connect has finished processing the build
(usually 5–15 minutes after upload), then adds it to the group. Internal
groups need no Beta App Review, so the build becomes installable the moment
this succeeds.

Required environment:
  APP_STORE_CONNECT_API_KEY_ID       App Store Connect API key id
  APP_STORE_CONNECT_ISSUER_ID        issuer id for the key
  APP_STORE_CONNECT_API_KEY_CONTENT  the .p8 private key body
  IOS_BUNDLE_ID                      e.g. at.gleb.saobracaj.saobracaj
  VERSION_NAME                       e.g. 1.1.0  (pre-release train)
  BUILD_NUMBER                       e.g. 108    (bundle version)
  TESTFLIGHT_GROUP_NAME              e.g. Internal manual
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT + cryptography, installed by the workflow step

API = "https://api.appstoreconnect.apple.com"
PROCESSING_TIMEOUT_S = 35 * 60
POLL_INTERVAL_S = 60


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"::error::{name} is not set")
    return value


def token() -> str:
    # Apple caps the lifetime at 20 minutes; issue a fresh short-lived token
    # per request instead of tracking expiry.
    now = int(time.time())
    return jwt.encode(
        {"iss": env("APP_STORE_CONNECT_ISSUER_ID"), "iat": now,
         "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        env("APP_STORE_CONNECT_API_KEY_CONTENT"),
        algorithm="ES256",
        headers={"kid": env("APP_STORE_CONNECT_API_KEY_ID")},
    )


def request(method: str, path: str, query: dict | None = None,
            body: dict | None = None) -> dict:
    url = f"{API}{path}"
    if query:
        url += "?" + urllib.parse.urlencode(query)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token()}",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else {}


def request_or_exit(method: str, path: str, query: dict | None = None,
                    body: dict | None = None) -> dict:
    try:
        return request(method, path, query, body)
    except urllib.error.HTTPError as e:
        sys.exit(f"::error::{method} {path} failed with HTTP {e.code}: "
                 f"{e.read().decode(errors='replace')[:2000]}")


def single(kind: str, path: str, query: dict) -> dict:
    items = request_or_exit("GET", path, query).get("data", [])
    if not items:
        sys.exit(f"::error::No {kind} found for {query}")
    return items[0]


def main() -> None:
    bundle_id = env("IOS_BUNDLE_ID")
    version_name = env("VERSION_NAME")
    build_number = env("BUILD_NUMBER")
    group_name = env("TESTFLIGHT_GROUP_NAME")

    app_id = single("app", "/v1/apps", {"filter[bundleId]": bundle_id})["id"]

    # The build shows up in the API a few moments after altool finishes and
    # stays in PROCESSING until Apple has scanned it.
    deadline = time.monotonic() + PROCESSING_TIMEOUT_S
    build = None
    while time.monotonic() < deadline:
        builds = request_or_exit("GET", "/v1/builds", {
            "filter[app]": app_id,
            "filter[version]": build_number,
            "filter[preReleaseVersion.version]": version_name,
            "filter[expired]": "false",
        }).get("data", [])
        state = builds[0]["attributes"]["processingState"] if builds else None
        if state == "VALID":
            build = builds[0]
            break
        if state in ("FAILED", "INVALID"):
            sys.exit(f"::error::Build {version_name}({build_number}) "
                     f"finished processing as {state}")
        print(f"Build {version_name}({build_number}): "
              f"{state or 'not visible yet'}; waiting…", flush=True)
        time.sleep(POLL_INTERVAL_S)
    if build is None:
        sys.exit(f"::error::Build {version_name}({build_number}) was still "
                 f"processing after {PROCESSING_TIMEOUT_S // 60} minutes")

    # A build whose export-compliance question is unanswered sits in "Missing
    # Compliance" and is not distributable to any group. Info.plist ships
    # ITSAppUsesNonExemptEncryption=false, but answer here too so builds made
    # before that key (or with a stripped plist) don't wedge the job.
    if build["attributes"].get("usesNonExemptEncryption") is None:
        print("Export compliance unanswered; declaring exempt encryption.",
              flush=True)
        request_or_exit("PATCH", f"/v1/builds/{build['id']}", body={
            "data": {"type": "builds", "id": build["id"],
                     "attributes": {"usesNonExemptEncryption": False}},
        })

    group = single("beta group", "/v1/betaGroups", {
        "filter[app]": app_id,
        "filter[name]": group_name,
    })

    # TestFlight readiness lags processingState=VALID (and the compliance
    # answer takes a moment to apply), so a 422 "not in an internally testable
    # state" is retried until the deadline. Adding an already-linked build is
    # a no-op, so reruns are safe.
    while True:
        try:
            request("POST",
                    f"/v1/betaGroups/{group['id']}/relationships/builds",
                    body={"data": [{"type": "builds", "id": build["id"]}]})
            break
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:2000]
            if e.code != 422 or time.monotonic() >= deadline:
                sys.exit(f"::error::Adding the build to the group failed "
                         f"with HTTP {e.code}: {detail}")
            print(f"Build not assignable yet ({detail.strip()[:200]}…); "
                  f"waiting…", flush=True)
            time.sleep(POLL_INTERVAL_S)
    print(f"Build {version_name}({build_number}) is now available to "
          f"the internal group “{group_name}”.")


if __name__ == "__main__":
    main()
