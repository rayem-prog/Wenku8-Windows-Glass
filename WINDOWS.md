# Windows 在线与玻璃界面候选版 0.5.0+164

基于 mikufoxxx/Wenku8_Flutter v0.4.6 的非官方 Windows 适配继续开发。上游地址：https://github.com/mikufoxxx/Wenku8_Flutter 。本次 Windows 改造日期：2026-10-23。

## 本次改造

- 引擎固定 Flutter 3.47.0 / Dart 3.13.0。Windows 使用该版本引擎默认渲染路径；不强制关闭 Impeller。
- Windows 在线发现、按书名/作者/ID 搜索、详情、目录、章节正文接入普通官网页面，结果送入原生阅读器。官网页面使用独立 WebView2 会话；需要登录或访问验证时，在应用内官网页面由用户完成，再重试原操作。
- 本地 TXT/EPUB、原文件、进度、书签、横竖排、翻页与书架动画继续保留。
- Windows 控件采用更清透的胶囊、细光学边缘、冷中性色和蓝色选中态；首次使用默认模糊 14、透明度参数 0.55。已有用户的外观参数继续保留，可以在设置中调整。
- Windows 刷新率跟随应用所在显示器的 vsync，可读取 60/120/144Hz 等显示器；不修改系统显示模式。移到另一台显示器后更新读数。
- 设置中增加“流畅度记录”：3 秒准备、20 秒操作、JSON 导出。按实际显示器刷新率计算 build/raster 帧预算。它不是实际显示帧率证明。

本版本没有新增云同步、Windows 账号私有 API、在线听书或 Android 专用文档转换器。官网不提供的内容会显示实际错误，不生成替代搜索结果或正文。不同页面结构、账号权限、网络条件仍需目标机器验证。

## 运行候选包

将完整 ZIP 解压到普通文件夹后运行 `wenku8_flutter.exe`，同时保留全部 DLL、data、许可文件。Windows 10 1809 或更新版本，建议 Windows 11 x64。官网连接需要 Microsoft Edge WebView2 Runtime；如果未安装，应用提供 Microsoft 下载页入口。应用不会静默安装运行时。

收到的是源码包时，里面没有新版 EXE，须先完成下面的 Windows 构建。2026-10-22 旧版 EXE 不代表本次改造结果。

## 在 Windows 构建

准备 Flutter 3.47.0（与 `.flutter-version` 一致）、Node.js 22、Python 3、Git，以及 Visual Studio 2022 的“使用 C++ 的桌面开发”和 Windows SDK。源码放在短路径，例如 `C:\src\wenku8`。在 PowerShell 运行：

```powershell
./Build-Windows.ps1
./tools/Package-Windows.ps1
```

可通过 `-Flutter C:\flutter\bin\flutter.bat` 指定 SDK。构建脚本会核对版本、解析依赖、静态检查、执行全部 Flutter 测试，再构建 Release。打包脚本要求源码已提交且工作区干净，从 Visual Studio 的 x64 CRT 目录复制运行时 DLL，并打包全部 Release 文件、源码、许可证、构建版本信息和 SHA256 校验。也可通过 `-VcRuntimeDirectory` 显式选择有权分发的 x64 Microsoft.VC*.CRT 目录。

仓库有 `.github/workflows/windows.yml`，支持在 GitHub Actions 的 Windows 2022 运行器构建候选 ZIP；只上传构建产物，不发布 Release。公共仓库为 https://github.com/rayem-prog/Wenku8-Windows-Glass ，Windows 流程执行状态以仓库 Actions 为准。

## 原生检查与性能

```powershell
./tools/Validate-Windows.ps1
```

这会启动真实 Windows Flutter 窗口，检查本地书架、鼠标拖动、阅读器和翻页，保存截图。最终联网与流畅度验证按 `WINDOWS-ACCEPTANCE.md` 操作。使用实际 Release 程序，先热身再记录；不能用 Debug 测试或静态截图证明 120/144fps。

## 许可与源码

保留 LICENSE、NOTICE、assets/licenses 和 third_party。组合工程沿用 GPL v3，新增适配代码按相同条款提供。源码包包含版本锁、构建/验证脚本及全部对应修改；运行时依赖由 pubspec.yaml / pubspec.lock 记录。原私有 Android API 实现不在工程中，新的 Windows 联网实现为公开网站适配器。

从源码 ZIP 开始且当前目录还不是 Git 仓库时，先执行 `git init`、`git add .`、`git commit -m "Windows 0.5.0 candidate"`，再运行构建和打包，以便源码提交号与二进制一一对应。GitHub Actions 检出的工程已经具备 Git 元数据。

官网连接组件固定为 `webview_flutter_windows 1.3.0`，Windows 构建另需 CMake 3.20 或更新（当前 Visual Studio 2022 提供）。它修复了上游旧组件的窗口焦点与释放问题；首次构建会通过 NuGet 下载 WebView2 SDK/WIL，须能访问 NuGet。
