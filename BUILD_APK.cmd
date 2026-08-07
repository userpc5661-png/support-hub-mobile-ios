@echo off
setlocal
cd /d "%~dp0"

flutter pub get
if errorlevel 1 exit /b 1

if exist firebase_defines.json (
  flutter build apk --debug --dart-define=API_BASE_URL=https://go-wasl.com/api --dart-define-from-file=firebase_defines.json
) else (
  echo [Wasl] firebase_defines.json was not found. The APK will build, but external push notifications will remain disabled.
  flutter build apk --debug --dart-define=API_BASE_URL=https://go-wasl.com/api
)
