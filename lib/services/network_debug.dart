import 'package:flutter/foundation.dart';

/// 网络诊断日志：同时打控制台 + 存内存，界面可直接看
class NetworkDebug {
  NetworkDebug._();

  static const _max = 80;
  static final List<String> _lines = [];

  static List<String> get lines => List.unmodifiable(_lines);

  static String get recentText {
    if (_lines.isEmpty) return '（暂无日志，点「测试并保存」或打开群聊会记录）';
    return _lines.takeLast(20).join('\n');
  }

  static void log(String tag, String msg) {
    final line = '${_ts()} [$tag] $msg';
    _lines.add(line);
    while (_lines.length > _max) {
      _lines.removeAt(0);
    }
    debugPrint(line);
  }

  static void clear() {
    _lines.clear();
    log('Debug', '日志已清空');
  }

  static String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:'
        '${n.minute.toString().padLeft(2, '0')}:'
        '${n.second.toString().padLeft(2, '0')}';
  }
}

extension _TakeLast on List<String> {
  Iterable<String> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
