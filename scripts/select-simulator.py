#!/usr/bin/env python3
import json
import subprocess

payload = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
preferred = ("iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15")
devices = [device for group in payload.get("devices", {}).values() for device in group if device.get("isAvailable")]
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
