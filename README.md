<div align="center">

<img src="assets/brand/glad_logo.png" width="120" alt="Glad" />

# Glad

### Watch it. Read it. Remember it.

An Android app for anime, movies, series, manga and light novels, with a stats
page that remembers what you watched and read.

</div>

---

## What's new in Glad

- **Memories**: hours watched, movies finished, series and anime started,
  manga and novel chapters read, a day streak, and a month calendar that lights
  up on every day you watched or read. Open it from the banner at the top of
  Home or from Settings. It is recorded on your device and starts exact from
  the day you install; existing history is imported once as an estimate.
- **Spotlight**: a coverflow carousel and a swipe stack on Home. Drag a card
  right to save it to My List, left to skip, tap to open.
- **New look**: new violet palette, new logo mark, splash and loading animation.

## Download

Get the latest APK from the
[Releases](https://github.com/akshaytharayal-glitch/Glad/releases/latest) page.

| APK | Use it for |
|---|---|
| `Glad-vX.Y.Z-arm64-v8a.apk` | Most modern phones (recommended) |
| `Glad-vX.Y.Z-armeabi-v7a.apk` | Older 32-bit phones |
| `Glad-vX.Y.Z-universal.apk` | Not sure? Works on both, larger |

## Building

Every push to `main` runs **Actions → Build Glad APK**, which builds the APKs
and publishes them as a GitHub Release. You can also run it by hand from the
Actions tab.

To sign releases with your own key, add these repository secrets:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Without them the build uses the fallback key in
`android/glad-ci.keystore`.

### Changing the logo or loading animation

Replace these files and push:

| File | What it is |
|---|---|
| `assets/brand/glad_logo.png` | Square logo, 1024x1024 recommended |
| `assets/brand/glad_logo_fg.png` | Optional transparent mark for the adaptive launcher icon |
| `assets/brand/glad_wordmark.png` | Optional "Glad" lettering for headers |
| `assets/brand/glad_loader.gif` | Loading animation |

The build runs `tool/apply_glad_logo.py`, which regenerates every launcher icon
size and the in-app logo images from them.

### Discord Rich Presence

Discord's SDK is proprietary and is not in this repository, so Rich Presence is
off by default. To enable it, install the SDK with `tool/setup_discord_sdk.py`.

## Credits and license

Glad is a fork of [Zangetsu](https://github.com/Spyou/Zangetsu) by Krishna
Vishwakarma and is released under the same license, **GPL-3.0**. See
[LICENSE](LICENSE) and [NOTICE.md](NOTICE.md) for the full text and third-party
notices.

Glad does not host, provide or distribute any streaming content. It is a
tracking and management tool.
