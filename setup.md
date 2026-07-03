# SETUP.md — From a bare Mac to "app running on my iPhone"
 
Do this **before** CLAUDE.md Milestone 0. It gets your MacBook Air M5 + iPhone 12 to the point where you can build and run a SwiftUI app on the phone. After that, Claude Code takes over the actual build.
 
---
 
## Division of labor (read this first)
 
| Step | Who | Why |
|---|---|---|
| Install Xcode, Command Line Tools | **You** (GUI/terminal) | Comes from the Mac App Store; CC can't click through it. |
| Add Apple ID, configure signing | **You** (Xcode GUI) | Signing UI is manual; one-time. |
| Enable Developer Mode + trust cert on iPhone | **You** (iPhone GUI) | On-device toggles; CC has no access to your phone. |
| Create the first Xcode project | **You** (Xcode GUI) | Xcode owns the `.xcodeproj`. |
| Install Homebrew, Node, wrangler; scaffold `/worker` `/gateway` `/batch`; write all Swift/TS/Python code | **Claude Code** | This is the part CC is great at. |
| Build + run on device (day to day) | **You press ⌘R in Xcode**; CC can also automate via `xcodebuild`/`devicectl` later | Keep the first runs in Xcode — most reliable. |
 
The pattern: **Xcode owns the iOS project + signing + device. CC writes the code and owns the backend.** They share the same folder on disk.
 
---
 
## Part A — Mac bootstrap
 
**A1. Confirm the basics**
-  → About This Mac → confirm macOS is **Tahoe 26.x** (it will be on an M5). Storage: you have ~400 GB free — plenty (Xcode + a simulator ≈ 30–40 GB).
**A2. Install Xcode**
- Open **App Store** → search **Xcode** → Get/Install. It's large (~15 GB download, more after components) — let it finish, ideally on a good connection.
- Install the **stable** version, not any "Xcode 27 beta."
**A3. First launch + components**
- Open Xcode once. Accept the license. Let it "Install additional required components."
- In Terminal, finalize the toolchain:
  ```bash
  xcode-select --install            # if it says already installed, fine
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
  xcodebuild -version               # should print Xcode 26.x
  swift --version
  ```
 
**A4. General dev tools (CC needs these for the backend)**
```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# follow the post-install line it prints to add brew to your PATH, then:
brew install git node
node -v && npm -v
python3 --version                   # confirm what you already have
```
> You'll write Swift in Xcode/VS Code, but the `/worker` (Cloudflare/Hono) needs Node, and `/gateway` + `/batch` need Python. This installs both.
 
---
 
## Part B — Apple ID + first project + signing (Xcode GUI)
 
**B1. Add your Apple ID**
- Xcode → **Settings** (⌘,) → **Accounts** → **＋** → **Apple ID** → sign in.
- This creates a free **Personal Team** — that's what enables free 7-day provisioning.
**B2. Create the project**
- **File → New → Project → iOS → App → Next.**
- Product Name: `Fluent` (or your real name).
- Team: your **Personal Team**.
- Organization Identifier: reverse-DNS you control, e.g. `com.dion`. → Bundle ID becomes `com.dion.Fluent`.
- Interface: **SwiftUI**. Language: **Swift**. Storage: **None**. → Save it somewhere like `~/dev/fluent/app`.
**B3. Turn on filesystem-synchronized groups (so CC-created files auto-appear)**
- In the Project navigator, keep your source in a **synchronized folder group** (Xcode 16+ default for added folders). This matters: when **CC creates new `.swift` files** in that folder, they get added to the build target automatically — no manual "Add Files" clicking.
- If you add a new top-level code folder later, right-click the project → **Add Files / Add Folder** and pick the **folder** (synced), not individual files.
**B4. Signing**
- Select the project (top of navigator) → your target → **Signing & Capabilities**.
- Check **Automatically manage signing**. Team = your Personal Team. Confirm the Bundle Identifier is unique.
---
 
## Part C — iPhone 12: first run on device (the milestone)
 
