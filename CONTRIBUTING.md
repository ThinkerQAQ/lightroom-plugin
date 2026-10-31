# Contributing / 参与贡献

Use a pull request against `main`. CI parses every Lua source and compiles the Windows shortcut helper from its checked-in C# source. Actual HDR merging still requires manual acceptance in licensed Lightroom Classic on Windows; CI does not simulate Lightroom.

Keep the English and Chinese documentation and localization dictionaries aligned. Do not commit photographs, catalogs, logs, run mappings or Adobe SDK files. Original code uses MIT; third-party materials need their own documented permission.

Release tags use the existing calendar convention (`vYYYY.MM.DD[.N]`). The release workflow rebuilds the helper and packages the plug-ins with LICENSE, documentation and SHA-256 checksums. GitHub's source archive is not the installation bundle.

请向 `main` 提交 PR。CI 检查 Lua 语法并编译 Windows 辅助程序；真实 HDR 流程仍需在 Windows 的 Lightroom Classic 中验收。中英文文档与本地化字典保持同步，不提交照片、目录、日志、运行映射或 Adobe SDK 文件。发布工作流从源码构建并附带许可、文档及校验文件。
