# Lightroom Classic HDR Tools

[简体中文](README_ZH.md)

## Introduction

Two local Windows plug-ins for Adobe Lightroom Classic: **Automatic Bracketed HDR** detects exposure-bracket groups and submits HDR merges; **Merged Source Cleanup** gathers source-photo candidates into a review collection. For photographers processing bracketed RAW/DNG sets. This is independent community software for Classic, not cloud Lightroom; photos are not uploaded.

## Quick Start

### 1. Prerequisites

Windows, Adobe Lightroom Classic with SDK **6.0+**, a writable installation path **without spaces**, and 2–9 bracketed RAW/DNG photos for a small test. macOS/Linux are not supported. Back up the catalog and source photos first. Lightroom must stay in the foreground during automatic merging.

### 2. Download and install

1. Download the asset ZIP and `SHA256SUMS.txt` from [Releases](https://github.com/ThinkerQAQ/lightroom-plugin/releases/latest). Use the installable asset, not GitHub's generated source archive.
2. Compare the ZIP's SHA-256 with the manifest, for example in PowerShell: `Get-FileHash .\lightroom-plugin-vVERSION.zip -Algorithm SHA256` (replace the filename).
3. Extract `LightroomAutoHDRv2.lrplugin` and `LightroomMergeCleanup.lrplugin` next to each other in a writable, space-free directory such as `C:\LightroomPlugins`. Keep both folders together so cleanup can find the HDR mapping.
4. In Lightroom choose **File → Plug-in Manager → Add** and add each `.lrplugin` folder separately. Confirm both are enabled. The packaged HDR folder must contain `AutoHDRInput.exe`.

### 3. Configure and merge one group

1. Manually merge one bracketed group once. Choose the desired auto-align, auto-tone, deghosting and stacking options; the automated no-preview merge reuses Lightroom's last settings.
2. In Library Grid select one test group of RAW/DNG files from the same folder. Photos must share camera, focal length and dimensions, have at most 2 seconds between adjacent shots, and span at least 1 EV.
3. Choose **Library → Plug-in Extras → [v2] Detect and merge bracketed HDR DNGs…**. Review the detected group count, then start. Stop other import/export/HDR jobs first. Keep Lightroom in front and do not use the mouse or keyboard while the run is active.
4. Wait for the result. Each group has a 180-second DNG timeout; failure stops later submissions. Videos, virtual copies, other formats and filenames already marked HDR/Pano are excluded.

### 4. Verify and review sources

Success means a new merged DNG appears in the catalog **and** the successful DNG-to-source relation is recorded in `AutoHDR-v2-last-run.tsv` beside the HDR plug-in. Original source photos must still exist; automatic HDR does not delete them.

To verify cleanup without deleting anything:

1. Select that merged result and **all** its RAW source photos together in Library Grid.
2. Choose **Library → Plug-in Extras → Scan merges and source photos (stacks/AutoHDR)…**.
3. Review the counts, evidence and retained merged files. Open the generated review collection and check every thumbnail/selection. The scan must leave files unchanged.

Only after reviewing the selection yourself, you may choose Lightroom's **Ctrl+Alt+Shift+Backspace** (Backspace, not Delete), then **Delete from Disk**. This user action moves selected files to the Windows Recycle Bin; it is not part of the scan or required Quick Start acceptance.

### 5. Troubleshooting

- **No menu:** verify each `.lrplugin` folder was added, not its parent ZIP/directory. Restart Lightroom after language changes.
- **Merge does not start:** confirm foreground Lightroom, a space-free path and `AutoHDRInput.exe`. Check `AutoHDR-v2.log` and `AutoHDRInput.log`.
- **No groups:** use eligible RAW/DNG originals with the grouping criteria above; do not include only virtual copies or prior HDR/Pano results.
- **No safe cleanup candidates:** select result and every source; inspect `MergeCleanup.log`. Incomplete/ambiguous matches are skipped.
- **Windows unsigned-program warning:** inspect `AutoHDRInput.cs` and compile it yourself if needed; the helper only sends the HDR shortcut to foreground Lightroom.

## Configuration

No separate TOML, account or API key is required. Merge options come from Lightroom's most recent manual HDR merge. English and Simplified Chinese UI are included; other Lightroom languages fall back to English.

Logs and the latest successful source mapping live inside the plug-in directories, so the directory must be writable. Cleanup checks actual folder stacks, the exact Auto HDR mapping, then constrained filename/metadata matches. The existing collection-set name is retained across upgrades.

## Optional Features

Close Lightroom and replace both plug-in folders together when upgrading. Preserve logs and `AutoHDR-v2-last-run.tsv` before replacement if you need earlier exact mappings; otherwise cleanup can only use its remaining evidence. Keep catalog/photos separate from plug-in upgrades. The source-cleanup plug-in can be used independently, but without an Auto HDR mapping it relies on the other supported evidence.

## Development

Source consists of Lightroom Lua plug-ins and the Windows C# input helper. On Linux/macOS with Lua 5.4 installed, syntax-check each Lua file:

```sh
find . -name '*.lua' -print0 | xargs -0 -n 1 luac -p
```

Compile the helper from the repository root in Windows PowerShell:

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:LightroomAutoHDRv2.lrplugin/AutoHDRInput.exe LightroomAutoHDRv2.lrplugin/AutoHDRInput.cs
if ($LASTEXITCODE -ne 0) { throw 'Helper compilation failed' }
```

CI validates Lua syntax and distribution inputs on Linux, and compiles the helper on Windows. Tag-triggered packaging builds the helper from source and publishes a ZIP/checksum. No automated Lightroom host/integration test is supplied; actual merge and review-collection acceptance needs Windows Lightroom and a backed-up test catalog. Use feature branches, PRs and Squash Merge.

## License

[MIT](LICENSE) covers project source, not Adobe software, user catalogs or photographs. This independent project is not affiliated with Adobe; Adobe/Lightroom trademarks belong to Adobe. You need your own licensed Classic installation and rights to your media. The bundled helper is unsigned. See [security policy](SECURITY.md).
