#!/usr/bin/env python3
import json
import re
import subprocess

payload = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
sdk_version = subprocess.check_output(
    ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], text=True
).strip()


def version_tuple(value: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?$", value)
    if match:
        return tuple(int(part) for part in match.groups() if part is not None)
    return ()


sdk_tuple = tuple(int(part) for part in sdk_version.split("."))
runtime_groups = [
    (identifier, [device for device in devices if device.get("isAvailable")])
    for identifier, devices in payload.get("devices", {}).items()
    if ".iOS-" in identifier
]
runtime_groups.sort(
    key=lambda item: (version_tuple(item[0]) == sdk_tuple, version_tuple(item[0])),
    reverse=True,
)
preferred = ("iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15")
for _, devices in runtime_groups:
    for name in preferred:
        for device in devices:
            if device.get("name") == name:
                print(f"platform=iOS Simulator,id={device['udid']}")
                raise SystemExit(0)
    for device in devices:
        if str(device.get("name", "")).startswith("iPhone"):
            print(f"platform=iOS Simulator,id={device['udid']}")
            raise SystemExit(0)
raise SystemExit("No available iPhone simulator")
