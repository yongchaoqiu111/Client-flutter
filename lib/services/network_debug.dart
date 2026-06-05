import 'package:flutter/foundation.dart';

/// 网络/聊天诊断日志：控制台 + 内存，界面实时刷新
class NetworkDebug {
  NetworkDebug._();

  static const _max = 120;
  static final List<String> _lines = [];
  static VoidCallback? onLog;

  static List<String> get lines => List.unmodifiable(_lines);
  static int get count => _lines.length;

  static String get recentText {
    if (_lines.isEmpty) return '（暂无日志）\n打开群聊/直播间、发送消息后会自动记录 WSS 每一步';
    return _lines.takeLast(35).join('\n');
  }

  static void log(String tag, String msg) {
    final line = '${_ts()} [$tag] $msg';
    _lines.add(line);
    while (_lines.length > _max) {
      _lines.removeAt(0);
    }
    debugPrint(line);
    onLog?.call();
  }

  static void clear() {
    _lines.clear();
    log('Debug', '日志已清空');
  }

  static String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}.'
        '${(n.millisecond ~/ 100).toString()}';
  }
}

extension _TakeLast on List<String> {
  Iterable<String> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
