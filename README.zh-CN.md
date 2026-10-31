# Lightroom Classic HDR 工具

[English](README.md)

这是一组适用于 Windows 版 Adobe Lightroom Classic 的本地插件：自动合并包围曝光照片，以及合并完成后整理原片候选。插件不上传照片。

| 插件 | 版本 | 功能 |
| --- | --- | --- |
| 自动包围曝光 HDR | 2.1.2 | 识别选中 RAW/DNG 中的包围曝光组，逐组调用 Lightroom 的 HDR 合并。 |
| 合并原片清理助手 | 1.1.1 | 找到合成结果对应的原片，放进收藏集供人工复核。 |

**适用范围：**Windows、Lightroom Classic（最低 SDK 6.0），不适用于云端版 Lightroom。HDR 插件需要 Lightroom 保持前台，插件完整路径不能包含空格。界面支持简体中文和英文；其他 Lightroom 界面语言回退为英文。

## 下载与安装

1. 从[最新 Release](https://github.com/ThinkerQAQ/lightroom-plugin/releases/latest)下载上传的 ZIP 文件，不要误用 GitHub 自动生成的 Source code 压缩包。
2. 解压两个 `.lrplugin` 文件夹到没有空格的路径，例如 `%APPDATA%\Adobe\Lightroom\Modules\`。两个插件要放在同一父目录，清理助手才可读取 Auto HDR 的精确映射记录。
3. 在 Lightroom Classic 打开**文件 > 增效工具管理器 > 添加**，分别添加两个 `.lrplugin` 目录。更新后如菜单语言未变化，请重启 Lightroom。
4. 先备份目录和原片，再用少量照片试运行。

安装包包含 `AutoHDRInput.exe`。它通过 Windows 向前台 Lightroom 发送 HDR 快捷键，是自动合并必需的辅助程序。若 Windows 提示未签名程序，可先审查 `AutoHDRInput.cs` 源码并自行编译。

## 自动合并包围曝光 HDR

1. 先手动合并一组照片，设好自动对齐、自动色调、去除重影和堆栈选项；后续无预览合并沿用这组设置。
2. 在图库网格选中同一文件夹的 RAW/DNG，运行**图库 > 增效工具额外功能 > [v2] 自动识别并逐组合成 HDR DNG…**。
3. 复核识别结果并开始。处理期间 Lightroom 必须在前台，不要使用键鼠；开始前先等待其他导入、导出或 HDR 任务结束。

一组为 2–9 张，要求文件夹、相机、焦距和尺寸相同，相邻拍摄间隔不超过 2 秒，曝光跨度至少 1 EV；视频、虚拟副本、非 RAW/DNG 和已命名 HDR/Pano 的文件会被排除。每组最多等待 180 秒生成 DNG，失败时停止后续组。插件不会删除源照片。最近一次成功合成的 DNG 与原片映射保存在插件目录的 `AutoHDR-v2-last-run.tsv`，日志为 `AutoHDR-v2.log` 和 `AutoHDRInput.log`。

## 复核合并后的原片

1. 在图库网格中同时选中合成结果和它对应的**全部** RAW 原片。批量操作时，可在合适的当前来源中全选。
2. 运行**图库 > 增效工具额外功能 > 扫描合并结果与原片（堆栈/AutoHDR）…**，核对组数、证据来源、保留的合成文件。
3. 插件会创建待复核收藏集并尝试选中候选原片。**逐张核对缩略图和实际选择。**扫描不会删除文件。
4. 只有确认无误后，才按 **Ctrl+Alt+Shift+Backspace**（退格键，不是 Del），并在 Lightroom 的确认框中选择**从磁盘删除**；文件进入 Windows 回收站。

识别依次参考真实文件夹堆栈、Auto HDR 精确映射、受约束的文件名与元数据匹配；不完整或有歧义的匹配会跳过。升级后收藏集根目录继续使用原有中文名称，避免把旧收藏集分开。细节见 `MergeCleanup.log`。

## 升级与排查

关闭 Lightroom 后同时替换两个插件目录，目录和照片数据不受此操作影响。日志与最近一次映射记录位于插件目录内：若后续还要根据旧 HDR 运行的精确映射清理原片，替换前请保留这些文件；丢失映射后只能依靠其他证据。HDR 操作失败时检查 Lightroom 是否在前台并查看两份 Auto HDR 日志；清理助手没有候选时检查是否选全合成结果与原片，并查看 `MergeCleanup.log`。

## 许可证

[MIT](LICENSE)。本项目为独立社区项目，与 Adobe 无关联。Adobe 和 Lightroom 为 Adobe Inc. 的商标。
