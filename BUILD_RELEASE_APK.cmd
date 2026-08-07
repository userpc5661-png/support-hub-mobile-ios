@echo off
setlocal
cd /d "%~dp0"

if not exist android\key.properties (
  echo [Wasl] Release signing is not configured.
  echo Copy android\key.properties.example to android\key.properties and add the real keystore values.
  exit /b 1
)

flutter pub get
if errorlevel 1 exit /b 1

if exist firebase_defines.json (
  flutter build apk --release --dart-define=API_BASE_URL=https://go-wasl.com/api --dart-define-from-file=firebase_defines.json
) else (
  echo [Wasl] firebase_defines.json was not found. The APK will build, but external push notifications will remain disabled.
  flutter build apk --release --dart-define=API_BASE_URL=https://go-wasl.com/api
)
