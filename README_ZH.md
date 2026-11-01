# Lightroom Classic HDR Tools

[English](README.md)

- [1. Introduction](#1-introduction)
- [2. Quick Start](#2-quick-start)
- [3. Configuration](#3-configuration)
- [4. Optional Features](#4-optional-features)
- [5. Development](#5-development)
- [6. License](#6-license)

## 1. Introduction

拍摄包围曝光后，一组场景往往会留下好几张曝光不同的 RAW 照片。照片多了，需要反复选择、合成 HDR；合成完成后，原片又不能随意删除，因为必须先确认每张原片对应哪个合成结果。

Lightroom Classic HDR Tools 用**两个配合使用的插件**处理这件事：**Automatic Bracketed HDR** 从当前选中的照片中识别包围曝光组，调用 Lightroom Classic 自身的 HDR 合成功能逐组处理；**Merged Source Cleanup** 根据合成结果、文件堆栈和记录找到可能的源照片，放进**待人工复核的收藏集**。**两个插件都不会自动删除原片。**

插件在 **Windows 版 Adobe Lightroom Classic** 本地运行，不适用于云版 Lightroom，也不需要账号、API Key 或上传照片。由于 Lightroom 插件 SDK 没有直接开放 HDR 合并接口，自动合并通过 Windows 辅助程序发送 Lightroom 原生快捷键，因此运行时必须让 Lightroom 保持在前台。

## 2. Quick Start

下面完整走通一次：安装插件、合成一组 HDR、检查结果并生成原片审阅集合。**首次验收不需要删除任何照片。**

### 2.1. 准备环境

需要 Windows、已安装的 **Adobe Lightroom Classic**，且版本支持插件在 `Info.lua` 中声明的最低 Lightroom SDK `6.0`。**macOS、Linux 和云版 Lightroom 均不支持**。

开始前先备份 **Lightroom 目录（Catalog）和原始照片**。准备**两组不同**的包围曝光 RAW/DNG，每组 **2–9 张**：用 **A 组**手动合成一次、设置 Lightroom 的合成参数；用**尚未合成的 B 组**测试自动处理。不要对同一组反复合成，以免结果混淆。

B 组照片必须位于同一文件夹，使用相同相机、焦距及图像尺寸；相邻拍摄时间不超过 **2 秒**，整组曝光跨度至少 **1 EV**，并且具备必要的拍摄与曝光元数据。视频、虚拟副本、非 RAW/DNG 以及已标记 HDR/Pano 的文件不会参与分组。

### 2.2. 下载并安装

1. 打开[最新 Release](https://github.com/ThinkerQAQ/lightroom-plugin/releases/latest)，下载正式发布的 **ZIP 安装包**和 `SHA256SUMS.txt`。不要使用 GitHub 自动生成的 Source code 压缩包，它不是打包好的 Windows 插件。
2. 在下载目录打开 PowerShell，使用**实际下载文件名**替换占位符，计算校验值：

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\lightroom-plugin-YOUR-RELEASE.zip'
```

将输出与 `SHA256SUMS.txt` 中**相同文件名**对应的 SHA-256 比对；不一致不要安装。

3. 将 ZIP **完整解压到固定、可写、路径不含空格**的目录，例如 `C:\LightroomPlugins`。确认存在 `LightroomAutoHDRv2.lrplugin\Info.lua`、`LightroomMergeCleanup.lrplugin\Info.lua`，以及 `LightroomAutoHDRv2.lrplugin\AutoHDRInput.exe`。**两个 `.lrplugin` 文件夹保持并列**，清理插件才能读取 HDR 合成映射。
4. 打开 Lightroom Classic，进入「**文件 → 增效工具管理器（Plug-in Manager） → 添加**」，选择 `LightroomAutoHDRv2.lrplugin` **文件夹**安装；再添加 `LightroomMergeCleanup.lrplugin`。确认两个插件均已启用，然后关闭管理器。**不要选择 ZIP，也不要选择最外层的 `C:\LightroomPlugins` 文件夹。** 操作入口可参考 [Adobe 官方插件管理说明](https://helpx.adobe.com/in/lightroom-classic/desktop/export-photos/export-presets-settings-plug-ins.html)。

安装完成后，在「**图库（Library） → 增效工具额外功能（Plug-in Extras）**」中应能看到两个插件的菜单。

### 2.3. 设置 Lightroom 的 HDR 合成参数

1. 在 Lightroom 的「**图库**」中，选中用于设置参数的 **A 组**包围曝光照片。
2. 选择「**照片 → 照片合并 → HDR**」，在预览窗口中根据需要设置「**自动对齐**」「**自动色调**」「**去重影**」「**创建堆栈**」，然后点击「**合并**」。这是 Lightroom 自身的功能，详见 [Adobe 官方 HDR 合并说明](https://helpx.adobe.com/cn/lightroom-classic/desktop/process-and-develop-photos/hdr-photo-merge.html)。
3. 确认 A 组已产生预期的 HDR DNG。等待这次合成以及其他导入、导出、HDR 任务结束，再继续。

插件接下来调用 Lightroom 的**无预览 HDR 合并**，复用上一次手动操作的参数。**A 组只用于设置，B 组才用于自动合并测试。**

### 2.4. 自动合并 B 组

1. 在「**图库网格**」中只选中**尚未合成的 B 组 RAW/DNG**，不要选入 A 组的 DNG。
2. 选择「**图库 → 增效工具额外功能 → [v2] 自动识别并逐组合成 HDR DNG…**」。
3. 查看弹出的识别结果：正常应报告 **1 组**，且照片数量与 B 组一致。如显示 0 组或数量异常，先**取消**，根据 [2.1](#21-准备环境) 检查照片。
4. 点击「**开始合成**」，让 Lightroom 始终保持**前台窗口**；处理过程中不要操作鼠标或键盘。插件会选择照片、发送 `Ctrl+Shift+H` 快捷键，并等待磁盘出现**新的 DNG**。
5. 看到完成提示后再检查结果。每组最多等待 **180 秒**；失败会停止后续分组，不会跳过错误继续提交。

合成使用的是 Lightroom 自己的 HDR 引擎，不涉及云端处理或外部图片服务。

### 2.5. 验证结果并审阅原片

1. 在 Lightroom 和照片文件夹中确认 **B 组新生成的 HDR DNG**；同时检查 B 组原始 RAW/DNG **仍然存在**。
2. 查看已安装 `LightroomAutoHDRv2.lrplugin` 文件夹中的 `AutoHDR-v2.log` 与 `AutoHDR-v2-last-run.tsv`。如果合成和映射写入都成功，TSV 会记录新 DNG 与各张原片的路径。如果有 DNG 却没有映射，**不要直接认为清理插件已经获得完整对应关系**，先检查日志。
3. 回到「**图库网格**」，**同时选中 B 组的合成 DNG 和它对应的全部原片**。如果照片被折叠到堆栈里，先展开再选择。
4. 选择「**图库 → 增效工具额外功能 → 扫描合并结果与原片（堆栈/AutoHDR）…**」，核对识别组数、依据和需要保留的合成文件。只有确认匹配正确，再点击「**创建待删除收藏集**」。
5. 打开新建的**原片复核收藏集**，逐张确认缩略图和选中状态。**首次测试到这里就结束，不需要删除文件。** 扫描可创建收藏集和选择候选原片，但**不会删除磁盘文件，也不会修改原始照片内容**。

至此完成验收：**HDR DNG 已生成、原片仍在、可在收藏集中复核对应关系**。真正删除原片是独立操作，见 [Case 2](#42-case-2复核后删除源照片)。

### 2.6. 常见问题

- **没有插件菜单：**检查添加的是两个 `.lrplugin` 文件夹，且里面直接包含 `Info.lua`；确认已启用。切换语言后可重启 Lightroom。
- **没有识别到分组：**检查 **2–9 张 RAW/DNG**、相同文件夹/相机/焦距/尺寸、相邻时间 **2 秒**及曝光跨度 **1 EV** 等条件；不要混入虚拟副本或已有 HDR 成品。
- **自动合并启动失败：**让 Lightroom 保持**前台**，确认插件路径**无空格且可写**、`AutoHDRInput.exe` 存在；检查 `AutoHDRInput.log` 与 `AutoHDR-v2.log`。退出码 **20** 表示未找到 Lightroom、**22** 表示 Lightroom 不是前台、**23** 表示 Windows 按键发送失败。
- **等待 DNG 超时：**检查是否还有其他导入、导出或 HDR 任务。插件以目标文件夹出现新 DNG 作为完成依据，重试前先看日志。
- **清理没有找到安全候选：**必须同时选中合成结果和所有原片，或核实真实文件夹堆栈。缺少映射、有歧义时会跳过；查看 `MergeCleanup.log`。
- **Windows 提示程序未签名：**辅助程序确实未签名，可先阅读 `AutoHDRInput.cs`，必要时[自行编译](#5-development)，不要为运行它而直接关闭系统安全保护。

其他问题可[提交 Issue](https://github.com/ThinkerQAQ/lightroom-plugin/issues)，附复现步骤和**脱敏**日志，不要公开私人照片名或本地完整路径。

## 3. Configuration

**无需 TOML、账号、API Key 或额外服务配置。** 自动 HDR 直接使用 Lightroom 最近一次手动合并时选择的参数；插件自带英文与简体中文菜单。

两个 `.lrplugin` 应放在**并列、可写、无空格的固定目录**。HDR 插件把 `AutoHDR-v2.log`、`AutoHDRInput.log` 和最近一次 `AutoHDR-v2-last-run.tsv` 写在自己的文件夹里；清理插件在自己的文件夹生成 `MergeCleanup.log`，并按需读取相邻 HDR 目录中的记录。**每次开始新的自动合并都会重置 last-run TSV**，如果还需要旧映射，请提前备份。

清理插件依次依据**真实 Lightroom 文件夹堆栈、AutoHDR 精确映射/日志、受约束的文件名与元数据**判断原片。任何证据不完整或归属不明确的照片都应跳过，不能认为「合成 DNG 附近的 RAW」一定可以删除。

## 4. Optional Features

### 4.1. Case 1：测试 HDR 快捷键

如果自动合并卡在辅助程序阶段，可以用**另一组未合成的测试照片**先手动确认 `Ctrl+Shift+H` 能触发 Lightroom HDR，然后选择「**图库 → 增效工具额外功能 → [v2] 测试合并当前选择一次…**」，确认「**发送一次**」。

**这个测试不是空跑。** 它会真的向 Lightroom 发送 HDR 快捷键，**可能生成新的 DNG**；但不会自动分组、改变选择或创建源图映射。不要测试完同一组，又直接拿它运行自动合并。

### 4.2. Case 2：复核后删除源照片

清理插件只负责**生成待审阅集合**。确认每张候选确实是原片、需要保留的合成 DNG 正确、原片已备份以后，才可以执行 Lightroom 原生的 **Ctrl+Alt+Shift+Backspace**，并在确认窗口选择「**从磁盘删除**」。

这是**用户主动执行的删除操作**，不是安装验收的一步。Windows 通常会把本地删除文件送入回收站，但**不能依赖回收站代替备份**。快捷键可核对 [Adobe 官方 Lightroom Classic 快捷键列表](https://helpx.adobe.com/in/lightroom-classic/desktop/introduction-to-lightroom-classic/keyboard-shortcuts.html)。如果插件没有成功全选候选照片，必须**先人工确认并选择**，不能对不确定的选择直接执行删除。

### 4.3. Case 3：升级或单独使用清理插件

升级前先关闭 Lightroom。如果后续还需要旧批次的精确原片映射，先备份 `AutoHDR-v2-last-run.tsv` 和相关日志。下载新版 Release 后，在**原安装位置**一起替换两个插件文件夹，再到「**文件 → 增效工具管理器**」确认仍然启用。不要把 Lightroom 目录数据库或原始照片当成插件文件替换。

也可以单独安装 **Merged Source Cleanup**：它仍能识别真实堆栈和符合安全约束的元数据，但没有相邻 HDR 插件的精确映射可供使用。

## 5. Development

源码由 **Lightroom SDK Lua 插件**和一个用来给前台 Lightroom 发送 `Ctrl+Shift+H` 的小型 **Windows C# 辅助程序**组成。

在安装了 Lua 5.4 工具的 Linux/macOS 上，可以从仓库根目录检查 Lua 语法：

```bash
git clone https://github.com/ThinkerQAQ/lightroom-plugin.git
cd lightroom-plugin
find . -name '*.lua' -print0 | xargs -0 -n 1 luac -p
git diff --check
```

在 **Windows PowerShell** 的仓库根目录，使用 .NET Framework C# 编译器重新编译辅助程序：

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /out:LightroomAutoHDRv2.lrplugin/AutoHDRInput.exe LightroomAutoHDRv2.lrplugin/AutoHDRInput.cs
if ($LASTEXITCODE -ne 0) { throw 'Helper compilation failed' }
```

CI 在 Linux 检查 Lua 和发行输入，在 Windows 编译辅助程序；正式 Release 会从源码重编辅助程序并生成 ZIP 和 SHA-256 清单。**目前没有真正运行在 Lightroom Classic 宿主中的自动集成测试**，实际 HDR 合并与原片复核需要 Windows Lightroom、测试 RAW/DNG 和已备份的目录。修改通过分支、PR Review 和 Squash Merge。

## 6. License

本项目原创源码采用 [MIT License](LICENSE)，不包括 Adobe 软件、Lightroom 许可证或用户摄影作品。这是**独立社区项目，与 Adobe 无隶属关系**。

**安全与隐私：**辅助程序是**未签名的本地 Windows 程序**，负责向前台 Lightroom 发送 HDR 快捷键。日志和 `AutoHDR-v2-last-run.tsv` 可能包含**本地路径、照片文件名及 Windows 用户信息**，不能直接上传公开仓库，反馈问题前先脱敏。插件不上传照片或凭据。安全漏洞尽量通过仓库的 [GitHub 私密安全报告](https://github.com/ThinkerQAQ/lightroom-plugin/security/advisories) 提交，不要在公开 Issue 中附原始私人日志。
