"""Prepare a separate Flutter workspace; never edits source iOS or signs/builds.

Requires the real, previously verified Firebase Staging plist supplied locally.
No download or workflow creation. Rejects existing output rather than deleting it.
"""
import argparse
import base64
import json
import plistlib
import shutil
from pathlib import Path

PROJECT = "aqar-bookings-test-20261009"
BUNDLE = "com.andalus.aqar.bookingstest"
SENDER = "463930605039"


def validate(config):
    if (config.get("PROJECT_ID") != PROJECT or config.get("BUNDLE_ID") != BUNDLE
            or str(config.get("GCM_SENDER_ID")) != SENDER
            or config.get("STORAGE_BUCKET") != PROJECT + ".firebasestorage.app"
            or not config.get("GOOGLE_APP_ID", "").startswith("1:" + SENDER + ":ios:")
            or not config.get("API_KEY")):
        raise ValueError("Verified bookings iOS Staging config required")


def prepare(source, config_path, output):
    source, output = Path(source).resolve(), Path(output).resolve()
    with open(config_path, "rb") as handle:
        config = plistlib.load(handle)
    validate(config)  # Before creating output or copying any production resource.
    if output.exists() or output == source or source in output.parents or output in source.parents:
        raise ValueError("Output must be a new separate workspace")
    for name in ("lib", "assets", "ios", "pubspec.yaml", "pubspec.lock"):
        item = source / name
        if item.is_dir():
            shutil.copytree(item, output / name, ignore=shutil.ignore_patterns(
                "ephemeral", ".symlinks", "Pods", "DerivedData", "Generated.xcconfig",
                "flutter_export_environment.sh", "GoogleService-Info.plist"))
        elif item.is_file():
            output.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, output / name)
    with open(output / "ios/Runner/GoogleService-Info.plist", "wb") as handle:
        plistlib.dump(config, handle)
    with open(source / "ios/Runner/Info.plist", "rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleDisplayName"] = "عقارات الانبار — STAGING"
    # Production OAuth URL schemes must not be inherited by the isolated app.
    info.pop("CFBundleURLTypes", None)
    with open(output / "ios/BookingsStaging/Info.plist", "wb") as handle:
        plistlib.dump(info, handle)
    defines = {
        "FLUTTER_APP_FLAVOR": "bookingsStaging",
        "BOOKINGS_IOS_API_KEY": config["API_KEY"],
        "BOOKINGS_IOS_APP_ID": config["GOOGLE_APP_ID"],
        "BOOKINGS_IOS_BUNDLE_ID": BUNDLE,
    }
    # Generated private workspace only; never print its Firebase config values.
    (output / "booking-ios-defines.json").write_text(json.dumps(defines), encoding="utf-8")
    encoded = ",".join(base64.b64encode(f"{k}={v}".encode()).decode() for k, v in defines.items())
    with open(output / "ios/BookingsStaging/Staging.xcconfig", "a", encoding="utf-8") as handle:
        handle.write("\nDART_DEFINES = " + encoded + "\n")
    return {"project": PROJECT, "bundle": BUNDLE, "built": False, "signed": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--firebase-plist", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.source, args.firebase_plist, args.output)))
