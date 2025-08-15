#!/usr/bin/env python3
"""
Quanta App Icon Setup Script
Generates all required icon sizes from a source 1024x1024 image
"""

import os
import sys
from PIL import Image
import json

# Required icon sizes
ICON_SIZES = {
    'ios': [
        (1024, 1024, 'ios-marketing'),
        (180, 180, 'iphone-app-60pt@3x'),
        (167, 167, 'ipad-pro-app'),
        (152, 152, 'ipad-app-76pt@2x'),
        (120, 120, 'iphone-app-60pt@2x'),
        (87, 87, 'iphone-settings-29pt@3x'),
        (80, 80, 'iphone-spotlight-40pt@2x'),
        (76, 76, 'ipad-app-76pt@1x'),
        (58, 58, 'iphone-settings-29pt@2x'),
        (40, 40, 'iphone-spotlight-40pt@1x'),
        (29, 29, 'iphone-settings-29pt@1x'),
        (20, 20, 'iphone-notification-20pt@1x'),
    ],
    'android': [
        (192, 192, 'xxxhdpi'),
        (144, 144, 'xxhdpi'),
        (96, 96, 'xhdpi'),
        (72, 72, 'hdpi'),
        (48, 48, 'mdpi'),
    ],
    'store': [
        (512, 512, 'play_store'),
        (1024, 500, 'play_store_feature'),
    ]
}

def create_directories():
    """Create necessary directories for icons"""
    directories = [
        'assets/app_icons/generated/ios',
        'assets/app_icons/generated/android',
        'assets/app_icons/generated/store',
        'android/app/src/main/res/mipmap-xxxhdpi',
        'android/app/src/main/res/mipmap-xxhdpi',
        'android/app/src/main/res/mipmap-xhdpi',
        'android/app/src/main/res/mipmap-hdpi',
        'android/app/src/main/res/mipmap-mdpi',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    ]
    
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
        print(f"✅ Created directory: {directory}")

def generate_icons(source_image_path):
    """Generate all required icon sizes from source image"""
    if not os.path.exists(source_image_path):
        print(f"❌ Source image not found: {source_image_path}")
        return False
    
    try:
        # Open source image
        with Image.open(source_image_path) as img:
            # Verify source image dimensions
            if img.size != (1024, 1024):
                print(f"⚠️  Warning: Source image is {img.size}, recommended: (1024, 1024)")
            
            # Generate iOS icons
            print("\n🍎 Generating iOS icons...")
            for width, height, name in ICON_SIZES['ios']:
                resized = img.resize((width, height), Image.Resampling.LANCZOS)
                output_path = f"assets/app_icons/generated/ios/icon_{width}x{height}_{name}.png"
                resized.save(output_path, 'PNG')
                print(f"   ✅ {width}x{height} -> {output_path}")
            
            # Generate Android icons
            print("\n🤖 Generating Android icons...")
            for width, height, density in ICON_SIZES['android']:
                resized = img.resize((width, height), Image.Resampling.LANCZOS)
                
                # Save in assets for reference
                output_path = f"assets/app_icons/generated/android/icon_{width}x{height}_{density}.png"
                resized.save(output_path, 'PNG')
                
                # Save in Android mipmap folders
                android_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
                resized.save(android_path, 'PNG')
                
                # Also create round version (same image for now)
                android_round_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png"
                resized.save(android_round_path, 'PNG')
                
                print(f"   ✅ {width}x{height} -> {android_path}")
            
            # Generate store assets
            print("\n🏪 Generating store assets...")
            for width, height, name in ICON_SIZES['store']:
                if width == 1024 and height == 500:
                    # Create feature graphic (landscape format)
                    feature_img = Image.new('RGB', (1024, 500), color='#1976D2')
                    # Center the icon in the feature graphic
                    icon_resized = img.resize((400, 400), Image.Resampling.LANCZOS)
                    feature_img.paste(icon_resized, (312, 50), icon_resized if icon_resized.mode == 'RGBA' else None)
                    output_path = f"assets/app_icons/generated/store/feature_graphic_1024x500.png"
                    feature_img.save(output_path, 'PNG')
                else:
                    resized = img.resize((width, height), Image.Resampling.LANCZOS)
                    output_path = f"assets/app_icons/generated/store/icon_{width}x{height}_{name}.png"
                    resized.save(output_path, 'PNG')
                print(f"   ✅ {width}x{height} -> {output_path}")
            
        return True
        
    except Exception as e:
        print(f"❌ Error generating icons: {e}")
        return False

