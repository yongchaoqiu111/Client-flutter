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

## 链上排单（pool-v4-dual-pool）

App 内 **链上排单** 页为方案 A：TronGrid 拉买券 + 出场池入账，本地 Dart 引擎回放，与 WSS-server 规则一致。

| 模块 | 路径 |
|------|------|
| 规则配置 | `lib/config/pool_rules_config.dart` |
| 匹配引擎 | `lib/services/pool_engine_service.dart` |
| TronGrid 拉取 | `lib/services/pool_matcher_service.dart` |
| 出场验款 | `lib/services/exit_pay_verify.dart` |
| 快照持久化 | `lib/services/pool_snapshot_store.dart` |

算法说明（中英文，权威文档在服务端仓库）：

- [pool-v4-algorithm-zh.md](https://github.com/yongchaoqiu111/WSS-server/blob/main/docs/pool-v4-algorithm-zh.md)
- [pool-v4-algorithm-en.md](https://github.com/yongchaoqiu111/WSS-server/blob/main/docs/pool-v4-algorithm-en.md)

出场池地址（三档默认）：`TRjvctzrc5WcEeu2UrT8mV5H6zW8dCgimR`

## 打包

```bash
flutter build apk --release
flutter build web --release
flutter build windows --release
```

当前版本见 `pubspec.yaml`（如 `1.0.7+8`）。Release APK 输出：`build/app/outputs/flutter-apk/app-release.apk`

## 安全说明

- 助记词/私钥仅存本机安全区，不上传服务器
- 勿将 `.env`、密钥文件提交到 Git
