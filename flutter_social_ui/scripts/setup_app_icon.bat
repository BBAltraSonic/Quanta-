@echo off
echo 🚀 Quanta App Icon Setup (Windows)
echo ===================================

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python from https://python.org
    pause
    exit /b 1
)

REM Check if PIL (Pillow) is installed
python -c "from PIL import Image" >nul 2>&1
if errorlevel 1 (
    echo 📦 Installing required Python package: Pillow
    pip install Pillow
    if errorlevel 1 (
        echo ❌ Failed to install Pillow
        pause
        exit /b 1
    )
)

REM Check if source image exists
if "%~1"=="" (
    echo Usage: setup_app_icon.bat "path\to\your\source_image.png"
    echo Example: setup_app_icon.bat "assets\app_icons\quanta_icon_1024.png"
    pause
    exit /b 1
)

if not exist "%~1" (
    echo ❌ Source image not found: %~1
    echo Please make sure the file exists and try again
    pause
    exit /b 1
)

REM Run the Python script
echo 🔧 Running icon generation script...
python scripts\setup_app_icon.py "%~1"

if errorlevel 1 (
    echo ❌ Icon generation failed
    pause
    exit /b 1
)

echo.
echo ✅ Icon setup complete!
echo 💡 Next steps:
echo    1. Run: flutter clean
echo    2. Run: flutter pub get  
echo    3. Test your app on a device to see the new icon
echo.
pause
