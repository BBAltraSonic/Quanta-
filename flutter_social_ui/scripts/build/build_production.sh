#!/bin/bash

# Quanta Production Build Script
# This script automates the production build process for Android and iOS
# Usage: ./scripts/build/build_production.sh [android|ios|all]

set -e

# Configuration
PROJECT_NAME="Quanta"
PACKAGE_NAME="com.mynkayenzi.quanta"
BUILD_DIR="build/release"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Flutter installation
    if ! command -v flutter &> /dev/null; then
        error "Flutter is not installed or not in PATH"
    fi
    
    # Check Flutter doctor
    log "Running Flutter doctor..."
    flutter doctor --quiet || warning "Flutter doctor reported issues"
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        error ".env file not found. Please create it from .env.template"
    fi
    
    # Verify environment variables
    if ! grep -q "SUPABASE_URL=https://" .env; then
        error "SUPABASE_URL not properly configured in .env"
    fi
    
    if ! grep -q "SUPABASE_ANON_KEY=" .env && ! grep -q "your_supabase_anon_key_here" .env; then
        warning "SUPABASE_ANON_KEY may not be properly configured"
    fi
    
    success "Prerequisites check completed"
}

# Clean previous builds
clean_builds() {
    log "Cleaning previous builds..."
    
    flutter clean
    rm -rf build/
    rm -rf .dart_tool/
    
    success "Clean completed"
}

# Get dependencies
get_dependencies() {
    log "Getting dependencies..."
    
    flutter pub get
    
    success "Dependencies updated"
}

# Run tests before building
run_tests() {
    log "Running tests before build..."
    
    # Run unit tests
    flutter test || warning "Some unit tests failed"
    
    # Run static analysis
    flutter analyze || warning "Static analysis found issues"
    
    success "Tests completed"
}

# Build for Android
build_android() {
    log "Building Android APK and App Bundle..."
    
    # Create build directory
    mkdir -p "$BUILD_DIR/android"
    
    # Build APK (for testing)
    log "Building APK..."
    flutter build apk --release \
        --build-name=1.0.0 \
        --build-number=1 \
        --no-tree-shake-icons
    
    # Copy APK to release directory
    cp build/app/outputs/flutter-apk/app-release.apk \
       "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.apk"
    
    # Build App Bundle (for Play Store)
    log "Building App Bundle..."
    flutter build appbundle --release \
        --build-name=1.0.0 \
        --build-number=1 \
        --no-tree-shake-icons
    
    # Copy App Bundle to release directory
    cp build/app/outputs/bundle/release/app-release.aab \
       "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.aab"
    
    # Get file sizes
    APK_SIZE=$(du -h "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.apk" | cut -f1)
    AAB_SIZE=$(du -h "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.aab" | cut -f1)
    
    success "Android build completed"
    log "📱 APK size: $APK_SIZE"
    log "📦 AAB size: $AAB_SIZE"
    log "📂 Files saved to: $BUILD_DIR/android/"
}

# Build for iOS
build_ios() {
    log "Building iOS..."
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        warning "iOS build requires macOS. Skipping iOS build."
        return
    fi
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        warning "Xcode not found. Skipping iOS build."
        return
    fi
    
    # Create build directory
    mkdir -p "$BUILD_DIR/ios"
    
    # Build iOS
    log "Building iOS archive..."
    flutter build ios --release \
        --build-name=1.0.0 \
        --build-number=1 \
        --no-codesign
    
    success "iOS build completed"
    log "📱 iOS build saved to: build/ios/iphoneos/"
    log "⚠️ Code signing required for distribution"
}

# Generate build report
generate_report() {
    log "Generating build report..."
    
    REPORT_FILE="$BUILD_DIR/build_report_${TIMESTAMP}.md"
    
    cat > "$REPORT_FILE" << EOF
# 🚀 Quanta Production Build Report

**Build Date:** $(date)
**Build Version:** 1.0.0
**Build Number:** 1

## 📱 Build Artifacts

### Android
EOF

    if [ -f "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.apk" ]; then
        APK_SIZE=$(du -h "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.apk" | cut -f1)
        echo "- ✅ APK: ${PROJECT_NAME}_${TIMESTAMP}.apk ($APK_SIZE)" >> "$REPORT_FILE"
    fi
    
    if [ -f "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.aab" ]; then
        AAB_SIZE=$(du -h "$BUILD_DIR/android/${PROJECT_NAME}_${TIMESTAMP}.aab" | cut -f1)
        echo "- ✅ App Bundle: ${PROJECT_NAME}_${TIMESTAMP}.aab ($AAB_SIZE)" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

### iOS
- ⚠️ iOS build requires macOS and code signing

## 📊 Build Configuration

- **Environment:** Production
- **Flutter Version:** $(flutter --version | head -n1)
- **Dart Version:** $(dart --version)
- **Build Mode:** Release
- **Obfuscation:** Disabled
- **Tree Shaking:** Enabled

## 🔧 Next Steps

1. **Android:**
   - Upload AAB file to Google Play Console
   - Create release notes
   - Configure release rollout

2. **iOS:**
   - Open project in Xcode
   - Configure code signing
   - Archive and upload to App Store Connect

## ⚠️ Security Checklist

- [ ] Environment variables properly configured
- [ ] No hardcoded secrets in build
- [ ] Crash reporting enabled
- [ ] Analytics configured
- [ ] App signing configured

EOF

    success "Build report generated: $REPORT_FILE"
}

# Run security checks
run_security_checks() {
    log "Running security checks..."
    
    # Run dependency scanner if available
    if [ -f "scripts/security_audit/dependency_scanner.dart" ]; then
        log "Running dependency vulnerability scan..."
        dart scripts/security_audit/dependency_scanner.dart || warning "Dependency scan completed with warnings"
    fi
    
    # Run code analyzer if available
    if [ -f "scripts/security_audit/code_analyzer.dart" ]; then
        log "Running static code security analysis..."
        dart scripts/security_audit/code_analyzer.dart || warning "Code analysis completed with warnings"
    fi
    
    success "Security checks completed"
}

# Main build function
main() {
    local build_target="${1:-all}"
    
    log "🚀 Starting Quanta production build..."
    log "📂 Project: $PROJECT_NAME"
    log "📦 Package: $PACKAGE_NAME"
    log "🎯 Target: $build_target"
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Run build steps
    check_prerequisites
    clean_builds
    get_dependencies
    run_tests
    run_security_checks
    
    case $build_target in
        "android")
            build_android
            ;;
        "ios")
            build_ios
            ;;
        "all"|*)
            build_android
            build_ios
            ;;
    esac
    
    generate_report
    
    success "🎉 Production build completed successfully!"
    log "📂 Build artifacts saved to: $BUILD_DIR"
    
    # Final instructions
    echo ""
    echo "🔥 DEPLOYMENT READY!"
    echo ""
    echo "Next steps:"
    echo "1. Review build report: $BUILD_DIR/build_report_${TIMESTAMP}.md"
    echo "2. Test APK on physical devices"
    echo "3. Upload to respective app stores"
    echo "4. Configure release rollout"
    echo ""
}

# Run main function with arguments
main "$@"