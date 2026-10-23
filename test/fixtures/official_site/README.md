# 官网页面契约

login.html 是 2026-10-23 正常浏览器访问官网跳转登录页后，手工缩减的空表单结构；已去除广告、脚本、跟踪参数和无关版面，没有登录信息。只保留检测登录要求使用的 frmlogin/password 属性。

普通官网入口：https://www.wenku8.net/ 。目录/搜索结构另与公开页面契约 https://gist.github.com/zsakvo/64a79f3f5c3802ac2003ab33d271afb8 交叉核对。test/official_site_parser_test.dart 的书籍、目录和正文样例为手写契约，均不代表线上请求已经成功。
