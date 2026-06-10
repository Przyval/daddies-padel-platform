# Build APK / AAB with EAS

EAS Build compiles the app in Expo's cloud — **no Android Studio / Xcode / Mac
needed**. You drive it from this folder.

## 0. One-time setup
```bash
npm i -g eas-cli
eas login                      # create a free Expo account if needed
cd mobile
eas init                       # links this project, writes the projectId into app.json
```

## 1. Point the build at your API
Build profiles bake in `EXPO_PUBLIC_API_URL` (see `eas.json`). Edit the URL in
the `preview` / `production` profiles to your real VPS domain before building:
```json
"env": { "EXPO_PUBLIC_API_URL": "https://api.daddiespadel.com" }
```
> The app talks to the API over HTTPS — the VPS must be deployed first
> (see ../deploy/DEPLOY.md). A WebView-only app would need this too.

## 2. Build an installable APK (internal testing)
```bash
eas build -p android --profile preview
```
EAS provisions a keystore the first time (it stores it for you), builds in the
cloud (~10–20 min), and gives a download URL + QR. Install the `.apk` on any
Android phone (enable "install unknown apps").

## 3. Build for the stores
```bash
# Android — AAB for Google Play ($25 one-time developer account)
eas build -p android --profile production

# iOS — needs Apple Developer ($99/yr); builds in cloud, no Mac required
eas build -p ios --profile production
```

## 4. Submit (optional, after stores are set up)
```bash
eas submit -p android --latest      # upload AAB to Play Console
eas submit -p ios --latest          # upload to App Store Connect / TestFlight
```

## 5. OTA updates (push JS-only fixes without a rebuild)
```bash
npm i -g eas-cli
eas update --branch production --message "fix copy"
```

## Versions
- `appVersionSource: remote` + `autoIncrement` (production) → EAS manages the
  Android `versionCode` / iOS build number automatically each build.
- Bump the user-facing `version` in `app.json` for real releases.

## Checklist before first store build
- [ ] API deployed on VPS over HTTPS, smoke test GREEN (../deploy)
- [ ] `EXPO_PUBLIC_API_URL` in eas.json points to the VPS domain
- [ ] App icon + splash added (replace Expo defaults)
- [ ] Android: Google Play Developer account ($25)
- [ ] iOS: Apple Developer Program ($99/yr)
