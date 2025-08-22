# 🔐 Code Signing Configuration Guide

This guide provides comprehensive instructions for configuring code signing and certificates for the Quanta app on both Android and iOS platforms.

## 📱 Android Code Signing

### Step 1: Generate Signing Key

```bash
# Navigate to android/app directory
cd android/app

# Generate keystore (replace with your details)
keytool -genkey -v -keystore ~/quanta-release-key.keystore \
    -alias quanta-key-alias \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass YOUR_STORE_PASSWORD \
    -keypass YOUR_KEY_PASSWORD \
    -dname "CN=MyNkayenzi, OU=Development, O=MyNkayenzi, L=City, ST=State, C=US"
```

### Step 2: Configure Gradle Signing

Create `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=quanta-key-alias
storeFile=../quanta-release-key.keystore
```

### Step 3: Update android/app/build.gradle

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    compileSdkVersion flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId "com.mynkayenzi.quanta"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### Step 4: Security Best Practices

**Important Security Notes:**

- ⚠️ **NEVER commit `key.properties` or keystore files to version control**
- 🔒 Store keystore files securely (cloud storage, secure backup)
- 📝 Document keystore passwords securely (password manager)
- 🔄 Create backup copies of keystore files
- 📋 Keep record of keystore details for Play Store

Add to `.gitignore`:

```
android/key.properties
android/app/*.keystore
android/app/*.jks
*.keystore
*.jks
```

### Step 5: Verify Android Signing

```bash
# Build signed APK
flutter build apk --release

# Verify APK signature
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# Check APK details
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```

## 🍎 iOS Code Signing

### Step 1: Apple Developer Account Setup

