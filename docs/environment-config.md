# Environment Configuration (API_BASE_URL)

The Flutter app never hardcodes the backend URL. It's injected at build/run
time via Dart's `--dart-define-from-file`, reading one of the JSON files in
`config/`.

## Running against each environment

```bash
# Android emulator against a locally-running backend
flutter run --dart-define-from-file=config/dev.json

# Staging
flutter run --dart-define-from-file=config/staging.json

# Production
flutter run --dart-define-from-file=config/prod.json
```

The same flag works for `flutter build apk` / `flutter build ios`.

## Testing on a physical device

`config/dev.json` points at `10.0.2.2` -- the Android emulator's alias for
your host machine. A physical phone can't resolve that; it needs your
computer's real LAN IP instead. Rather than edit the committed
`config/dev.json` (and risk committing your personal network's IP):

1. Copy it: `cp config/dev.json config/local.json`
2. Edit `config/local.json`'s `API_BASE_URL` to `http://<your-LAN-IP>:8000`
3. Run with `--dart-define-from-file=config/local.json`

`config/local.json` is gitignored -- it never gets committed.

## Updating staging/prod URLs

`config/staging.json` and `config/prod.json` currently hold placeholder
URLs. Once the backend is deployed (see the backend repo's
`docs/deployment-runbook.md`), update `prod.json`'s `API_BASE_URL` to the
App Runner service URL from `terraform output app_runner_service_url`.

## Why no default

`apiBaseUrl` in `lib/core/api/api_client.dart` has no fallback value on
purpose. It used to default to a hardcoded LAN IP, which meant any build
that forgot the `--dart-define-from-file` flag silently pointed at one
developer's home network instead of failing loudly. An empty value means
every request fails immediately and obviously (and logs a clear error
telling you what to do), instead of quietly hitting the wrong backend.
