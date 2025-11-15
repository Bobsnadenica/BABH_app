# App Configuration Setup Guide

## Overview

The app now reads configuration from a centralized `app_properties.json` file stored in S3. This allows you to update folders, compression settings, and storage properties without redeploying the app. UI strings remain hardcoded in the app.

## File Location

Place the `app_properties.json` file in the **`public/` directory** of your S3 bucket (accessible to guest/public access):

```
S3 Bucket (babh-user-photos99327-dev)
├── public/
│   ├── app_properties.json     ← Place it here
│   ├── [user folders and files...]
└── [other files...]
```

## File Structure

The `app_properties.json` file controls:

1. **Folders**: The list of document categories displayed in the app
2. **Compression Settings**: JPEG quality, max dimensions, thumbnail settings
3. **Storage**: Trash retention period

## Modifying Configuration

To update the app's behavior:

1. Edit `app_properties.json` in your S3 `public/` directory
2. Upload the updated file
3. **App automatically fetches fresh config on next startup** (no caching)

### Example Changes

**Add a new folder:**
```json
"folders": [
  "Входящ Контрол",
  "Изходящ контрол",
  "Темп. Хладилник",
  "Хигиена Обект",
  "Лична хигиена",
  "Обуч. Персонал",
  "ДДД",
  "Нов Дневник"
]
```

**Adjust compression quality:**
```json
"compression": {
  "quality": 90,
  "maxWidth": 2048,
  "maxHeight": 2048,
  ...
}
```

**Change trash retention period:**
```json
"storage": {
  "trashRetentionDays": 45
}
```

## Configuration Loading

- **On app startup**: App fetches `app_properties.json` from `public/app_properties.json` in S3 (guest access level)
- **Fresh fetch every startup**: Config is fetched fresh from S3 on each app launch (no caching)
- **Fallback**: If S3 file can't be reached, app uses the hardcoded schema defaults from `lib/app_properties.dart`
- **Validation**: Config structure is validated against the schema and mismatches are logged
- **Access**: Available to all authenticated users immediately after login

## Available Configuration

### Folders
List of document categories. Each folder gets its own page with a dedicated image gallery.

### Compression
- **quality**: JPEG compression quality (0-100, recommended: 80-90)
- **maxWidth**: Maximum width in pixels (default: 1920)
- **maxHeight**: Maximum height in pixels (default: 1920)
- **thumbnailQuality**: Thumbnail JPEG quality (0-100, recommended: 60-75)
- **thumbnailWidth**: Thumbnail max width (default: 256)
- **thumbnailHeight**: Thumbnail max height (default: 256)

### Storage
- **trashRetentionDays**: Days before trash files are permanently deleted (default: 30)

## S3 Upload Instructions

1. Navigate to S3 bucket public directory: `s3://babh-user-photos99327-dev/public/`
2. Upload `app_properties.json` to this location
3. The file is automatically accessible to the app via Amplify Storage (guest/public access level)
4. No manual permission changes needed—Amplify Storage handles access rules

## Technical Details

- **Schema Definition**: `lib/app_properties.dart` (single source of truth for all config defaults)
- **Service**: `lib/services/app_config_service.dart` (fetches from S3, validates, provides fallback)
- **Global Access**: `appConfig` global variable in `app_config_service.dart`
- **File Format**: UTF-8 encoded JSON
- **Size**: ~500 bytes (lightweight, loads quickly)
- **Validation**: Generic recursive JSON comparison detects missing/extra/type-mismatched properties

## UI Strings

All user-facing text strings remain hardcoded in the app:
- Home page titles and descriptions
- Folder page buttons and messages
- Admin page titles
- Error messages

These strings are defined in the respective page files and are **NOT** loaded from `app_properties.json`.

## Troubleshooting

If changes don't appear:
1. Restart the app (fetches fresh config each startup)
2. Check S3 file is at `public/app_properties.json` (not root)
3. Verify JSON syntax is valid (use JSONLint)
4. Review app logs for `⚙️ Attempting to fetch app config from S3...` and validation messages
5. Check Amplify configuration in `lib/amplifyconfiguration.dart` for correct bucket/region

## Version Updates

When releasing new app features that require new config options:
1. Update schema in `lib/app_properties.dart` with new defaults
2. Update `AppConfig`, `CompressionConfig`, or `StorageConfig` classes in `app_config_service.dart` if needed
3. Add corresponding fields to `app_properties.json` 
4. The validation will automatically detect mismatches and log them
5. No app redeploy needed for value-only changes, only for structural changes


