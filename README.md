# Client-flutter

MMM 分布式蓄水池互助 — **Flutter 客户端**（Android / iOS / Web / Windows）。

服务端仓库（另库部署）：

- 网关：[WSS-server](https://github.com/yongchaoqiu111/WSS-server)
- 私链：[Closed-Blockchain-server](https://github.com/yongchaoqiu111/Closed-Blockchain-server)

## 环境

- Flutter 3.x（SDK ^3.5.4）
- Dart ^3.5.4

```bash
flutter doctor
flutter pub get
```

## 运行

```bash
flutter run -d chrome      # Web
flutter run -d windows     # Windows
flutter run                # 已连接手机
```

## 连接服务器

首次启动后在 App 内：

**我的 → 服务器配置**

| 项 | 值 |
|----|-----|
| HTTP API | `https://api.你的域名.com` |
| WebSocket | `wss://api.你的域名.com/ws` |

本地开发：

- API：`http://127.0.0.1:8443`
- WSS：`ws://127.0.0.1:8443/ws`

## 链上排单（pool-v4 · 一期 Vercel 快照）

| 文档 | 说明 |
|------|------|
| [docs/pool-v4-dev-master-zh.md](docs/pool-v4-dev-master-zh.md) | **开发总览（档位 + 匹配算法 + 源码索引）** |
| [docs/pool-v4-algorithm-zh.md](docs/pool-v4-algorithm-zh.md) | 算法完整说明 |
| [docs/pool-snapshot-phase2-upgrade-zh.md](docs/pool-snapshot-phase2-upgrade-zh.md) | 一期→二期 WSS 升级 |
| [docs/pool-snapshot-server-zh.md](docs/pool-snapshot-server-zh.md) | 快照服务器设计 |

**快照仓（算法 + 每日 JSON）**：[yongchaoqiu111/js](https://github.com/yongchaoqiu111/js) → Vercel CDN

| 功能 | 需要用户 TronGrid Key |
|------|----------------------|
| 看全队排单大盘 | ❌（读平台快照） |
| 付出场池后验款 / 刷新链上状态 | ✅ |

| 模块 | 路径 |
|------|------|
| 数据门禁说明 | `lib/config/pool_data_policy.dart` |
| 快照 URL 配置 | `lib/config/pool_snapshot_config.dart` |
| 远程快照拉取 | `lib/services/pool_remote_snapshot_service.dart` |
| 匹配（快照优先） | `lib/services/pool_matcher_service.dart` |
| Key 注册引导 | `lib/screens/trongrid_api_key_screen.dart` |

## 打包

```bash
# 默认已内置 js-chi-flax.vercel.app，可覆盖或加多 V 分流
flutter build apk --release \
  --dart-define=POOL_SNAPSHOT_URL=https://js-chi-flax.vercel.app

flutter build web --release
flutter build windows --release
```

当前版本见 `pubspec.yaml`（如 `1.0.7+8`）。Release APK 输出：`build/app/outputs/flutter-apk/app-release.apk`

## 安全说明

- 助记词/私钥仅存本机安全区，不上传服务器
- 勿将 `.env`、密钥文件提交到 Git
