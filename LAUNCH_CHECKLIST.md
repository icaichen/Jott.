# App launch checklist

## What’s already done

- **App icon** – `assets/logos/Jot logo.png` is copied into `Jot/Assets.xcassets/AppIcon.appiconset/AppIcon.png` and used as the app icon. For best results, provide a 1024×1024 PNG; Xcode will scale it for other sizes.
- **Xcode project** – `Jot.xcodeproj` is set up with:
  - macOS App target “Jot”
  - All Swift sources under `Sources/Jot`
  - `Info.plist` and `Jot.entitlements` at repo root
  - Asset catalog with AppIcon
  - Sandbox and entitlements wired

## What you must do yourself

### 1. Code signing (required to run and distribute)

1. Open **Jot.xcodeproj** in Xcode.
2. Select the **Jot** project in the navigator → select the **Jot** target.
3. Open **Signing & Capabilities**.
4. Check **“Automatically manage signing”**.
5. Choose your **Team** (your Apple ID or your team).  
   - If you see “Add an account…”, add your Apple ID in Xcode → Settings → Accounts.
   - For App Store distribution you need an Apple Developer Program membership and a team.

Without this, the app may not run on your Mac or submit to the App Store.

### 2. Bundle identifier (optional)

- Current: **com.chencai.Jot** (in `Info.plist` and in the target’s Build Settings).
- To change it: update **Product Bundle Identifier** in the Jot target’s Build Settings (and keep `Info.plist` in sync if you use it for `CFBundleIdentifier`).

### 3. Pricing: $0.99 USD (paid app)

Pricing is set **only in App Store Connect**, not in Xcode or in code.

1. You need a **paid Apple Developer Program** membership ($99/year) to distribute paid apps.
2. In [App Store Connect](https://appstoreconnect.apple.com), open your app (or create it with bundle ID `com.chencai.Jot`).
3. Go to **App Store** (left sidebar) → **Pricing and Availability**.
4. Under **Price**, choose **Add Pricing** (or edit existing).
5. Select **$0.99 USD** (or the equivalent tier; Apple gives you a price tier list; Tier 1 is typically $0.99 in the US).
6. Set **Availability** (e.g. “Make this app available in all territories” or select countries).
7. Save. The price applies when you submit the version for review and release.

No code or project changes are needed for a paid app; in-app purchase or StoreKit is only for selling extra content inside the app, not for the initial purchase.

### 4. App Store Connect (for App Store release)

- Create an app in [App Store Connect](https://appstoreconnect.apple.com) with the same bundle ID.
- In Xcode: **Product → Archive**, then **Distribute App → App Store Connect**.
- Upload the archive; finish metadata, screenshots, and (as above) pricing in App Store Connect.

### 5. Icon sizes (optional but recommended)

- The project uses one icon image for all sizes.
- For best quality on all devices, add separate assets in **Assets.xcassets → AppIcon** for 16, 32, 64, 128, 256, 512, and 1024 pt (or let Xcode generate them from the 1024×1024 image).

---

**Quick run:** Open `Jot.xcodeproj`, set your Team under Signing & Capabilities, then **⌘R** to build and run.
