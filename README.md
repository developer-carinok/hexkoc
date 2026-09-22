# HexKoç

TFT Set 18 (Enchanted Wilds) için Türkçe yardımcı iOS uygulaması: meta komplar, takım kodu kopyalama,
tahta dizilimi, şampiyon / özellik / eşya / güçlendirme rehberi ve Türkçe öğrenme içeriği.
Kişisel kullanım, TestFlight üzerinden dağıtılır.

## Yapı
- `HexKoc/` SwiftUI kaynakları (iOS 18+, bağımlılık yok). Proje `project.yml` ile xcodegen tarafından üretilir.
- `Resources/Data/*.json` + `Resources/Images/**` uygulamaya gömülü veri ve ikonlar (çevrimdışı çalışır).
- `data/v1/*.json` aynı verinin GitHub üzerinden yayınlanan kopyası; uygulama açılışta `manifest.json`'ı
  kontrol edip daha yeni veri varsa indirir.
- `tools/build_data.py` veri pipeline'ı (CommunityDragon + MetaTFT → JSON + ikon). `tools/rules.json`
  mağaza olasılıkları, XP ve ekonomi kuralları (elle güncellenir). `tools/guides.json` rehber makaleleri.
- `.github/workflows/refresh-data.yml` her gün 06:00 UTC'de kompları yenileyip `data/v1` JSON'larını commit'ler.
- `scripts/release.sh` arşiv + TestFlight yükleme, `scripts/tf_status.py` build durumu,
  `scripts/asc_setup.py` TestFlight grubu ve testçi kurulumu.
- `docs/` plan, veri sözleşmesi ve spec'ler.

## Geliştirme
```bash
xcodegen generate
xcodebuild -project HexKoc.xcodeproj -scheme HexKoc -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Veri yenileme (yerel)
```bash
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/build_data.py --verify-codes
```
Set değişince `tools/build_data.py` içindeki set anahtarı (`TFTSet18`) ve `tools/rules.json` güncellenmeli.

## Sürüm
```bash
ASC_KEY_ID=K5565AAZPA ./scripts/release.sh      # arşivler ve TestFlight'a yükler
../LockDeck/.venv/bin/python scripts/tf_status.py --watch
```

Veriler MetaTFT ve CommunityDragon'dan alınır. HexKoç, Riot Games ile bağlantılı değildir.
