# Daddies Padel — Mobile (Expo)

Native iOS/Android app (Expo + expo-router + TypeScript) that consumes the
Flask JSON API (`/api/v1`). Fase 2 scaffold: auth, tabs, membership, sessions,
members. More screens (tournaments, chips, notifications) come next.

## Stack
- Expo SDK 52 + expo-router (file-based routing, typed routes)
- React Query (data fetching/cache) + axios (JWT + auto-refresh interceptor)
- expo-secure-store (encrypted token storage)

## Run locally
```bash
cd mobile
npm install
npx expo install --fix        # align native dep versions to the SDK
cp .env.example .env          # set EXPO_PUBLIC_API_URL

# Start the Flask API first (separate terminal):
#   cd ../backend && ../venv/bin/python run.py   → http://127.0.0.1:5000

npx expo start
```

### Pointing the app at the API
Set `EXPO_PUBLIC_API_URL` in `.env`:
- **Android emulator:** `http://10.0.2.2:5000` (host loopback)
- **iOS simulator / web:** `http://127.0.0.1:5000`
- **Physical device:** `http://<your-LAN-ip>:5000` (same Wi-Fi)
- **Production VPS:** `https://api.daddiespadel.com`

Seeded login (dev): `hendy@daddiespadel.com` / `daddies`.

## Build APK / app store (EAS)
```bash
npm i -g eas-cli && eas login
eas build:configure
eas build -p android --profile preview      # APK for internal testing
eas build -p android --profile production    # AAB for Play Store
eas build -p ios --profile production        # TestFlight (needs Apple Dev)
```

## Structure
```
app/                       expo-router routes
  _layout.tsx              providers + auth redirect
  index.tsx                splash/redirect
  (auth)/login,register
  (tabs)/index,sessions,members,profile
  membership.tsx           (modal)
src/
  api/  client, endpoints, types, tokenStore
  context/AuthContext
  ui.tsx, theme.ts
```

## Status
- ✅ Auth (login/register/JWT refresh/secure-store), tab shell
- ✅ Home, Sessions (list+join), Members (list+search), Profile, Membership
- ⬜ Tournaments, Chips, Notifications, push (expo-notifications)