1. **Enroll in Apple Developer Program**

   - Visit [developer.apple.com](https://developer.apple.com)
   - Enroll in Apple Developer Program ($99/year)
   - Complete enrollment process

2. **Create App Identifier**
   - Go to Certificates, Identifiers & Profiles
   - Create new App Identifier: `com.mynkayenzi.quanta`
   - Enable required capabilities (Push Notifications, etc.)

### Step 2: Certificate Management

#### Development Certificate

```bash
# Generate Certificate Signing Request (CSR)
# Use Keychain Access > Certificate Assistant > Request Certificate
# Save CSR file for upload to Apple Developer Portal
```

#### Distribution Certificate

1. Create Distribution Certificate in Apple Developer Portal
2. Download and install certificate
3. Verify certificate in Keychain Access

### Step 3: Provisioning Profiles

#### Development Provisioning Profile

```bash
# Create in Apple Developer Portal
# - Select App ID: com.mynkayenzi.quanta
# - Select Development Certificates
# - Select Development Devices
# - Download and install profile
```

#### Distribution Provisioning Profile

```bash
# Create in Apple Developer Portal
# - Select App ID: com.mynkayenzi.quanta
# - Select Distribution Certificate
# - For App Store: no devices needed
# - Download and install profile
```

### Step 4: Xcode Configuration

Open `ios/Runner.xcworkspace` in Xcode:

1. **Select Runner target**
2. **Signing & Capabilities tab**
3. **Configure signing:**
   - Team: Select your development team
   - Bundle Identifier: `com.mynkayenzi.quanta`
   - Provisioning Profile: Select appropriate profile

#### Manual Signing Configuration

```yaml
# ios/Runner/Info.plist
<key>CFBundleIdentifier</key>
<string>com.mynkayenzi.quanta</string>
<key>CFBundleName</key>
<string>Quanta</string>
<key>CFBundleDisplayName</key>
<string>Quanta</string>
```

### Step 5: Build Configuration

#### Debug Configuration

```bash
# For development builds
flutter build ios --debug --flavor development
```

#### Release Configuration

```bash
# For App Store submission
flutter build ios --release --flavor production
```

### Step 6: Archive and Upload

```bash
# Build iOS archive
flutter build ios --release

# Open Xcode for archiving
open ios/Runner.xcworkspace

# In Xcode:
# 1. Product > Archive
# 2. Window > Organizer
# 3. Select archive > Distribute App
# 4. App Store Connect > Upload
```

## 🔧 Automation Scripts

### Android Signing Script

Create `scripts/signing/sign_android.sh`:

```bash
#!/bin/bash
# Android signing automation script

set -e

KEYSTORE_PATH="$HOME/quanta-release-key.keystore"
KEY_ALIAS="quanta-key-alias"

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "❌ Keystore not found: $KEYSTORE_PATH"
    exit 1
fi

if [ ! -f "android/key.properties" ]; then
    echo "❌ key.properties not found"
    exit 1
fi

echo "🔐 Building signed Android release..."
flutter build appbundle --release

echo "✅ Signed App Bundle created:"
ls -la build/app/outputs/bundle/release/app-release.aab

echo "🔍 Verifying signature..."
jarsigner -verify build/app/outputs/bundle/release/app-release.aab
echo "✅ Signature verification completed"
```

### iOS Signing Script

Create `scripts/signing/sign_ios.sh`:

```bash
#!/bin/bash
# iOS signing automation script

set -e

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ iOS signing requires macOS"
    exit 1
fi

echo "🍎 Building iOS release..."
flutter build ios --release

echo "🔐 Opening Xcode for manual archiving..."
open ios/Runner.xcworkspace

echo "📋 Next steps:"
echo "1. In Xcode: Product > Archive"
echo "2. Window > Organizer"
echo "3. Select archive > Distribute App"
echo "4. Choose distribution method"
echo "5. Upload to App Store Connect"
```

## 📋 Code Signing Checklist

### Android Checklist

- [ ] Keystore generated and secured
- [ ] `key.properties` configured (not in git)
- [ ] `build.gradle` updated with signing config
- [ ] APK/AAB builds and signs successfully
- [ ] Signature verified with jarsigner
- [ ] Keystore backed up securely

### iOS Checklist

- [ ] Apple Developer account active
- [ ] App Identifier created
- [ ] Development certificate installed
- [ ] Distribution certificate installed
- [ ] Development provisioning profile installed
- [ ] Distribution provisioning profile installed
- [ ] Xcode project configured
- [ ] Build and archive successful
- [ ] App uploaded to App Store Connect

## 🚨 Troubleshooting

### Android Issues

**Keystore not found:**

```bash
# Verify keystore location
ls -la ~/quanta-release-key.keystore

# Check key.properties path
cat android/key.properties
```

**Signing failed:**

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build appbundle --release --verbose
```

### iOS Issues

**Certificate issues:**

```bash
# List certificates
security find-identity -p codesigning

# Reset certificates
# Delete from Keychain Access and re-download
```

**Provisioning profile issues:**

```bash
# List profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/
```

## 🔒 Security Recommendations

1. **Keystore Security:**

   - Use strong passwords (minimum 12 characters)
   - Store keystore files in secure locations
   - Create encrypted backups
   - Document passwords in secure password manager

2. **Certificate Management:**

   - Regularly review installed certificates
   - Remove unused/expired certificates
   - Monitor certificate expiration dates
   - Use different certificates for development/production

3. **Access Control:**

   - Limit access to signing materials
   - Use CI/CD secure storage for automation
   - Implement audit logging for signing operations
   - Regular security reviews

4. **Backup Strategy:**
   - Multiple secure backup locations
   - Test backup restoration process
   - Document recovery procedures
   - Version control for configuration (not secrets)

## 📞 Support

If you encounter issues with code signing:

1. Check Flutter documentation: [flutter.dev/docs/deployment](https://flutter.dev/docs/deployment)
2. Android signing: [developer.android.com/studio/publish/app-signing](https://developer.android.com/studio/publish/app-signing)
3. iOS signing: [developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
4. Flutter community: [github.com/flutter/flutter/issues](https://github.com/flutter/flutter/issues)

---

**⚠️ Important:** Never share signing certificates, keystores, or passwords. Always follow platform-specific security guidelines for production apps.
