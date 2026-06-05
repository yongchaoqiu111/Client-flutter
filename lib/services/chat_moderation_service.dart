import '../config/chat_config.dart';
import '../models/chat_send_result.dart';

/// 群聊发言频控 + 违规内容过滤（前端执行，收发双向）
class ChatModerationService {
  static final _phone131 = RegExp(r'(?:^|[^\d])1\s*3\s*[1-9](?:\s*\d){8}(?:[^\d]|$)');
  static final _phone170 = RegExp(r'(?:^|[^\d])1\s*7\s*[0-9](?:\s*\d){8}(?:[^\d]|$)');
  static final _qqPattern = RegExp(r'(qq|q\s*群|扣扣)', caseSensitive: false);
  static final _wechatPattern = RegExp(r'(微信|weixin|wechat|微\s*信|v\s*信|vx|wx\s*号)');
  static final _scamKeywords = RegExp(
    r'(诈骗|欺骗|传销|资金盘|割韭菜|稳赚|躺赚|日入|月入百万|拉人头|发展下线|'
    r'交入会费|高额回报|保本保息|一夜暴富|刷单返利|杀猪盘|庞氏)',
  );

  static ChatSendResult validateSend({
    required String content,
    DateTime? lastSentAt,
  }) {
    final text = content.trim();
    if (text.isEmpty) {
      return ChatSendResult.fail('消息不能为空');
    }
    if (text.length > 200) {
      return ChatSendResult.fail('单条消息不超过 200 字');
    }

    final cooldown = _cooldownRemaining(lastSentAt);
    if (cooldown > 0) {
      return ChatSendResult.fail('发言太频繁，请 $cooldown 秒后再发');
    }

    final blocked = _blockedReason(text);
    if (blocked != null) {
      return ChatSendResult.fail(blocked);
    }

    return ChatSendResult.success();
  }

  /// 接收消息时过滤，违规内容不入库
  static bool shouldDisplay(String content) => _blockedReason(content) == null;

  static int cooldownRemaining(DateTime? lastSentAt) => _cooldownRemaining(lastSentAt);

  static int _cooldownRemaining(DateTime? lastSentAt) {
    if (lastSentAt == null) return 0;
    final elapsed = DateTime.now().difference(lastSentAt).inSeconds;
    final left = ChatConfig.sendIntervalSeconds - elapsed;
    return left > 0 ? left : 0;
  }

  static String? _blockedReason(String text) {
    final normalized = text.replaceAll(' ', '').toLowerCase();

    if (_wechatPattern.hasMatch(text) || normalized.contains('微信')) {
      return '已屏蔽：禁止发布微信等站外联系方式';
    }
    if (_qqPattern.hasMatch(text)) {
      return '已屏蔽：禁止发布 QQ 等站外联系方式';
    }
    if (_phone131.hasMatch(text)) {
      return '已屏蔽：禁止发布 131-139 号段电话';
    }
    if (_phone170.hasMatch(text)) {
      return '已屏蔽：禁止发布 170-179 号段电话';
    }
    if (_scamKeywords.hasMatch(text)) {
      return '已屏蔽：疑似诈骗/传销/欺骗类内容';
    }

    return null;
  }
}
