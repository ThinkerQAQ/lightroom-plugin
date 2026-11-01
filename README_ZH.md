# Lightroom Classic HDR Tools

[English](README.md)

## 项目简介

两个在本机运行的 Windows Lightroom Classic 插件：**Automatic Bracketed HDR** 检测包围曝光分组并提交 HDR 合并；**Merged Source Cleanup** 将可能的源照片加入待审阅集合。适合处理包围曝光 RAW/DNG 的摄影用户。这是独立社区项目，适用于 Classic，不适用于云版 Lightroom，不上传照片。

## 快速开始

### 1. 前置条件

Windows、支持 SDK **6.0+** 的 Adobe Lightroom Classic、可写且**不含空格**的安装路径，以及一小组 2–9 张包围曝光 RAW/DNG。macOS/Linux 不支持。先备份目录与源照片；自动合并期间 Lightroom 必须保持前台。

### 2. 下载与安装

1. 从 [Releases](https://github.com/ThinkerQAQ/lightroom-plugin/releases/latest) 下载发行资产 ZIP 和 `SHA256SUMS.txt`，不要使用 GitHub 自动生成的源码压缩包。
2. 对比 ZIP 的 SHA-256 与清单。例如 PowerShell：`Get-FileHash .\lightroom-plugin-vVERSION.zip -Algorithm SHA256`，替换实际文件名。
3. 将 `LightroomAutoHDRv2.lrplugin`、`LightroomMergeCleanup.lrplugin` 并排解压到可写、无空格目录，例如 `C:\LightroomPlugins`。两个目录放在一起，清理插件才能找到 HDR 映射。
4. 在 Lightroom「文件 → 增效工具管理器 → 添加」分别添加两个 `.lrplugin`，确认均已启用。发行包 HDR 目录必须包含 `AutoHDRInput.exe`。

### 3. 配置并合并一组照片

1. 先手动合并一次包围曝光，选择需要的自动对齐、自动色调、去重影和堆栈选项；自动无预览合并复用 Lightroom 上次设置。
2. 在图库网格中选择同一文件夹的一组 RAW/DNG 原片。相机、焦距、尺寸应一致，相邻拍摄间隔不超过 2 秒，曝光跨度至少 1 EV。
3. 进入「图库 → 增效工具额外信息」选择对应的「[v2] 检测并合并包围曝光 HDR DNG」菜单。确认分组数量后开始。先停止其他导入、导出或 HDR 任务，运行时保持 Lightroom 前台，不操作鼠标键盘。
4. 等待结果。每组等待 DNG 最长 180 秒，失败时停止后续提交。视频、虚拟副本、其他格式及文件名已标记 HDR/Pano 的文件会被排除。

### 4. 验证并审阅源照片

验收标准：目录中出现新合并的 DNG，且 HDR 插件旁的 `AutoHDR-v2-last-run.tsv` 记录了该 DNG 与源照片的对应关系。原片仍应存在，自动 HDR 不删除源照片。

可以在不删除文件的情况下验证清理流程：

1. 在图库网格中同时选中合并结果和全部 RAW 源照片。
2. 选择「图库 → 增效工具额外信息 → 扫描合并结果与源照片（堆栈/AutoHDR）」对应菜单。
3. 检查数量、依据和保留的合并文件，打开生成的审阅集合，逐张确认缩略图与选择。扫描不能修改源文件。

只有本人确认选择正确后，才可在 Lightroom 按 **Ctrl+Alt+Shift+Backspace**，注意是退格键，不是 Delete，再选择「从磁盘删除」。这是用户主动删除到 Windows 回收站的操作，不属于扫描，也不是 Quick Start 必需验收步骤。

### 5. 常见问题

- **菜单未出现：**确认分别添加了 `.lrplugin` 目录，而不是上层目录或 ZIP。语言变更后重启 Lightroom。
- **合并未开始：**确认 Lightroom 在前台、路径无空格且存在 `AutoHDRInput.exe`，查看 `AutoHDR-v2.log`、`AutoHDRInput.log`。
- **没有分组：**使用符合上面条件的 RAW/DNG 原片，不能只有虚拟副本或已有 HDR/Pano。
- **找不到可靠清理候选：**选中合并结果和全部源照片，查看 `MergeCleanup.log`。不完整或有歧义的匹配会跳过。
- **Windows 提示未签名：**可检查 `AutoHDRInput.cs` 后自行编译；该辅助程序只向前台 Lightroom 发送 HDR 快捷键。

## 配置说明

无需单独 TOML、账户或 API Key。合并选项来自 Lightroom 最近一次手动 HDR 合并。包含英文和简体中文界面，其他 Lightroom 语言回退英文。

日志与最近成功源图映射位于插件目录，因此目录必须可写。清理依次检查真实文件夹堆栈、Auto HDR 精确映射，再采用受限的文件名/元数据匹配。升级保留原集合组名称。

## 可选功能

升级时关闭 Lightroom，同时替换两个插件目录。需要旧的精确映射时，替换前保留日志和 `AutoHDR-v2-last-run.tsv`；否则清理只能使用其他依据。不要在升级插件时替换目录或照片。源照片清理插件可独立使用，没有 Auto HDR 映射时依赖其他受支持证据。

## 开发与验证

源码为 Lightroom Lua 插件和 Windows C# 快捷键辅助程序。在安装 Lua 5.4 的 Linux/macOS 上可检查 Lua 语法：

```sh
find . -name '*.lua' -print0 | xargs -0 -n 1 luac -p
```

在仓库根目录的 Windows PowerShell 编译辅助程序：

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:LightroomAutoHDRv2.lrplugin/AutoHDRInput.exe LightroomAutoHDRv2.lrplugin/AutoHDRInput.cs
if ($LASTEXITCODE -ne 0) { throw 'Helper compilation failed' }
```

CI 在 Linux 检查 Lua 语法及发行输入，在 Windows 编译辅助程序。标签触发的发行流程从源码编译并发布 ZIP/校验清单。当前没有自动 Lightroom 宿主集成测试，真实合并和审阅集合验收需要 Windows Lightroom 与已备份的测试目录。使用功能分支、PR 和 Squash Merge。

## 许可证与合规

[MIT](LICENSE) 覆盖本项目源码，不覆盖 Adobe 软件、用户目录或照片。本项目与 Adobe 无隶属关系，Adobe/Lightroom 商标归 Adobe 所有。用户需要自己的合法 Classic 安装与素材使用权。发行辅助程序未签名，详见[安全说明](SECURITY.md)。
