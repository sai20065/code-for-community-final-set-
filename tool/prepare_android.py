"""Finish the Android platform folder after `flutter create`.

android/ is not committed (it's generated on demand), so every build —
GitHub Actions and local — runs:

    flutter create . --platforms=android --project-name praja_dhvani
    python tool/prepare_android.py

This script then:
  1. forces applicationId/namespace to com.prajadhvani.app (matching
     firebase_options.dart) and moves MainActivity to that package path —
     AGP requires the two to agree;
  2. installs the real Firebase config (firebase_config/google-services.json);
  3. declares the runtime permissions image_picker / record / geolocator
     need;
  4. declares that the app opens https links (Android 11+ package
     visibility) — without it the "Open in Google Maps" button does nothing;
  5. sets the launcher label to "Prajadhwani".

Idempotent: safe to run more than once.
"""
import pathlib
import re
import shutil

TARGET = "com.prajadhvani.app"
ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "android" / "app"


def set_application_id() -> None:
    for name in ("build.gradle", "build.gradle.kts"):
        path = APP / name
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        text = re.sub(r'applicationId\s*=?\s*"[^"]*"', f'applicationId = "{TARGET}"', text)
        text = re.sub(r'namespace\s*=?\s*"[^"]*"', f'namespace = "{TARGET}"', text)
        path.write_text(text, encoding="utf-8")

    for lang, ext in (("kotlin", "kt"), ("java", "java")):
        base = APP / "src" / "main" / lang
        if not base.exists():
            continue
        matches = list(base.rglob(f"MainActivity.{ext}"))
        if not matches:
            continue
        old_file = matches[0]
        new_dir = base / pathlib.Path(*TARGET.split("."))
        new_dir.mkdir(parents=True, exist_ok=True)
        new_file = new_dir / old_file.name
        text = old_file.read_text(encoding="utf-8")
        text = re.sub(r"^package .*$", f"package {TARGET}", text, count=1, flags=re.MULTILINE)
        new_file.write_text(text, encoding="utf-8")
        if old_file != new_file:
            old_file.unlink()


def install_firebase_config() -> None:
    shutil.copyfile(ROOT / "firebase_config" / "google-services.json",
                    APP / "google-services.json")


def patch_manifest() -> None:
    path = APP / "src" / "main" / "AndroidManifest.xml"
    content = path.read_text(encoding="utf-8")

    permissions = "\n".join(
        f'    <uses-permission android:name="android.permission.{p}" />'
        for p in [
            "INTERNET",
            "CAMERA",
            "RECORD_AUDIO",
            "READ_MEDIA_IMAGES",
            "READ_EXTERNAL_STORAGE",
            "ACCESS_FINE_LOCATION",
            "ACCESS_COARSE_LOCATION",
        ]
    )
    if "android.permission.CAMERA" not in content:
        content = content.replace("<application", permissions + "\n\n    <application", 1)

    view_https = (
        "<queries>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.VIEW" />\n'
        '            <data android:scheme="https" />\n'
        "        </intent>"
    )
    if 'android:scheme="https"' not in content:
        if "<queries>" in content:
            content = content.replace("<queries>", view_https, 1)
        else:
            content = content.replace(
                "</manifest>", "    " + view_https + "\n    </queries>\n</manifest>", 1)

    content = re.sub(r'android:label="[^"]*"', 'android:label="Prajadhwani"', content, count=1)
    path.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    if not APP.exists():
        raise SystemExit("android/app not found - run `flutter create` first.")
    set_application_id()
    install_firebase_config()
    patch_manifest()
    print("android/ prepared for", TARGET)
