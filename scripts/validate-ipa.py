#!/usr/bin/env python3
"""Fail the build when an IPA is structurally incomplete."""

from __future__ import annotations

import json
import plistlib
import sys
import zipfile
from pathlib import Path, PurePosixPath


REQUIRED_LOCALIZATIONS = ("en", "zh-Hans", "ja", "ko")
ARM64_MACHO_MAGIC = b"\xcf\xfa\xed\xfe"


def fail(message: str) -> None:
    raise SystemExit(f"IPA validation failed: {message}")


def main(ipa_path: str) -> None:
    path = Path(ipa_path)
    if not path.is_file():
        fail(f"file does not exist: {path}")

    try:
        with zipfile.ZipFile(path) as archive:
            bad_entry = archive.testzip()
            if bad_entry:
                fail(f"corrupt ZIP entry: {bad_entry}")

            names = set(archive.namelist())
            app_roots = {
                "/".join(PurePosixPath(name).parts[:2])
                for name in names
                if len(PurePosixPath(name).parts) >= 2
                and PurePosixPath(name).parts[0] == "Payload"
                and PurePosixPath(name).parts[1].endswith(".app")
            }
            if len(app_roots) != 1:
                fail(f"expected one Payload/*.app bundle, found {len(app_roots)}")

            app_root = app_roots.pop()
            info_name = f"{app_root}/Info.plist"
            if info_name not in names:
                fail("Info.plist is missing")
            info = plistlib.loads(archive.read(info_name))

            if info.get("DTPlatformName") != "iphoneos":
                fail(f"unexpected platform: {info.get('DTPlatformName')!r}")
            executable = info.get("CFBundleExecutable")
            if not executable:
                fail("CFBundleExecutable is missing")
            executable_name = f"{app_root}/{executable}"
            if executable_name not in names:
                fail(f"executable is missing: {executable_name}")
            executable_data = archive.read(executable_name)
            if not executable_data.startswith(ARM64_MACHO_MAGIC):
                fail("executable is not a 64-bit arm64 Mach-O")

            required_resources = {f"{app_root}/Assets.car"}
            required_resources.update(
                f"{app_root}/{language}.lproj/Localizable.strings"
                for language in REQUIRED_LOCALIZATIONS
            )
            missing = sorted(required_resources - names)
            if missing:
                fail("missing bundled resources: " + ", ".join(missing))

            summary = {
                "ipa": str(path),
                "bundleIdentifier": info.get("CFBundleIdentifier"),
                "version": info.get("CFBundleShortVersionString"),
                "build": info.get("CFBundleVersion"),
                "minimumOS": info.get("MinimumOSVersion"),
                "sdk": info.get("DTSDKName"),
                "executableBytes": len(executable_data),
                "entries": len(names),
                "localizations": list(REQUIRED_LOCALIZATIONS),
                "assets": "Assets.car",
            }
            print("IPA validation passed")
            print(json.dumps(summary, indent=2, ensure_ascii=False))
    except zipfile.BadZipFile as error:
        fail(f"invalid ZIP container: {error}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        fail("usage: validate-ipa.py <path-to-ipa>")
    main(sys.argv[1])
