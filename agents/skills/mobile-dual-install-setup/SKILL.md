---
name: mobile-dual-install-setup
description: Enforce dual side-by-side installation of Debug and Release builds on Android and iOS with grayscale debug icons, debug app names, and dynamic package qualifiers. Use when setting up new mobile projects, configuring build types/schemes, adding providers/components, or customizing app launcher icons.
---

# Mobile Dual-Install Setup (Debug & Release Coexistence)

## Core Philosophy
Every mobile project (Android and iOS) MUST support installing both the **Production/Release** build (from Play Store / App Store) and the **Debug** build simultaneously on the same physical device or emulator without signature, package name, authority, or bundle ID collisions.

**ViMark:** install only to AVD `Vimark_Pixel_8` (`ANDROID_SERIAL=emulator-5574`). Do not use `Pixel_8`, `Small_Phone`, or a physical device unless the user names it.

---

## 1. Android Configuration

### A. Gradle Application ID Suffix
In `app/build.gradle.kts`:
```kotlin
android {
    defaultConfig {
        applicationId = "com.example.app"
        // ...
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            // Debug-specific API keys or flags
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            // ...
        }
    }
}
```

### B. Debug App Name
1. In `app/src/main/res/values/strings.xml`:
   ```xml
   <string name="app_name">AppName</string>
   ```
2. In `app/src/debug/res/values/strings.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <resources>
       <string name="app_name">AppName (Debug)</string>
   </resources>
   ```
   *Gradle resource merging will automatically override the label for Debug builds while keeping all 26+ release translations intact.*

### C. Grayscale Debug App Icon
Debug builds must have a distinct, visually identifiable **grayscale** icon so developers and testers never confuse debug builds with production:
1. Place grayscale versions of `ic_launcher.png`, `ic_launcher_round.png`, and `ic_launcher_foreground.png` in `app/src/debug/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/`.
2. Provide a dark/slate adaptive icon background in `app/src/debug/res/drawable/ic_launcher_background.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <shape xmlns:android="http://schemas.android.com/apk/res/android">
       <gradient
           android:type="linear"
           android:startColor="#616161"
           android:centerColor="#37474F"
           android:endColor="#212121"
           android:angle="135" />
   </shape>
   ```
3. Use macOS `sips` to generate grayscale icons automatically:
   ```bash
   sips -m "/System/Library/ColorSync/Profiles/Generic Gray Gamma 2.2 Profile.icc" input.png --out output_gray.png
   ```

### D. Component & Provider Isolation (Zero Clashes)
In `AndroidManifest.xml`, NEVER hardcode package names in `android:authorities` or custom permissions:
```xml
<!-- ALWAYS USE ${applicationId} -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

### E. Google Services (`google-services.json`)
1. Ensure `app/google-services.json` contains client blocks for both:
   - `com.example.app` (Release)
   - `com.example.app.debug` (Debug)
2. In addition, place `app/src/debug/google-services.json` configured specifically for `com.example.app.debug`. This ensures CI build pipelines (which often inject a production `google-services.json` from secrets) always compile debug test tasks cleanly without missing client errors.

---

## 2. iOS Configuration

### A. Bundle Identifier Differentiation
In `project.pbxproj` (or `.xcconfig`):
- **Debug Configuration**:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.example.app.debug;`
  - `INFOPLIST_KEY_CFBundleDisplayName = "AppName (Debug)";`
  - `ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-Debug";`
- **Release Configuration**:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.example.app;`
  - `INFOPLIST_KEY_CFBundleDisplayName = AppName;`
  - `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;`

### B. App Extensions & Widgets Rule
Any embedded binary (Widget Extension, Share Extension, Notification Service) in Debug MUST have its bundle ID prefixed with the main app's debug bundle ID:
- Main App: `com.example.app.debug`
- Widget Extension: `com.example.app.debug.widgets` (Debug) vs `com.example.app.widgets` (Release).

### C. Grayscale Debug AppIcon Asset
1. In `Assets.xcassets`, create `AppIcon-Debug.appiconset`.
2. Add grayscale versions of the 1024x1024 app icon.
3. Configure `Contents.json`:
   ```json
   {
     "images" : [
       {
         "filename" : "AppIcon.png",
         "idiom" : "universal",
         "platform" : "ios",
         "size" : "1024x1024"
       }
     ],
     "info" : {
       "author" : "xcode",
       "version" : 1
     }
   }
   ```

---

## 3. Automation Checklist for New Projects
When scaffolding or reviewing a mobile repository:
1. [ ] Configure `applicationIdSuffix = ".debug"` in Android `buildTypes.debug`.
2. [ ] Create `app/src/debug/res/values/strings.xml` with `app_name = "<AppName> (Debug)"`.
3. [ ] Generate grayscale debug launcher icons in `app/src/debug/res/mipmap-*`.
4. [ ] Verify all AndroidManifest authorities use `${applicationId}`.
5. [ ] Configure `PRODUCT_BUNDLE_IDENTIFIER = <id>.debug` and `CFBundleDisplayName = "<AppName> (Debug)"` in iOS Xcode project Debug configuration.
6. [ ] Create `AppIcon-Debug.appiconset` with grayscale icon in iOS Assets.
7. [ ] Build and install both Debug and Release simultaneously to verify zero collision.
