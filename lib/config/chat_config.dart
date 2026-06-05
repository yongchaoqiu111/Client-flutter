/// 官方群聊直播间配置
class ChatConfig {
  ChatConfig._();

  /// 默认官方频道，所有客户端连接 WSS 后自动订阅
  static const officialRoom = 'hall';
  static const officialRoomName = '官方群聊直播间';

  /// 每人发言间隔（秒）
  static const sendIntervalSeconds = 30;

  static const rulesHint =
      '每 30 秒可发 1 条；自动屏蔽微信/QQ/电话/诈骗/传销等违规内容';

  /// 播客页直播间卡片 A/B/C → WSS 房间号
  static String liveRoomId(String card) => 'live_${card.toLowerCase()}';

  static String liveRoomTitle(String card) => '直播间 ${card.toUpperCase()}';
}
