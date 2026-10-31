English instructions: ../README.md
中文完整说明：../README.zh-CN.md

合并原片清理助手 1.1.1
========================

用途
----
扫描 Lightroom Classic 当前选中的 HDR/全景合成结果及原片，建立“待删除原片”
收藏集。它不会在扫描阶段直接删除文件。

1.1.1 修复
---------
- 不再要求 Lightroom 必须真正创建文件夹堆栈；
- 按三条证据链识别：真实文件夹堆栈、AutoHDR 精确清单/历史日志、文件名与
  拍摄时间元数据兜底；
- 真实堆栈中的合成结果不必位于第 1 张；
- 只有合成结果和至少两张源片形成完整映射才进入待删除收藏集；
- 创建收藏集后自动全选候选原片；
- 修正 Windows 删除快捷键为 Ctrl+Alt+Shift+Backspace（退格键）；
- 新增结构化 MergeCleanup.log。

使用
----
1. 在“图库”网格中同时选中 HDR DNG 和对应的全部 RAW 原片。批量处理时，
   请在包含合成结果与原片的当前来源中按 Ctrl+A。
2. 选择：图库 > 增效工具额外功能 >
   扫描合并结果与原片（堆栈/AutoHDR）…
3. 核对识别组数、候选原片数、证据来源和保留文件名。
4. 创建“待删除原片”收藏集；插件会打开它并尝试全选全部候选。
5. 再次人工复核缩略图。
6. 按 Ctrl+Alt+Shift+Backspace。注意是 Backspace/退格键，不是 Del。
7. 在 Lightroom 自己的确认框中选择“从磁盘删除”。文件将进入回收站。

识别证据
--------
1. 真实堆栈：读取文件夹堆栈的全部成员，保留其中所有名称明显为 HDR/Pano/
   Panorama/Merge 的 DNG/TIF/TIFF/PSD，仅把非合成 RAW/DNG 作为候选。
2. AutoHDR：读取相邻 LightroomAutoHDRv2.lrplugin 中的
   AutoHDR-v2-last-run.tsv 和 AutoHDR-v2.log，严格匹配 DNG 与每张源片路径。
3. 元数据兜底：合成结果名必须锚定首张源片，并通过文件夹、拍摄时间、相机、
   焦距、尺寸和 HDR 曝光跨度检查。

日志
----
LightroomMergeCleanup.lrplugin\MergeCleanup.log

日志包含时间、级别、traceId、节点、状态、耗时、识别证据、合成结果、源片、
收藏集写入结果以及自动选择校验，不记录密码或凭据。

安全说明
--------
- 插件不会直接修改 .lrcat 数据库，也不会自行删除磁盘文件；最终删除仍由
  Lightroom 原生命令和确认框完成。
- 如果 AutoHDR 记录与当前选择不完整、元数据闭环不安全或源片被两组合成结果
  重复引用，该组会被跳过。
- 删除前请备份 Lightroom 目录，并先用少量照片测试。
