#!/usr/bin/env python3
"""Switch the Runner's Release configuration to manual App Store signing.

The checked-in Xcode project uses automatic signing, which is what a developer
wants locally but cannot work on a CI runner with no signed-in Apple account
("error: No Accounts: Add a new account in Accounts settings"). This script
rewrites `ios/Runner.xcodeproj/project.pbxproj` **in CI only**, so the repository
keeps working unchanged for local development.

Usage:
    PROFILE_NAME="Saobracaj App Store" APPLE_TEAM_ID=BHH5379JU2 \
        python3 ios/ci/set_manual_signing.py [--check]

`--check` reports what would change without writing (used by the unit test).

Only the Release build configurations of the Runner target are touched — they
are recognised by the app's bundle identifier, which keeps RunnerTests and the
project-level configurations out of it.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

DEFAULT_PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"
DEFAULT_BUNDLE_ID = "at.gleb.saobracaj.saobracaj"
DEFAULT_TEAM_ID = "BHH5379JU2"

# A whole `/* Release */ = { isa = XCBuildConfiguration; ... name = Release; };`
# entry, non-greedy so each configuration is matched separately.
RELEASE_BLOCK = re.compile(
    r"/\* Release \*/ = \{\n\t*isa = XCBuildConfiguration;.*?name = Release;\n\t*\};",
    re.S,
)


def upsert(block: str, key: str, value: str, anchor: str) -> str:
    """Set `key = value;` inside an xcconfig block, inserting it if absent.

    `anchor` is a line that is known to exist in the block; a newly created
    setting is placed right before it, with the same indentation.
    """
    quoted_key = re.escape(key)
    existing = re.compile(rf"(\n(\t*){quoted_key} = )[^\n]*;")
    if existing.search(block):
        return existing.sub(rf"\g<1>{value};", block, count=1)

    anchor_match = re.search(rf"\n(\t*){re.escape(anchor)}", block)
    if anchor_match is None:
        raise SystemExit(f"ERROR: anchor {anchor!r} not found, cannot insert {key}")
    indent = anchor_match.group(1)
    return block.replace(
        anchor_match.group(0),
        f"\n{indent}{key} = {value};{anchor_match.group(0)}",
        1,
    )


def patch(source: str, profile_name: str, team_id: str, bundle_id: str) -> tuple[str, int]:
    anchor = f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};"
    patched = 0
    # Rewrite back-to-front so earlier match offsets stay valid.
    for match in reversed(list(RELEASE_BLOCK.finditer(source))):
        block = match.group(0)
        if anchor not in block:
            continue  # RunnerTests / project-level configuration

        # The project-level Release config sets CODE_SIGN_IDENTITY[sdk=iphoneos*]
        # to "iPhone Developer"; the target-level values written here win over it.
        block = upsert(block, "CODE_SIGN_STYLE", "Manual", anchor)
        block = upsert(block, "CODE_SIGN_IDENTITY", '"Apple Distribution"', anchor)
        block = upsert(
            block, '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"', '"Apple Distribution"', anchor
        )
        block = upsert(
            block, "PROVISIONING_PROFILE_SPECIFIER", f'"{profile_name}"', anchor
        )
        block = upsert(block, "DEVELOPMENT_TEAM", team_id, anchor)

        source = source[: match.start()] + block + source[match.end() :]
        patched += 1

    return source, patched


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pbxproj", default=DEFAULT_PBXPROJ)
    parser.add_argument("--profile-name", default=os.environ.get("PROFILE_NAME", ""))
    parser.add_argument(
        "--team-id", default=os.environ.get("APPLE_TEAM_ID", DEFAULT_TEAM_ID)
    )
    parser.add_argument(
        "--bundle-id", default=os.environ.get("IOS_BUNDLE_ID", DEFAULT_BUNDLE_ID)
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="do not write the file, only report the result",
    )
    args = parser.parse_args(argv)

    if not args.profile_name:
        # --check runs without a real profile: any placeholder exercises the rewrite.
        if not args.check:
            print("ERROR: PROFILE_NAME is empty", file=sys.stderr)
            return 1
        args.profile_name = "CHECK ONLY"

    with open(args.pbxproj, encoding="utf-8") as handle:
        original = handle.read()

    result, patched = patch(original, args.profile_name, args.team_id, args.bundle_id)
    if patched == 0:
        print(
            f"ERROR: no Runner Release configuration with "
            f"PRODUCT_BUNDLE_IDENTIFIER = {args.bundle_id} was found",
            file=sys.stderr,
        )
        return 1

    if args.check:
        print(f"OK: {patched} Release configuration(s) would be patched")
        for line in result.splitlines():
            if any(
                key in line
                for key in (
                    "CODE_SIGN_STYLE",
                    "CODE_SIGN_IDENTITY",
                    "PROVISIONING_PROFILE_SPECIFIER",
                    "DEVELOPMENT_TEAM",
                )
            ):
                print(line.strip())
        return 0

    with open(args.pbxproj, "w", encoding="utf-8") as handle:
        handle.write(result)
    print(
        f"Patched {patched} Release configuration(s) to manual signing "
        f"with profile '{args.profile_name}' (team {args.team_id})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
