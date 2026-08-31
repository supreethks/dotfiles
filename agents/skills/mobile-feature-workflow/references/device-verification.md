# Verifying on connected devices

Read this before driving a physical device. Several steps here are irreversible on someone's personal phone, and the failure mode is destroying their real data — not a broken build.

## Contents

- [Discovering what is attached](#discovering-what-is-attached)
- [Android: installing without destroying data](#android-installing-without-destroying-data)
- [iOS: simulators and physical devices](#ios-simulators-and-physical-devices)
- [Driving the app](#driving-the-app)
- [Reading state you cannot read directly](#reading-state-you-cannot-read-directly)
- [Restoring state afterwards](#restoring-state-afterwards)

## Discovering what is attached

```bash
adb devices -l                       # emulator-* are emulators, everything else is physical
xcrun devicectl list devices         # physical iOS, look for state "connected"
xcrun simctl list devices booted     # booted simulators
```

Prefer an **emulator or simulator** for anything exploratory or destructive. Reserve the physical device for confirming the change looks right on real hardware, and for behaviour that simulators cannot reproduce (Play Billing, StoreKit, real Google Photos, notification delivery).

When no physical device is attached, boot a virtual one and verify there — never skip the step. A simulated run still catches unreachable flows, broken navigation, wrong empty states and layout regressions.

**ViMark only:** AVD `Vimark_Pixel_8` on port `5574` (`ANDROID_SERIAL=emulator-5574`). Never steal `Pixel_8` / `Small_Phone`. Boot: `~/.agents/skills/vimark-feature-workflow/scripts/boot-android-emulator.sh`.

```bash
# ViMark
export ANDROID_SERIAL=emulator-5574
~/.agents/skills/vimark-feature-workflow/scripts/boot-android-emulator.sh
# Other projects — never use port 5574 or AVD Vimark_Pixel_8
~/Library/Android/sdk/emulator/emulator -list-avds
~/Library/Android/sdk/emulator/emulator -avd <name> -no-snapshot-load -no-boot-anim
adb -s "$ANDROID_SERIAL" wait-for-device
adb -s "$ANDROID_SERIAL" shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'

# iOS
xcrun simctl list devices available | grep iPhone
xcrun simctl boot <udid>
xcrun simctl bootstatus <udid> -b
```

Emulators you started are yours to clean up (`adb -s <serial> emu kill`). Simulators can be left booted, but reset any state you dirtied.

When more than one device is attached, every single command must name its target:

```bash
adb -s <serial> shell ...
xcrun simctl <verb> <udid> ...
xcodebuild ... -destination 'id=<device-id>'
```

An unqualified `adb shell pm clear <package>` picks whichever device adb feels like and can wipe the user's real app data. `xcodebuild -showdestinations` is worth running once: physical devices often appear there under a **different identifier** than `devicectl` reports, and using the wrong one fails with an unhelpful "Unable to find a device matching the provided destination specifier".

## Android: installing without destroying data

`adb install -r` fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` when the installed app was signed with a different key — which is exactly the case when the phone has a Play Store or release build and you are holding a debug APK.

**Do not uninstall to work around this.** Uninstalling deletes the app's database and preferences permanently. On a personal phone that is the user's real content.

Instead build a release APK signed with the project's own key and install it over the top; the data survives:

```bash
cd android && ./gradlew assembleRelease
adb -s <serial> install -r app/build/outputs/apk/release/app-release.apk
```

This requires the signing config to resolve (typically a `keystore.properties` and keystore, often symlinked from outside the repo). If it does not resolve, stop and ask — do not fall back to uninstalling.

Two consequences of testing on a release build worth telling the user about:

- **Analytics fire for real.** Debug builds usually short-circuit event logging (`if (BuildConfig.DEBUG) return`); release builds do not. Test interactions land in production analytics and can pollute an experiment you are about to read.
- **`run-as` does not work**, so the app's databases and preferences are unreadable over adb. You must infer state from the UI.

Verify what actually landed:

```bash
adb -s <serial> shell dumpsys package <pkg> | grep -E "versionName|versionCode|firstInstallTime"
```

## iOS: simulators and physical devices

Simulator install and launch, including launch arguments (which is how you force a starting state):

```bash
xcrun simctl install <udid> <path>/App.app
xcrun simctl launch  <udid> <bundle-id> -someLaunchFlag YES -anotherFlag
xcrun simctl io <udid> screenshot out.png
```

Launch arguments also seed `UserDefaults`: passing `-myPrefKey YES` makes `UserDefaults.standard.bool(forKey: "myPrefKey")` return true for that launch, without persisting. This is the cleanest way to flip a developer toggle you would otherwise have to reach through the UI.

**Keychain data survives app uninstall on iOS.** Anything stored there — trial start dates, device identifiers, anti-abuse state — persists across `simctl uninstall` and reinstall, which will silently invalidate a "fresh install" test. Reset it explicitly:

```bash
xcrun simctl keychain <udid> reset
```

Physical device builds need a signed build and `-allowProvisioningUpdates`:

```bash
xcodebuild -project <p>.xcodeproj -scheme <s> -configuration Debug \
  -destination 'id=<id-from-showdestinations>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <devicectl-id> <path>/App.app
```

A `Failed to load provisioning parameter list ... No provider was found` warning in `devicectl` output is noise; judge success by the `App installed:` block that follows.

## Driving the app

The device MCP works against both platforms. Prefer the element tree over screenshots for finding things — it gives exact coordinates and accessibility identifiers, and it tells you whether a control exists at all:

```
mobile_list_elements_on_screen        → elements with coordinates and identifiers
mobile_click_on_screen_at_coordinates → tap (coordinates from the element tree)
mobile_type_keys                      → type into the focused field
mobile_take_screenshot                → visual check
```

Element coordinates come back as the element's **top-left plus width/height**; tap the centre, not the origin.

If the MCP cannot reach a device (access not granted, panel not attached), fall back to platform tooling rather than stalling:

```bash
adb -s <serial> shell input tap <x> <y>
adb -s <serial> shell input text "hello"
adb -s <serial> shell input keyevent KEYCODE_BACK
adb -s <serial> exec-out screencap -p > shot.png
```

Note the coordinate systems differ: `adb input` uses raw pixels, while the MCP and `xcrun simctl` use points. A screenshot at 1080×2400 pixels is 402×874 points on a 3× device — do not mix them.

**Date and number fields are locale-formatted.** A field showing `MM/DD/YYYY` on one device shows `YYYY/MM/DD` on another, so the same digit string produces a valid date on one and a validation error on the other. Screenshot the placeholder and type in the order it actually specifies.

## Reading state you cannot read directly

On a release build you cannot read preferences over adb. Two ways through:

1. **Infer from the UI.** A screen that renders one of two mutually exclusive states is a reliable one-bit read. If the dashboard shows a demo timeline when a flag is on and an empty-state CTA when it is off, then which one renders tells you the flag's value.

2. **Use the app's own diagnostics.** Many apps have a hidden developer menu (often a long-press on a logo, sometimes gated on a companion "key" app being installed). If it has a "copy debug info" action, extend it to print whatever state you keep needing — that helps every future debugging session too.

When testing a remote feature flag, **turn off any local override first**, then cold-restart, then confirm the override really is off before drawing a conclusion. A flag that appears to work while an override is still on has proved nothing. Cold restart matters because flag values are usually fetched once per launch and cached.

## Restoring state afterwards

Leave the device as you found it and say exactly what changed.

- Delete test records you created, through the app's own UI so its internal bookkeeping stays consistent.
- Return developer/QA toggles to their original positions — note them before you change anything.
- Shut down emulators you started (`adb -s <serial> emu kill`) and reset simulator state you dirtied.
- Some effects cannot be undone through the UI — a started trial clock, a consumed one-time prompt, analytics already emitted. Call these out explicitly rather than letting the user discover them later.

Then report what was verified, on which device, and what residue remains.
