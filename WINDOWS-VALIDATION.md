# 0.5.0+164 改造验证记录（2026-10-23）

## 已有证据

- 本机：macOS arm64；官方 Flutter 3.47.0 / Dart 3.13.0。
- Flutter framework：4cf24164269a5ebf0c16a028a00727d0e77bbb05；engine：5f77625673248ee5846fbcaf5d3e1a3878386fd7。
- 原 Windows/本地阅读/历史/翻页/书架基线：35 项通过、1 项按平台跳过。
- 最终完整 Flutter 回归：868 项通过、9 项按平台跳过，全部通过；包含原本地阅读与动画回归。首轮发现的版本标识不一致已经修正。
- 工具回归：Python 25 项、Node 18 项通过。
- 对应提交源码在归档前执行文件清单和私有数据检查；详情与源码提交号见交付说明。
- Windows PowerShell 构建/打包脚本及 CI 已编写，但尚未在 Windows 执行；不把脚本存在视为构建通过。
- 新增测试覆盖：显示器刷新率变化与帧预算、网站 HTML 解析和分页/章节、GBK 搜索编码、实际生成的浏览器 fetch 脚本、正常官网验证后的操作恢复、封面缓存、缺少 WebView2 的恢复入口、记录导出界面、Windows 外观默认值及已有设置保留。
- `dart analyze lib test integration_test`：无问题。本机 Flutter SDK 为官方稀疏源码检出，SDK 自身 dev/examples 未成功下载，`flutter analyze` 的 SDK 工程枚举失败；不代表应用分析失败。Windows CI 使用完整 SDK，并强制执行 `flutter analyze`。
- 浅色/深色和玻璃控件回归 30 项通过；本机 CPU 渲染已检查布局和中文字形。CPU 截图使用磨砂回退，不能证明 Windows GPU 折射效果。
- 实际官网探测：直连请求遇到访问验证；正常浏览器进入官网登录页。当前没有在 Windows 上用账号完成真实搜索/正文读取；测试夹具不是线上成功证据。

## 仍待完成

- 在 Windows 运行器执行新版原生编译、打包脚本和原生窗口测试。当前主机不能生成或运行 Windows EXE。
- 朋友机器上的官网登录后搜索/目录/正文与缓存验证。
- 朋友机器上的 Impeller 玻璃效果、60/120/144Hz 流畅度与实际呈现验收。尚无实际 FPS 保证。

项目具备对应源代码、测试、Windows 构建和打包流程，当前阶段为源码候选版，不能标为已交付的 Windows 安装包。

2026-10-22 的旧版 Windows 构建记录移至 docs/validation/2026-10-22-original-windows.md，仅作为历史证据，不适用于本次引擎和联网改造。

## 连接组件更新

官网组件固定为 webview_flutter_windows 1.3.0，替换 webview_windows 0.4.0。依据维护者迁移说明选择修复窗口焦点、释放与初始化问题的版本，应用的独立官网会话和原生阅读器接口不变。已回归缺少 WebView2、导航失败后重试、初始化中关闭、浏览器请求脚本及官网登录恢复路径。原生键盘/输入法/DPI/Impeller 纹理仍须 Windows 验证。

维护者说明：https://pub.dev/packages/webview_flutter_windows/changelog ；Flutter 版本与后端：https://docs.flutter.dev/perf/impeller 。

## 上传前收尾

新增可选 GPU 资源加载的失败隔离：着色器加载失败时不阻断启动，使用原生磨砂回退；性能 JSON 记录运行时就绪/加载失败状态。该策略已通过失败与并发初始化测试，真实 GPU 驱动故障仍属于 Windows 验证范围。

公共源代码仓库：https://github.com/rayem-prog/Wenku8-Windows-Glass 。原 GPL v2-or-later LICENSE 不变，另附 GPL v3 COPYING，新增 BSD/Mozilla 许可全文、修改日期与依赖来源。
