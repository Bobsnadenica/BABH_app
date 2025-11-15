# BABH Дневници

Flutter mobile app for Bulgarian Food Safety Authority inspectors to manage digital inspection diaries with photo documentation and cloud storage.

## Features

- **User Authentication** – Cognito login with password reset
- **Dynamic Folders** – Configurable inspection categories from S3
- **Photo Management** – Capture, compress, and organize images
- **Cloud Storage** – AWS S3 integration via Amplify
- **Admin Dashboard** – User management (admin only)
- **Offline Support** – Core functionality without connectivity

## Quick Start

```bash
flutter pub get
flutter run -d <device-id>
```

See `APP_CONFIG_GUIDE.md` for S3 configuration setup.

## Project Structure

```
lib/
├── main.dart                          # App entry & theme
├── app_properties.dart                # Config schema
├── pages/                             # UI screens
├── services/                          # Business logic (auth, storage, compression)
└── widgets/                           # Reusable UI components
```

## Key Services

- **AppConfigService** – Fetches config from S3, validates, falls back to defaults
- **AuthService** – Cognito authentication & user groups
- **ImageCompressionService** – JPEG compression & thumbnails (settings from S3 config)
- **AmplifyStorage** – S3 file upload/download wrapper

## Config

App loads `app_properties.json` from S3 `public/` directory on startup (fresh each time, no caching). See `APP_CONFIG_GUIDE.md` for details.

## Build

```bash
flutter build apk --release
```

For troubleshooting, check app logs: `flutter logs -d <device-id>`
