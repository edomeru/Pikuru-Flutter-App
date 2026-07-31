# TestFlight Guide — Flutter iOS (Pikuru)

A step-by-step reference for building a Flutter app and distributing it to testers via TestFlight, from IPA build to adding testers. Based on the Pikuru setup.

---

## 0. One-time prerequisites

Do these once per app / account.

- **Apple Developer Program membership** (paid, active).
- **App record in App Store Connect** with a bundle ID matching your Xcode project.
  - App Store Connect → **Apps** → blue **"+"** → **New App**.
  - Platform: iOS · Name (unique across the App Store) · Primary Language · Bundle ID (e.g. `com.pikurupickleball.pikuru`) · SKU (any unique code, e.g. `pikuru-001`) · Full Access.
- **Xcode signing set up**: open `ios/Runner.xcworkspace` → Runner target → **Signing & Capabilities** → select your **Team** → enable **Automatically manage signing**.
- Confirm the bundle ID App ID is registered at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers (automatic signing usually registers it for you).

---

## 1. Prepare the build

1. **Bump the version/build number** in `pubspec.yaml` if needed:
   ```yaml
   version: 1.0.0+7   # format is <version>+<build>; build number must be unique per upload
   ```
   - Version (`1.0.0`) = the marketing version shown to users.
   - Build (`+7`) = internal build number. **Every upload needs a unique build number.** Bump it (e.g. `+8`) for each new upload of the same version.

2. **Check the app icon has no transparency (alpha channel).** The 1024×1024 App Store icon must be opaque, or upload fails with "Invalid large app icon."
   - In `pubspec.yaml` under `flutter_launcher_icons`, set:
     ```yaml
     remove_alpha_ios: true
     background_color_ios: "#FFFFFF"
     ```
   - Regenerate icons: `dart run flutter_launcher_icons` (or `flutter pub run flutter_launcher_icons`).

3. **Clean (optional but avoids stale builds):**
   ```bash
   flutter clean && flutter pub get
   ```

---

## 2. Build the IPA

```bash
flutter build ipa --release
```

- Use **two hyphens** `--release` (not an em-dash `—release`, which some editors auto-insert and causes "Target file not found").
- Output: `build/ios/ipa/*.ipa`.

---

## 3. Upload the build to App Store Connect

Pick one method:

**A. Transporter app (easiest)**
1. Install **Transporter** from the Mac App Store; sign in with your Apple ID.
2. Drag `build/ios/ipa/*.ipa` into Transporter → **Deliver**.
3. Watch for **Delivered** (green check). If it shows an issue (e.g. the icon alpha error), fix and re-upload.

**B. Xcode**
- Product → Archive → Distribute App → App Store Connect → Upload.

**C. Command line**
```bash
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```
(Requires an App Store Connect API key from Users and Access → Integrations.)

---

## 4. Wait for processing

- After a successful upload, App Store Connect → your app → **TestFlight** tab shows the build as **Processing** (usually 5–30 min).
- When done, status becomes **Ready to Submit** (or "Missing Compliance" — see next step).

---

## 5. Clear export compliance (encryption)

If the build shows **Missing Compliance**:
1. Click **Manage** on the build.
2. "What type of encryption algorithms does your app implement?"
3. For a typical app using only standard HTTPS/TLS (Firebase, sign-in, normal networking) and no custom/proprietary encryption → select **"None of the algorithms mentioned above."**
4. Confirm. Status changes to **Ready to Submit**.

**To stop the prompt on every future build**, add to `ios/Runner/Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
(Only if your app truly uses no non-exempt encryption.)

---

## 6. Add testers

Two options — pick based on who the testers are.

### Internal testing (your own team, instant, no review)
- Testers **must be App Store Connect users** on your team (max 100).
- To add someone new:
  1. Top nav → **Users and Access** → **People** → blue **"+"**.
  2. Enter First/Last name (labels only — placeholders like "Pikuru / Tester1" are fine) + email + role (**Developer** is the minimal role that includes TestFlight).
  3. Send invite. **The person must accept the email invitation** before they appear as an available tester (pending invites show "Resend Invitation" and won't show up in the picker).
  4. TestFlight → **INTERNAL TESTING → "+"** → create group → **Add Testers** → select accepted users → **Add**.
  5. Attach the build (Builds tab of the group) if not auto-attached.
- Testers get a TestFlight invite → install the **TestFlight** app on iPhone → redeem → install Pikuru.

### External testing (outside testers, by email — recommended for non-team people)
- Add **any email address** (no ASC account, no names, up to 10,000).
  1. TestFlight → **EXTERNAL TESTING → "+"** → name the group.
  2. Add testers by email (or import a list).
  3. Add the build to the group.
  4. **First external build triggers a one-time Beta App Review** by Apple (a few hours to ~1 day). After approval, testers get invites; future builds don't need review again.
- Fill in **Test Information** (feedback email, what to test) — required for external testing.

**Rule of thumb:** internal for you/your team; external for everyone else (much less friction).

---

## 7. Tester install flow (what testers do)

1. Receive TestFlight invite email (or a public link, for external).
2. Install the **TestFlight** app from the App Store.
3. Open the invite / redeem the code → install the app → send feedback via TestFlight.

---

## 8. Pushing updates to testers

1. Bump the build number in `pubspec.yaml` (e.g. `1.0.0+8`).
2. `flutter build ipa --release` → upload via Transporter.
3. Wait for processing → clear compliance if asked.
4. TestFlight auto-notifies existing testers of the new build (internal: immediate; external: no re-review needed unless it's a new app version with major changes).

---

## Common gotchas (that we hit)

| Problem | Fix |
|---|---|
| `Target file "—release" not found` | Use `--release` with two real hyphens, not an em-dash. |
| `Invalid large app icon ... alpha channel` | Remove transparency from the 1024 icon; set `remove_alpha_ios: true`. |
| Build stuck / not appearing in version's Build section | Wait for **Processing** to finish, then refresh. |
| "Missing Compliance" | Answer the encryption question ("None…") or set `ITSAppUsesNonExemptEncryption`. |
| Invited testers don't show in the Add Testers list | They must **accept the ASC invite email** first (internal testing). |
| Duplicate build number error | Bump `+N` in `pubspec.yaml` and rebuild. |

---

## For the public App Store release (separate from TestFlight)

1. **Distribution** tab → version 1.0 → **Build** section → select your processed build.
2. Fill required metadata: description, keywords, promotional text, screenshots (e.g. iPhone 6.5" = **1242 × 2688 px**), support URL, privacy details, age rating, pricing.
3. Click **Add for Review** → submit. App Review typically takes ~1–3 days.
