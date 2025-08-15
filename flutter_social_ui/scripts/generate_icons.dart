#!/usr/bin/env dart

import 'dart:io';

/// App icon generation and configuration script for Quanta
void main() async {
  print('🎨 Quanta App Icon Generator');
  print('=' * 40);
  
  await _createIconManifest();
  await _generateIconSizes();
  await _updateFlutterIconConfig();
  
  print('\n✅ Icon generation complete!');
  print('📋 Next Steps:');
  print('1. Replace assets/icons/app_icon.png with your custom Quanta icon (1024x1024)');
  print('2. Run: flutter pub get');
  print('3. Run: dart run flutter_launcher_icons');
  print('4. Test the app to verify icons appear correctly');
}

/// Create icon manifest and directory structure
Future<void> _createIconManifest() async {
  print('📁 Creating icon directory structure...');
  
  // Create directories
  await Directory('assets/icons').create(recursive: true);
  await Directory('assets/app_icons').create(recursive: true);
  
  // Create app icon placeholder (you should replace this with actual icon)
  await _createIconPlaceholder();
  
  print('✅ Icon directories created');
}

/// Create a simple placeholder icon description
Future<void> _createIconPlaceholder() async {
  final iconReadme = '''# Quanta App Icons

## Required Icons

### Master Icon (app_icon.png)
- Size: 1024x1024 pixels
- Format: PNG with transparent background
- Design: Quanta logo with "Q" symbol and modern AI/avatar theme
- Colors: Primary - #6366f1 (Indigo), Secondary - #1a1a1a (Dark)

### Design Guidelines
1. **Symbol**: Stylized "Q" that represents both "Quanta" and quantum computing
2. **Theme**: AI/Avatar focused with modern geometric design
3. **Colors**: Use the app's primary indigo color with gradient effects
4. **Background**: Transparent or subtle gradient
5. **Style**: Modern, flat design with slight 3D effect

### Auto-Generated Sizes
The flutter_launcher_icons package will generate these sizes:
- Android: 36x36, 48x48, 72x72, 96x96, 144x144, 192x192
- iOS: 20x20, 29x29, 40x40, 58x58, 60x60, 76x76, 87x87, 114x114, 120x120, 152x152, 167x167, 180x180, 1024x1024
- Web: 192x192, 512x512

## Design Inspiration
- Modern social media apps (clean, recognizable)
- AI/Tech companies (gradient, futuristic)
- Avatar/gaming apps (character-focused)

Replace the placeholder files with professional designs before production!
''';

  await File('assets/app_icons/README.md').writeAsString(iconReadme);
}

/// Generate different icon sizes for testing
Future<void> _generateIconSizes() async {
  print('🔢 Setting up icon size specifications...');
  
  // Create a simple SVG placeholder that can be converted to different sizes
  final svgPlaceholder = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6366f1;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#4f46e5;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- Background Circle -->
  <circle cx="512" cy="512" r="450" fill="url(#grad)" stroke="#1a1a1a" stroke-width="8"/>
  
  <!-- Q Letter -->
  <text x="512" y="600" font-family="Arial Black, sans-serif" font-size="400" font-weight="bold" 
        text-anchor="middle" fill="white">Q</text>
  
  <!-- Small AI indicator -->
  <circle cx="700" cy="700" r="80" fill="#1a1a1a"/>
  <circle cx="700" cy="700" r="50" fill="#00ff88"/>
  <circle cx="700" cy="700" r="20" fill="white"/>
</svg>''';

  await File('assets/icons/app_icon.svg').writeAsString(svgPlaceholder);
  
  print('✅ Icon specifications created');
}

/// Update flutter_launcher_icons configuration
Future<void> _updateFlutterIconConfig() async {
  print('⚙️ Updating Flutter launcher icons configuration...');
  
  // Read current pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  var pubspecContent = await pubspecFile.readAsString();
  
  // Add flutter_launcher_icons dependency if not present
  if (!pubspecContent.contains('flutter_launcher_icons:')) {
    pubspecContent = pubspecContent.replaceFirst(
      '  # Linting and Code Quality\n  flutter_lints: ^5.0.0',
      '  # Linting and Code Quality\n  flutter_lints: ^5.0.0\n  \n  # Icon Generation\n  flutter_launcher_icons: ^0.13.1'
    );
  }
  
  // Add flutter_launcher_icons configuration if not present
  if (!pubspecContent.contains('flutter_launcher_icons:')) {
    pubspecContent += '''

# Flutter Launcher Icons Configuration
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icons/app_icon.png"
  min_sdk_android: 21
  web:
    generate: true
    image_path: "assets/icons/app_icon.png"
    background_color: "#1a1a1a"
    theme_color: "#6366f1"
  windows:
    generate: true
    image_path: "assets/icons/app_icon.png"
    icon_size: 48
  macos:
    generate: true
    image_path: "assets/icons/app_icon.png"
''';
  }
  
  await pubspecFile.writeAsString(pubspecContent);
  
  print('✅ Pubspec.yaml updated with icon configuration');
}
