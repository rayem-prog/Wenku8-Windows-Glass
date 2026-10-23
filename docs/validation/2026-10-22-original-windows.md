# Windows 适配验证（2026-10-22）

- 环境：Windows 11 x64，Flutter 3.41.5 / Dart 3.11.3，Visual Studio Build Tools 2022。
- `flutter analyze --no-pub`：初版适配代码无问题。
- 单元/组件回归：36 项通过，覆盖 Windows 中文解码、原文件保留、TXT/EPUB 导入及书库重新加载、进度保存与恢复、原版翻页动效和立体书架。
- `flutter build windows --release --no-pub`：成功生成 Windows x64 程序。
- 原生 Windows 集成测试：1 项通过，在真实 Windows Flutter 渲染窗口中显示 12 本测试书的立体书架、验证鼠标拖动位置变化，并打开双页阅读器、执行 PageDown 翻页。测试数据使用临时目录，测试结束清理。
- 已检查原生窗口渲染截图，书架拖动与阅读翻页后的画面正常。
- Windows 液态玻璃检测到无 Impeller，采用上游提供的磨砂/颜色/边缘回退效果。

测试范围不等于全部上游功能验收。本轮未通过人工点选验证所有系统文件选择对话框；网盘、在线书库、账号、听书及 Android 专用文档转换不属于本版范围。
