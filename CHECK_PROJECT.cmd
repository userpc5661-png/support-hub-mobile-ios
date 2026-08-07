@echo off
setlocal
cd /d "%~dp0"

flutter pub get
if errorlevel 1 exit /b 1

dart format --output=none --set-exit-if-changed lib test
if errorlevel 1 echo [Wasl] Formatting changes are required. Run: dart format lib test

flutter analyze
if errorlevel 1 exit /b 1

flutter test
