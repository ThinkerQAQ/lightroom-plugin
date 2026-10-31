# Lightroom Classic HDR Tools

[简体中文](README.zh-CN.md)

Two Windows plug-ins for Adobe Lightroom Classic: one merges bracketed RAW/DNG photos into HDR DNGs, and the other prepares source photos for manual review after a merge. The plug-ins work locally and do not upload photos.

| Plug-in | Version | What it does |
| --- | --- | --- |
| Automatic Bracketed HDR | 2.1.2 | Detects bracketed groups in the selection and invokes Lightroom's HDR merge, one group at a time. |
| Merged Source Cleanup | 1.1.1 | Finds source photos associated with merged results and puts candidates in a review collection. |

**Scope:** Windows and Lightroom Classic with SDK 6.0 or later. This is not a plug-in for cloud-based Lightroom. The HDR helper uses a Windows executable and requires Lightroom to remain in the foreground. The full plug-in path must contain no spaces. English and Simplified Chinese UI are included; other Lightroom languages fall back to English.

## Download and install

1. Download the ZIP from the [latest Release](https://github.com/ThinkerQAQ/lightroom-plugin/releases/latest). Download the asset ZIP, not GitHub's automatically generated source archive: the latter might not be the intended installation package.
2. Extract both `.lrplugin` folders to a path without spaces, such as `%APPDATA%\Adobe\Lightroom\Modules\`. Keep the folders next to each other so cleanup can read Auto HDR's exact mapping file.
3. In Lightroom Classic, open **File > Plug-in Manager > Add** and add each `.lrplugin` folder separately. Restart Lightroom if the menu language does not update after upgrading.
4. Back up your catalog and source photos, then try a small bracketed set first.

The downloaded bundle includes `AutoHDRInput.exe`. Windows may warn about an unsigned executable; inspect the source `AutoHDRInput.cs` and compile it yourself if you prefer. The executable only sends Lightroom's HDR shortcut to the foreground Lightroom process. It is required for automatic merging.

## Merge bracketed HDR photos

1. Manually merge one set in Lightroom and choose your desired auto-align, auto-tone, deghosting, and stacking options. The no-preview merge uses those settings.
2. In Library Grid, select RAW/DNG photos from the same folder. Choose **Library > Plug-in Extras > [v2] Detect and merge bracketed HDR DNGs…** (the menu appears in Chinese when Lightroom's language is Simplified Chinese).
3. Review the detected groups and start. Keep Lightroom in the foreground; do not use the keyboard or mouse until the run ends. Stop any other import, export, or HDR work first.

A group contains 2–9 photos with matching folder, camera, focal length, and dimensions, no more than 2 seconds between adjacent shots, and at least 1 EV exposure span. Videos, virtual copies, other formats, and files already named as HDR/Pano are excluded. Each group has a 180-second DNG wait; failure stops subsequent submissions. Source photos are never deleted by this plug-in. The most recent successful DNG-to-source mapping is stored in `AutoHDR-v2-last-run.tsv` beside the plug-in; logs are `AutoHDR-v2.log` and `AutoHDRInput.log`.

## Review merged source photos

1. Select a merged HDR/Pano result and **all** its RAW source photos together in Library Grid. For a batch, select all photos in the current source when appropriate.
2. Choose **Library > Plug-in Extras > Scan merges and source photos (stacks/AutoHDR)…**. Review the counts, evidence, and list of merged files that will be kept.
3. The plug-in creates a review collection under the existing collection set and attempts to select its candidate source photos. **Check every thumbnail and selection yourself.** The scan does not delete files.
4. Only if the selection is correct, press **Ctrl+Alt+Shift+Backspace** (Backspace, not Delete) and confirm **Delete from Disk** in Lightroom. This final action is yours and moves files to the Windows Recycle Bin.

The scan checks real folder stacks, Auto HDR's exact mapping, then constrained filename and metadata matches. Incomplete or ambiguous matches are skipped. The collection set retains its existing Chinese name after upgrading so previous review collections remain together. See `MergeCleanup.log` for details.

## Upgrading and troubleshooting

Replace both plug-in folders together while Lightroom is closed. Keep your catalog and photo files untouched. Logs and the last-run mapping live inside the plug-in folders, so preserve them before replacing folders if you need those records for cleanup; otherwise the exact mapping for an earlier HDR run will be unavailable and cleanup will rely on other evidence. Do not install the plug-in under a path containing spaces. If the HDR command fails, check whether Lightroom is in the foreground and inspect the two Auto HDR logs. If cleanup finds no safe candidates, select the result and every source photo, then inspect `MergeCleanup.log`.

## License

[MIT](LICENSE). This is an independent community project and is not affiliated with Adobe. Adobe and Lightroom are trademarks of Adobe Inc.
