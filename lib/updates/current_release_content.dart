import 'release_notices.dart';

class ReleaseSection {
  const ReleaseSection(this.title, this.items);
  final String title;
  final List<String> items;
}

const inAppCommunityNotice = r'''**交流群：1131397088**\
遇到问题或有功能建议，欢迎进群反馈。''';
const releaseFreeNotice = "**本项目完全免费、开源，无任何赞助、打赏或付费渠道。**";
const releaseReadingNotice =
    "**本项目仅为第三方阅读客户端，提供阅读界面与本地书籍管理，不运营在线书库、不自行发布小说资源。在线内容及可读状态一切以 Wenku8 为准；不提供因版权限制而停止开放的在线书籍阅读。**";

const _freeHeading = '### ⚠️ 免费开源，请勿付费';
const _freeFraudNotice =
    '不出售会员、激活码或功能解锁服务。任何以本项目或开发者名义收费、募捐、索要赞助的行为均与本项目无关，请勿付款。';
const _downloadNotice = '请通过**项目仓库或 App 内更新**获取安装包。';
const _freeNoticeBody =
    '$_freeHeading\n\n$releaseFreeNotice\n\n$_freeFraudNotice\n\n$_downloadNotice';
const _websiteReadingFix =
    '改善部分设备及网络环境下官网书籍详情、目录和正文无法加载的问题；需要访问验证时，可在官网页面完成验证后返回继续阅读。';
const _chineseUsernameFix = '修复文库账号用户名输入框无法正常输入中文的问题。';
const _trialShelfFix = '修复试读或缓存章节后书籍自动出现在书架的问题；在线书籍仅在主动加入书架后显示，缓存与阅读进度保留。';
const _releaseChanges =
    '### 本次更新\n\n- $_websiteReadingFix\n- $_chineseUsernameFix\n- $_trialShelfFix';

// Keep the in-app opening intact. Public announcements omit contact information.
const publicReleaseNotes =
    '$_freeNoticeBody\n\n$releaseReadingNotice\n\n**$currentReleaseSourcePolicy**\n\n$_releaseChanges';
const currentReleaseNotes = '$inAppCommunityNotice\n\n$publicReleaseNotes';

const currentReleaseSummary = [
  inAppCommunityNotice,
  releaseFreeNotice,
  releaseReadingNotice,
  currentReleaseSourcePolicy,
  _websiteReadingFix,
  _chineseUsernameFix,
  _trialShelfFix,
];

const currentReleaseSections = [
  ReleaseSection("重要说明 · 请务必阅读", [
    inAppCommunityNotice,
    _freeHeading,
    releaseFreeNotice,
    _freeFraudNotice,
    _downloadNotice,
    releaseReadingNotice,
    currentReleaseSourcePolicy,
  ]),
  ReleaseSection("本次更新", [
    _websiteReadingFix,
    _chineseUsernameFix,
    _trialShelfFix,
  ]),
];

const windowsReleaseSummary = [
  '非官方 Windows 测试版；升级前请先备份本地书籍与阅读记录。',
  '新增官网搜索、详情、目录和原生阅读；需要登录或访问验证时，在官网页面完成后返回继续。',
  '调整透明玻璃胶囊与深浅主题；原有透明度、减少动态效果设置继续保留。',
  '跟随窗口所在显示器刷新率；设置新增流畅度记录与导出，实际表现以设备测试为准。',
  '保留本地 TXT/EPUB、书架、进度、书签和阅读排版。',
];

const windowsReleaseSections = [
  ReleaseSection('Windows 本次改造', windowsReleaseSummary),
  ReleaseSection('使用说明', [
    '官网连接需要 WebView2；密码和访问验证由用户在官网页面自行完成。',
    '官网未提供的内容不会转换成阅读正文；网络与账号可用性以官网实际状态为准。',
    '本版未新增云同步和 Windows 在线听书。',
    '支持高刷新率调度不代表已通过 120/144fps 实机验收。',
  ]),
];
