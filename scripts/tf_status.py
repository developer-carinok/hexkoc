#!/usr/bin/env python3
"""TestFlight build durumunu App Store Connect API'sinden okur.

Kullanım: .venv/bin/python scripts/tf_status.py [--watch]
"""
import json, os, sys, time, urllib.request, datetime
import jwt

KEY_ID = os.environ.get("ASC_KEY_ID", "K5565AAZPA")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2b798c52-072f-470e-8808-fe953150cba6")
APP_ID = os.environ.get("ASC_APP_ID", "6814912778")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")


def token() -> str:
    with open(KEY_PATH) as f:
        private_key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def get(path: str) -> dict:
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com" + path,
        headers={"Authorization": "Bearer " + token()},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def builds():
    data = get(f"/v1/builds?filter[app]={APP_ID}&limit=5&sort=-uploadedDate")
    out = []
    for b in data.get("data", []):
        a = b["attributes"]
        out.append({
            "build": a.get("version"),
            "app_version": a.get("preReleaseVersion", {}).get("version") if isinstance(a.get("preReleaseVersion"), dict) else None,
            "state": a.get("processingState"),
            "expired": a.get("expired"),
            "uploaded": a.get("uploadedDate"),
            "expires": a.get("expirationDate"),
        })
    return out


if __name__ == "__main__":
    watch = "--watch" in sys.argv
    while True:
        try:
            rows = builds()
        except Exception as e:
            print("HATA:", e, flush=True)
            sys.exit(2)
        if not rows:
            print("henüz build yok", flush=True)
        for r in rows:
            print(f"Build {r['build']} · {r['state']} · yüklendi {r['uploaded']} · son kullanma {r['expires']}", flush=True)
        if not watch:
            break
        if rows and rows[0]["state"] == "VALID":
            print("HAZIR", flush=True)
            break
        if rows and rows[0]["state"] in ("INVALID", "FAILED"):
            print("BASARISIZ", flush=True)
            sys.exit(1)
        time.sleep(30)
