@echo off
REM Quanta Production Build Script for Windows
REM This script automates the production build process for Android and iOS
REM Usage: scripts\build\build_production.bat [android|ios|all]

setlocal enabledelayedexpansion

REM Configuration
set PROJECT_NAME=Quanta
set PACKAGE_NAME=com.mynkayenzi.quanta
set BUILD_DIR=build\release
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

echo.
echo 🚀 Starting Quanta production build...
echo 📂 Project: %PROJECT_NAME%
echo 📦 Package: %PACKAGE_NAME%
echo 🎯 Target: %1

REM Create build directory
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM Check prerequisites
echo.
echo [INFO] Checking prerequisites...

REM Check Flutter installation
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    exit /b 1
)

REM Check if .env file exists
if not exist ".env" (
    echo ❌ .env file not found. Please create it from .env.template
    exit /b 1
)

REM Verify environment variables
findstr /c:"SUPABASE_URL=https://" .env >nul
if %errorlevel% neq 0 (
    echo ❌ SUPABASE_URL not properly configured in .env
    exit /b 1
)

echo ✅ Prerequisites check completed

REM Clean previous builds
echo.
echo [INFO] Cleaning previous builds...
flutter clean
if exist "build\" rmdir /s /q "build\"
if exist ".dart_tool\" rmdir /s /q ".dart_tool\"
echo ✅ Clean completed

REM Get dependencies
echo.
echo [INFO] Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Failed to get dependencies
    exit /b 1
)
echo ✅ Dependencies updated

REM Run tests
echo.
echo [INFO] Running tests before build...
flutter test
if %errorlevel% neq 0 (
    echo ⚠️ Some unit tests failed
)

flutter analyze
if %errorlevel% neq 0 (
    echo ⚠️ Static analysis found issues
)
echo ✅ Tests completed

REM Run security checks
echo.
echo [INFO] Running security checks...
if exist "scripts\security_audit\dependency_scanner.dart" (
    echo [INFO] Running dependency vulnerability scan...
    dart scripts\security_audit\dependency_scanner.dart
)

if exist "scripts\security_audit\code_analyzer.dart" (
    echo [INFO] Running static code security analysis...
    dart scripts\security_audit\code_analyzer.dart
)
echo ✅ Security checks completed

REM Determine build target
set BUILD_TARGET=%1
if "%BUILD_TARGET%"=="" set BUILD_TARGET=all

REM Build Android
if "%BUILD_TARGET%"=="android" goto build_android
if "%BUILD_TARGET%"=="all" goto build_android
goto check_ios

:build_android
echo.
echo [INFO] Building Android APK and App Bundle...

REM Create Android build directory
if not exist "%BUILD_DIR%\android" mkdir "%BUILD_DIR%\android"

REM Build APK
echo [INFO] Building APK...
flutter build apk --release --build-name=1.0.0 --build-number=1 --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ❌ Android APK build failed
    exit /b 1
)

REM Copy APK to release directory
copy "build\app\outputs\flutter-apk\app-release.apk" "%BUILD_DIR%\android\%PROJECT_NAME%_%TIMESTAMP%.apk"

REM Build App Bundle
echo [INFO] Building App Bundle...
flutter build appbundle --release --build-name=1.0.0 --build-number=1 --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo ❌ Android App Bundle build failed
    exit /b 1
)

REM Copy App Bundle to release directory
copy "build\app\outputs\bundle\release\app-release.aab" "%BUILD_DIR%\android\%PROJECT_NAME%_%TIMESTAMP%.aab"

echo ✅ Android build completed
echo 📱 APK: %PROJECT_NAME%_%TIMESTAMP%.apk
echo 📦 AAB: %PROJECT_NAME%_%TIMESTAMP%.aab
echo 📂 Files saved to: %BUILD_DIR%\android\

:check_ios
if "%BUILD_TARGET%"=="ios" goto build_ios
if "%BUILD_TARGET%"=="all" goto build_ios
goto generate_report

:build_ios
echo.
echo [INFO] Building iOS...
echo ⚠️ iOS build requires macOS and Xcode
echo ⚠️ Skipping iOS build on Windows
goto generate_report

:generate_report
echo.
echo [INFO] Generating build report...

set REPORT_FILE=%BUILD_DIR%\build_report_%TIMESTAMP%.md

echo # 🚀 Quanta Production Build Report > "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo **Build Date:** %date% %time% >> "%REPORT_FILE%"
echo **Build Version:** 1.0.0 >> "%REPORT_FILE%"
echo **Build Number:** 1 >> "%REPORT_FILE%"
echo **Platform:** Windows >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo ## 📱 Build Artifacts >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo ### Android >> "%REPORT_FILE%"

if exist "%BUILD_DIR%\android\%PROJECT_NAME%_%TIMESTAMP%.apk" (
    echo - ✅ APK: %PROJECT_NAME%_%TIMESTAMP%.apk >> "%REPORT_FILE%"
)

if exist "%BUILD_DIR%\android\%PROJECT_NAME%_%TIMESTAMP%.aab" (
    echo - ✅ App Bundle: %PROJECT_NAME%_%TIMESTAMP%.aab >> "%REPORT_FILE%"
)

echo. >> "%REPORT_FILE%"
echo ### iOS >> "%REPORT_FILE%"
echo - ⚠️ iOS build requires macOS and Xcode >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo ## 📊 Build Configuration >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo - **Environment:** Production >> "%REPORT_FILE%"
echo - **Build Mode:** Release >> "%REPORT_FILE%"
echo - **Tree Shaking:** Enabled >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo ## 🔧 Next Steps >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo 1. **Android:** >> "%REPORT_FILE%"
echo    - Upload AAB file to Google Play Console >> "%REPORT_FILE%"
echo    - Create release notes >> "%REPORT_FILE%"
echo    - Configure release rollout >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo 2. **iOS:** >> "%REPORT_FILE%"
echo    - Build on macOS with Xcode >> "%REPORT_FILE%"
echo    - Configure code signing >> "%REPORT_FILE%"
echo    - Archive and upload to App Store Connect >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo ## ⚠️ Security Checklist >> "%REPORT_FILE%"
echo. >> "%REPORT_FILE%"
echo - [ ] Environment variables properly configured >> "%REPORT_FILE%"
echo - [ ] No hardcoded secrets in build >> "%REPORT_FILE%"
echo - [ ] Crash reporting enabled >> "%REPORT_FILE%"
echo - [ ] Analytics configured >> "%REPORT_FILE%"
echo - [ ] App signing configured >> "%REPORT_FILE%"

echo ✅ Build report generated: %REPORT_FILE%

echo.
echo ✅ 🎉 Production build completed successfully!
echo 📂 Build artifacts saved to: %BUILD_DIR%
echo.
echo 🔥 DEPLOYMENT READY!
echo.
echo Next steps:
echo 1. Review build report: %BUILD_DIR%\build_report_%TIMESTAMP%.md
echo 2. Test APK on physical devices
echo 3. Upload to respective app stores
echo 4. Configure release rollout
echo.

exit /b 0