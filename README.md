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

## 打包

```bash
flutter build apk --release
flutter build web --release
flutter build windows --release
```

## 安全说明

- 助记词/私钥仅存本机安全区，不上传服务器
- 勿将 `.env`、密钥文件提交到 Git
