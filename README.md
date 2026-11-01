# Lightroom Classic HDR Tools

[简体中文](README_ZH.md)

- [1. Introduction](#1-introduction)
- [2. Quick Start](#2-quick-start)
- [3. Configuration](#3-configuration)
- [4. Optional Features](#4-optional-features)
- [5. Development](#5-development)
- [6. License](#6-license)

## 1. Introduction

A bracketed photo shoot can leave you with dozens of nearly identical RAW files: several exposures of each scene that need to be merged, followed by the source frames that still need reviewing. Merging every set manually is repetitive, but deleting the originals without checking which HDR they belong to is risky.

Lightroom Classic HDR Tools contains **two complementary plug-ins** for that workflow. **Automatic Bracketed HDR** finds exposure-bracket groups in your current selection and asks Lightroom Classic to merge them one at a time. **Merged Source Cleanup** identifies source photos associated with completed HDR or panorama results and places eligible originals into a collection for **your review**. Neither plug-in automatically deletes source photos.

The plug-ins run locally on **Windows with Adobe Lightroom Classic** (not cloud-based Lightroom). They do not require an account, API key or external image service, and do not upload photos. The HDR helper uses a Windows keyboard shortcut because Lightroom's plug-in SDK does not expose a direct HDR-merge API. You must keep Lightroom in the foreground during a batch run.

## 2. Quick Start

Follow one complete workflow: install both plug-ins, merge a test exposure bracket, then create a review collection **without deleting any photos**.

### 2.1. Requirements

You need Windows, an installed **Adobe Lightroom Classic** version supporting the Lightroom SDK minimum declared by the plug-ins (`LrSdkMinimumVersion = 6.0`), and permission to install plug-ins. This project does **not** run in the cloud Lightroom app or on macOS/Linux.

Before starting, back up your Lightroom **catalog and original photos**. Prepare **two different exposure-bracket groups**, each containing **2–9 RAW/DNG originals**: use **Group A** to set Lightroom's manual HDR options and **Group B** for the automatic merge. Keeping the groups separate avoids accidentally merging the same files twice.

For Group B, the photos must be in one folder, from the same camera at the same focal length and image dimensions, with no more than **2 seconds between adjacent shots** and at least **1 EV** across the bracket. Exposure/time metadata must be present. Videos, virtual copies, other formats, and files named as existing HDR/Pano outputs are excluded.

### 2.2. Download and install

1. Open the [latest Release](https://github.com/ThinkerQAQ/lightroom-plugin/releases/latest) and download the **published ZIP asset** and `SHA256SUMS.txt`. Do **not** use GitHub's automatically generated Source code archive, which is not the packaged Windows plug-in.
2. Open PowerShell in the download folder and calculate the checksum, replacing the placeholder with the **actual downloaded ZIP filename**:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\lightroom-plugin-YOUR-RELEASE.zip'
```

Compare the displayed hash to the **same filename** in `SHA256SUMS.txt`. Stop if they differ.

3. Extract the entire ZIP into a **writable, permanent path without spaces**, such as `C:\LightroomPlugins`. Confirm it contains both `LightroomAutoHDRv2.lrplugin\Info.lua` and `LightroomMergeCleanup.lrplugin\Info.lua`, and that `LightroomAutoHDRv2.lrplugin\AutoHDRInput.exe` exists. Keep the two plug-in folders **side by side** so Cleanup can read the HDR source mapping.
4. In Lightroom Classic, open **File → Plug-in Manager → Add**. Select the `LightroomAutoHDRv2.lrplugin` **folder** and add it; repeat for `LightroomMergeCleanup.lrplugin`. Confirm **both** show as enabled, then close the manager. Do not add the ZIP or the parent `C:\LightroomPlugins` folder. See [Adobe's Plug-in Manager instructions](https://helpx.adobe.com/in/lightroom-classic/desktop/export-photos/export-presets-settings-plug-ins.html).

Installation is complete when both plug-ins are enabled and their commands appear under **Library → Plug-in Extras**.

### 2.3. Prepare Lightroom's HDR settings

1. In the **Library** module, select **Group A** (one ordinary bracket set you can safely merge).
2. Choose **Photo → Photo Merge → HDR**. In Lightroom's preview, choose your preferred **Auto Align**, **Auto Tone**, **Deghost Amount** and **Create Stack** settings, then click **Merge**. This is Lightroom's normal manual workflow; see [Adobe's HDR merge guide](https://helpx.adobe.com/lightroom-classic/desktop/process-and-develop-photos/hdr-photo-merge.html).
3. Confirm that Lightroom produced the expected HDR DNG for Group A. Wait for that operation and all other import/export/HDR tasks to finish before running the plug-in.

The automatic command uses Lightroom's **headless HDR merge**, which reuses the most recent manual options. Group A is for setup; **do not reuse it as Group B**.

### 2.4. Merge Group B automatically

1. In **Library Grid**, select only the **unmerged Group B** RAW/DNG originals (not the DNG from Group A).
2. Choose **Library → Plug-in Extras → [v2] Detect and merge bracketed HDR DNGs...**.
3. Read the confirmation dialog: it should report **one detected group** containing the number of photos you selected. If it reports zero or an unexpected count, **cancel** and check [2.1](#21-requirements).
4. Click **Start merge**. Keep Lightroom **in front** and avoid using the mouse/keyboard until the operation finishes. The plug-in selects the group, invokes Lightroom's `Ctrl+Shift+H` headless HDR shortcut, and waits for a **new DNG on disk** before proceeding.
5. Check the completion message. The wait limit is **180 seconds per group**; failures stop later submissions rather than silently moving to the next group.

The shortcut helper is Windows-only. This is not an export or online HDR processor: Lightroom performs the merge using its own engine.

### 2.5. Verify and review the source photos

1. Confirm that **Group B's new HDR DNG** exists both in its folder and in the Lightroom catalog. The original Group B RAW/DNG files must still exist.
2. In the installed `LightroomAutoHDRv2.lrplugin` folder, inspect `AutoHDR-v2.log` and `AutoHDR-v2-last-run.tsv`. A successful, writable mapping records the merged DNG and its individual source paths. If the DNG exists but the mapping is missing, **do not assume the cleanup mapping was recorded**; inspect the log first.
3. In Library Grid, select **Group B's merged DNG and all its source originals together**. Expand any collapsed stack first so the required photos can be selected.
4. Choose **Library → Plug-in Extras → Scan merges and source photos (stacks/AutoHDR)...**. Review the reported groups, evidence and protected merged filenames. Choose **Create review collection** only when the candidates are correct.
5. Open the new **source-photo review collection** and inspect every selected thumbnail. **Stop here for the first-run test.** The scanner creates a collection and may select candidate originals, but **does not delete files or change original image data**.

A complete first run produces a new HDR DNG, preserves its sources, and lets you inspect the matched originals in a review collection. Deletion is a separate, optional action in [Case 2](#42-case-2-review-and-delete-sources).

### 2.6. Troubleshooting

- **Plug-in commands are missing:** check that both actual `.lrplugin` directories were added and enabled. The `Info.lua` files must be inside the selected folders. Restart Lightroom if you changed its UI language.
- **The automatic merge reports no groups:** check the **2–9 RAW/DNG**, same-folder/camera/focal-length/dimension rules, metadata, 2-second timing and 1 EV span. Don't select merged results or virtual copies.
- **The shortcut/helper fails:** Lightroom must be the **foreground** application; keep the installation path writable and **without spaces**, and confirm `AutoHDRInput.exe` exists. Inspect `AutoHDRInput.log` and `AutoHDR-v2.log`. Exit codes **20** (Lightroom not found), **22** (not foreground) and **23** (SendInput failed) help identify the cause.
- **The DNG times out:** wait for other Lightroom jobs to finish. A new DNG in the expected folder is the completion signal; inspect the HDR log before attempting another run.
- **Cleanup finds no safe matches:** select the merged DNG **and all originals**, or inspect their actual folder stack. Missing/ambiguous evidence is intentionally rejected. Check `MergeCleanup.log`.
- **Windows warns about an unsigned executable:** the packaged helper is unsigned. Inspect `AutoHDRInput.cs` and [build it yourself](#5-development) if desired; never disable security protections just to continue.

For other problems, [open an Issue](https://github.com/ThinkerQAQ/lightroom-plugin/issues) with a reproducible description and **redacted** logs; local file paths and photo names can be sensitive.

## 3. Configuration

There is **no separate config file, API key or login**. Automatic HDR uses Lightroom's **most recently selected manual HDR merge settings**. English and Simplified Chinese menu text is bundled with the plug-ins.

Keep both `.lrplugin` directories together in a **writable path with no spaces**. HDR records `AutoHDR-v2.log`, `AutoHDRInput.log` and the latest exact `AutoHDR-v2-last-run.tsv` mapping inside its folder. Cleanup writes `MergeCleanup.log` in its own folder and reads the adjacent HDR mapping when available. A fresh HDR batch **resets the last-run TSV**, so preserve an earlier mapping if you need it for later review.

Cleanup uses **real Lightroom folder stacks**, then exact AutoHDR paths/logs, then conservative filename/metadata checks; an incomplete match is skipped. It does **not** assume every image near a merged DNG can safely be deleted.

## 4. Optional Features

### 4.1. Case 1: Test the HDR shortcut

If automatic merging stops at the helper stage, select an **additional unused bracket group** and first check that **Ctrl+Shift+H** works manually in Lightroom. You can then choose **Library → Plug-in Extras → [v2] Test HDR shortcut on current selection...** and confirm **Send once**.

**This is not a dry run:** the test actually sends Lightroom's HDR shortcut and **may create another DNG**. It does not detect groups, change the selection or build source mappings. Do not test on photos you intend to merge again in the automatic workflow.

### 4.2. Case 2: Review and delete sources

The Cleanup plug-in only **prepares a review collection**. After verifying that every candidate is a source frame, the correct merged image is safely retained, and you have a backup, you may use Lightroom's own **Ctrl+Alt+Shift+Backspace** shortcut and choose **Delete from Disk** in Lightroom's confirmation.

This is a **user-initiated destructive operation**; never run it simply to finish setup. On Windows, Lightroom normally sends deleted local files to the Recycle Bin, but do not rely on recovery as a substitute for backup. See [Adobe's Lightroom Classic keyboard shortcuts](https://helpx.adobe.com/in/lightroom-classic/desktop/introduction-to-lightroom-classic/keyboard-shortcuts.html). If the plug-in could not select every candidate, **review/select manually first** rather than invoking the shortcut on an uncertain selection.

### 4.3. Case 3: Upgrade or use Cleanup alone

Close Lightroom before replacing plug-in files. Keep the installation path stable, and **back up `AutoHDR-v2-last-run.tsv` and logs** first if you need to retain earlier exact source mappings. Extract the new Release and replace both plug-in directories together, then confirm both remain enabled in **File → Plug-in Manager**. Keep your Lightroom catalog and original photographs separate from plug-in upgrades.

Cleanup can also be installed independently: it can inspect real folder stacks and conservative metadata matches, but it will not have the adjacent AutoHDR exact mapping.

## 5. Development

The project contains Lightroom SDK **Lua** plug-ins plus a small Windows **C#** executable that sends `Ctrl+Shift+H` to a foreground Lightroom window.

From a source checkout on Linux/macOS with Lua 5.4 tools installed, check all Lua files:

```bash
git clone https://github.com/ThinkerQAQ/lightroom-plugin.git
cd lightroom-plugin
find . -name '*.lua' -print0 | xargs -0 -n 1 luac -p
git diff --check
```

Compile the helper from the repository root in **Windows PowerShell** using the .NET Framework C# compiler:

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:LightroomAutoHDRv2.lrplugin/AutoHDRInput.exe LightroomAutoHDRv2.lrplugin/AutoHDRInput.cs
if ($LASTEXITCODE -ne 0) { throw 'Helper compilation failed' }
```

CI checks Lua syntax and distribution inputs on Linux and compiles the helper on Windows. Release packaging builds the helper from source and produces a ZIP plus SHA-256 manifest. **There is no automated test inside a running Lightroom Classic host**: a real HDR merge and source review require Windows Lightroom, test RAW/DNGs and a backed-up catalog. Use feature branches, review PRs and Squash Merge.

## 6. License

The project source is distributed under the [MIT License](LICENSE). Lightroom Classic is separate Adobe software; this independent community project is **not affiliated with Adobe**, and it does not license Adobe products or user photographs.

**Security and privacy:** the helper is an **unsigned local Windows executable** that sends an HDR shortcut to the foreground Lightroom process. Plug-in logs and `AutoHDR-v2-last-run.tsv` can contain **local paths, photo names and Windows user information**. Keep them out of public commits and redact them before sharing. The plug-ins do not upload photos or credentials. Report security issues through [GitHub's private security advisories](https://github.com/ThinkerQAQ/lightroom-plugin/security/advisories) where available; do not disclose sensitive logs in public Issues.
