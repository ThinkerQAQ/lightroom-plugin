# Lightroom Plugin

一组面向 Windows 版 Adobe Lightroom Classic 的本地增效工具，包含自动包围曝光 HDR 合并和合并原片清理两个插件。

> 这两个插件会操作照片选择、调用 Lightroom 原生命令，并生成本地日志。首次使用前请备份 Lightroom 目录，并先用少量测试照片验证流程。

## 插件

| 插件 | 版本 | 作用 |
| --- | --- | --- |
| `LightroomAutoHDRv2.lrplugin` | 2.1.1 | 识别选中照片中的包围曝光序列，逐组调用 Lightroom 的无预览 HDR 合并。 |
| `LightroomMergeCleanup.lrplugin` | 1.1.0 | 识别合并结果和对应原片，创建“待删除原片”收藏集供人工复核。 |

插件自身的详细操作说明分别见：

- [`LightroomAutoHDRv2.lrplugin/README.txt`](LightroomAutoHDRv2.lrplugin/README.txt)
- [`LightroomMergeCleanup.lrplugin/README.txt`](LightroomMergeCleanup.lrplugin/README.txt)

## 系统要求

- Windows
- Adobe Lightroom Classic（插件声明最低 Lightroom SDK 6.0）
- 使用 Auto HDR 时，Lightroom 必须位于前台
- 插件所在完整路径不要包含空格；当前辅助程序的启动方式对含空格路径不可靠

## 安装

1. 将两个 `.lrplugin` 目录复制到同一个父目录。建议使用：

   ```text
   %APPDATA%\Adobe\Lightroom\Modules\
   ```

2. 在 Lightroom Classic 中打开“文件 > 增效工具管理器”。
3. 选择“添加”，分别选中两个 `.lrplugin` 目录。
4. 先用少量测试照片验证插件行为。

两个插件应保持相邻目录结构，以便清理助手读取 Auto HDR 生成的精确映射记录：

```text
Modules/
├── LightroomAutoHDRv2.lrplugin/
└── LightroomMergeCleanup.lrplugin/
```

## 使用提示

### 自动包围曝光 HDR

先手动合并一组照片并设置 Lightroom 的自动对齐、自动色调、去除重影和创建堆栈选项。之后在图库网格中选中待处理照片，运行：

```text
图库 > 增效工具额外功能 > [v2] 自动识别并逐组合成 HDR DNG…
```

处理期间请保持 Lightroom 在前台，不要操作键盘或鼠标。该插件只生成 DNG，不删除源照片。

### 合并原片清理

在当前来源中同时选中合并结果和对应原片，运行：

```text
图库 > 增效工具额外功能 > 扫描合并结果与原片（堆栈/AutoHDR）…
```

插件只创建“待删除原片”收藏集，不会在扫描阶段删除文件。必须人工复核后，再使用 Lightroom 的删除命令和确认框完成删除。

## 构建辅助程序

`LightroomAutoHDRv2.lrplugin/AutoHDRInput.exe` 是由同目录的 `AutoHDRInput.cs` 构建的 Windows 辅助程序，用于在确认 Lightroom 位于前台后发送 `Ctrl+Shift+H`。仓库中附带的可执行文件未进行数字签名。

当前文件 SHA-256：

```text
CDE906AC8C8DD759A1D0525AB15AAFB940767A34A3388F38A54A153FF4CDA2C9
```

## 运行产物与隐私

以下文件可能包含本机用户名、路径、照片文件名或处理记录，已通过 `.gitignore` 排除，不应提交：

- `*.log`
- `AutoHDR-v2-last-run.tsv`

提交问题前请先审查并脱敏日志，不要公开原始照片路径或其他个人信息。

## 许可证

本仓库为私有项目，采用保留所有权利的专有许可。未经版权所有者书面许可，不得复制、修改或再分发。详见 [`LICENSE`](LICENSE)。
