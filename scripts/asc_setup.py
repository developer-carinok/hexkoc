#!/usr/bin/env python3
"""App Store Connect kurulumu: uygulama kaydını bulur, "Kişisel" iç test grubunu ve testçileri hazırlar.

Kullanım: ../LockDeck/.venv/bin/python scripts/asc_setup.py [--tester email ...]
Gereksinim: pyjwt (LockDeck .venv'inde var). Uygulama kaydı (bundle com.carinok.hexkoc) ASC'de yoksa
çıkış kodu 3 ile durur — kayıt yalnızca Xcode/ASC web arayüzünden açılabilir.
"""
import json, os, sys, time, urllib.request, urllib.error
import jwt

KEY_ID = os.environ.get("ASC_KEY_ID", "K5565AAZPA")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "2b798c52-072f-470e-8808-fe953150cba6")
BUNDLE_ID = os.environ.get("ASC_BUNDLE_ID", "com.carinok.hexkoc")
GROUP_NAME = os.environ.get("ASC_GROUP_NAME", "Kişisel")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
API = "https://api.appstoreconnect.apple.com"


def token() -> str:
    now = int(time.time())
    return jwt.encode({"iss": ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                      open(KEY_PATH).read(), algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode()[:1500]}


def main():
    testers = [a for a in sys.argv[1:] if "@" in a] or ["kadirgolcuk@icloud.com"]
    st, apps = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not apps.get("data"):
        print(f"Uygulama kaydı yok ({BUNDLE_ID}). Önce App Store Connect'te 'Yeni Uygulama' açılmalı.", file=sys.stderr)
        sys.exit(3)
    app = apps["data"][0]
    app_id = app["id"]
    print("APP", app_id, app["attributes"]["name"], app["attributes"]["bundleId"])

    st, groups = call("GET", f"/v1/betaGroups?filter[app]={app_id}")
    group = next((g for g in groups.get("data", []) if g["attributes"]["name"] == GROUP_NAME), None)
    if not group:
        st, res = call("POST", "/v1/betaGroups", {"data": {"type": "betaGroups",
            "attributes": {"name": GROUP_NAME, "isInternalGroup": True, "hasAccessToAllBuilds": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
        if st not in (200, 201):
            print("Grup açılamadı:", st, res, file=sys.stderr); sys.exit(4)
        group = res["data"]
        print("GROUP created", group["id"])
    else:
        print("GROUP exists", group["id"])
    gid = group["id"]

    st, existing = call("GET", f"/v1/betaGroups/{gid}/betaTesters?limit=200")
    have = {t["attributes"].get("email", "").lower() for t in existing.get("data", [])}
    for email in testers:
        if email.lower() in have:
            print("TESTER already in group:", email); continue
        st, found = call("GET", f"/v1/betaTesters?filter[email]={email}")
        tester = (found.get("data") or [None])[0]
        if tester:
            st, res = call("POST", f"/v1/betaGroups/{gid}/relationships/betaTesters",
                           {"data": [{"type": "betaTesters", "id": tester["id"]}]})
            print("TESTER linked", email, st, res if st >= 300 else "")
        else:
            st, res = call("POST", "/v1/betaTesters", {"data": {"type": "betaTesters",
                "attributes": {"email": email}, "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}})
            print("TESTER created", email, st, res if st >= 300 else "")

    st, builds = call("GET", f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=3")
    for b in builds.get("data", []):
        a = b["attributes"]
        print("BUILD", a.get("version"), a.get("processingState"), a.get("uploadedDate"), a.get("expirationDate"))
    print("ASC_APP_ID=" + app_id)


if __name__ == "__main__":
    main()