**C1. Connect & pair**
- Plug the iPhone 12 into the Mac (**Lightning-to-USB-C cable**). On the phone, tap **Trust This Computer** and enter your passcode.
**C2. Enable Developer Mode (iOS 16+)**
- In Xcode, select your iPhone as the run destination (top toolbar device dropdown).
- On the iPhone: **Settings → Privacy & Security → Developer Mode → On → Restart.** (This item appears once the device has been connected to Xcode.)
**C3. Build & run**
- In Xcode press **⌘R** (Run). First time, it builds and tries to install.
- If it says the developer cert is untrusted: on the iPhone go **Settings → General → VPN & Device Management → [your Apple ID under Developer App] → Trust.** Press ⌘R again.
- The default SwiftUI "Hello, world!" launches on your phone. ✅ **Setup is done.**
**C4. (Optional) Wireless debugging**
- After the first wired run: Xcode → **Window → Devices and Simulators** → select the iPhone → check **Connect via network.** Now you can run untethered on the same Wi-Fi.
---
 
## Part D — Wire the repo for Claude Code
 
Lay out the monorepo from CLAUDE.md so the Xcode project sits inside it:
```
~/dev/fluent/
├── CLAUDE.md          ← the build spec (auto-loaded by CC)
├── SETUP.md           ← this file
├── app/               ← the Xcode project you just made
├── worker/            ← CC scaffolds (Hono/TS, wrangler)
├── gateway/           ← CC scaffolds (FastAPI)
├── batch/             ← CC scaffolds (Python)
├── shared/            ← contracts/schemas
├── infra/             └─ wrangler.toml, cloudflared, D1 migrations
└── docs/
```
- Open `~/dev/fluent/` as the folder in **VS Code**. Claude Code now sees `CLAUDE.md`, `SETUP.md`, and the `app/` project.
- Install Wrangler when CC asks (it'll handle this in Milestone 0): `npm install -g wrangler` (or it uses `npx wrangler`).
---
 
## Part D½ — Install Claude Code in VS Code

```bash
npm install -g @anthropic-ai/claude-code
```
- Open `~/dev/fluent/` in VS Code → install the **Claude Code** extension (or run `claude` in the integrated terminal) → sign in.
- First session: run `/init` is NOT needed — CLAUDE.md already exists and is auto-loaded.
- Put `DESIGN.md` at `docs/DESIGN.md` (CLAUDE.md references it there).

## Part E — Hand off to Claude Code
 
Once Hello-World runs on your phone, paste this as your **first CC message**:
 
```
Read CLAUDE.md and SETUP.md. My environment is ready: Xcode 26.x installed,
Hello-World SwiftUI app already runs on my iPhone 12 via free provisioning,
Node and Python installed, repo at ~/dev/fluent with the Xcode project in app/.
 
Do CLAUDE.md Milestone 0 only:
- scaffold worker/, gateway/, batch/, shared/, infra/, docs/
- define the /shared JSON contracts and types
- set up the Hono Worker skeleton + wrangler.toml + D1 migrations from the schema
- give me the exact terminal commands to run, and tell me precisely which steps
  I must do by hand in Xcode or the Cloudflare dashboard (you can't click those).
 
Set the app's minimum deployment target to iOS 18. Do NOT start Milestone 1
until I confirm the scaffold builds.
```
 
CC will write code and hand you back the few clicks it can't do itself (creating the Cloudflare D1/KV/R2 resources in the dashboard, pasting secrets, pressing ⌘R in Xcode).
 
---
 
## Free-provisioning gotchas (live with these until the $99 plan in v2)
 
- **7-day expiry:** apps signed with a free Personal Team stop launching after 7 days. Fix = re-run from Xcode (⌘R) to re-sign. Keep doing this through v1.
- **Limits:** max **3** sideloaded apps per device and **10** App IDs per 7 days on a free account. Don't churn bundle IDs.
- **Re-trust** may be needed after a re-sign: same VPN & Device Management → Trust step.
- When you move to TestFlight / App Store in v2, the **$99/yr Apple Developer Program** removes the 7-day limit and unlocks push, etc. Nothing in the code needs to change — it's an account upgrade.
---
 
## If something stalls
 
- Device not showing in Xcode → unplug/replug, re-tap Trust, confirm Developer Mode is On.
- "Untrusted Developer" → the C3 Trust step.
- Build fails on signing → Signing & Capabilities → confirm Personal Team selected + unique Bundle ID.
- Xcode won't install from App Store (macOS too old) → update macOS in System Settings → General → Software Update, then retry.