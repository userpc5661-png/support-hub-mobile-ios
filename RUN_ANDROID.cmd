@echo off
setlocal
cd /d "%~dp0"

flutter pub get
if errorlevel 1 exit /b 1

if exist firebase_defines.json (
  flutter run --dart-define=API_BASE_URL=https://go-wasl.com/api --dart-define-from-file=firebase_defines.json
) else (
  echo [Wasl] firebase_defines.json was not found. The app will run, but external push notifications will remain disabled.
  flutter run --dart-define=API_BASE_URL=https://go-wasl.com/api
)