def create_ios_contents_json():
    """Create Contents.json file for iOS AppIcon.appiconset"""
    contents = {
        "images": [
            {"filename": "icon_1024x1024_ios-marketing.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"},
            {"filename": "icon_180x180_iphone-app-60pt@3x.png", "idiom": "iphone", "scale": "3x", "size": "60x60"},
            {"filename": "icon_120x120_iphone-app-60pt@2x.png", "idiom": "iphone", "scale": "2x", "size": "60x60"},
            {"filename": "icon_87x87_iphone-settings-29pt@3x.png", "idiom": "iphone", "scale": "3x", "size": "29x29"},
            {"filename": "icon_58x58_iphone-settings-29pt@2x.png", "idiom": "iphone", "scale": "2x", "size": "29x29"},
            {"filename": "icon_29x29_iphone-settings-29pt@1x.png", "idiom": "iphone", "scale": "1x", "size": "29x29"},
            {"filename": "icon_80x80_iphone-spotlight-40pt@2x.png", "idiom": "iphone", "scale": "2x", "size": "40x40"},
            {"filename": "icon_40x40_iphone-spotlight-40pt@1x.png", "idiom": "iphone", "scale": "1x", "size": "40x40"},
            {"filename": "icon_20x20_iphone-notification-20pt@1x.png", "idiom": "iphone", "scale": "1x", "size": "20x20"},
            {"filename": "icon_167x167_ipad-pro-app.png", "idiom": "ipad", "scale": "2x", "size": "83.5x83.5"},
            {"filename": "icon_152x152_ipad-app-76pt@2x.png", "idiom": "ipad", "scale": "2x", "size": "76x76"},
            {"filename": "icon_76x76_ipad-app-76pt@1x.png", "idiom": "ipad", "scale": "1x", "size": "76x76"},
        ],
        "info": {
            "author": "Quanta App Icon Generator",
            "version": 1
        }
    }
    
    contents_path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    
    print(f"✅ Created iOS Contents.json: {contents_path}")

def copy_icons_to_ios():
    """Copy generated iOS icons to the AppIcon.appiconset folder"""
    source_dir = "assets/app_icons/generated/ios"
    target_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(source_dir):
        print(f"❌ iOS icons not found in {source_dir}")
        return
    
    for filename in os.listdir(source_dir):
        if filename.endswith('.png'):
            source_path = os.path.join(source_dir, filename)
            target_path = os.path.join(target_dir, filename)
            
            # Copy file
            import shutil
            shutil.copy2(source_path, target_path)
            print(f"   📁 Copied {filename} to iOS AppIcon.appiconset")

def print_next_steps():
    """Print next steps for manual configuration"""
    print("\n🎉 Icon generation complete!")
    print("\n📋 Next Steps:")
    print("1. ✅ Icons have been generated and placed in the correct directories")
    print("2. 🔄 Clean and rebuild your Flutter project:")
    print("   flutter clean && flutter pub get")
    print("3. 📱 Test on physical devices to verify icon appearance")
    print("4. 🏪 Use the store assets in assets/app_icons/generated/store/ for app store submissions")
    print("5. 📝 Update app names in AndroidManifest.xml and Info.plist if not already done")
    print("\n🔍 Generated files locations:")
    print("   • iOS icons: ios/Runner/Assets.xcassets/AppIcon.appiconset/")
    print("   • Android icons: android/app/src/main/res/mipmap-*/")
    print("   • Store assets: assets/app_icons/generated/store/")

def main():
    if len(sys.argv) != 2:
        print("Usage: python setup_app_icon.py <source_image_path>")
        print("Example: python setup_app_icon.py assets/app_icons/quanta_icon_1024.png")
        sys.exit(1)
    
    source_image = sys.argv[1]
    
    print("🚀 Quanta App Icon Setup")
    print("=" * 50)
    
    # Create directories
    create_directories()
    
    # Generate icons
    if generate_icons(source_image):
        create_ios_contents_json()
        copy_icons_to_ios()
        print_next_steps()
    else:
        print("❌ Icon generation failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
