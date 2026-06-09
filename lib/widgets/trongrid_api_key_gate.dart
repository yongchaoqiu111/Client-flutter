import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

/// 执行须 Key 的操作前调用；已配置则返回 true，否则引导填写后返回是否已配置
Future<bool> ensureTronGridApiKey(
  BuildContext context, {
  required String actionTitle,
  String? message,
}) async {
  if (context.read<AppState>().hasTronGridApiKey) return true;

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(actionTitle),
      content: Text(
        message ??
            '此操作须查询您本人相关的链上转账，需要个人 TronGrid API Key。\n\n'
            '查看全队排单大盘无需 Key。请先注册 trongrid.io 并填写 Key。',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'guide'),
          child: const Text('注册说明'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'configure'),
          child: const Text('去配置 Key'),
        ),
      ],
    ),
  );

  if (choice == null) return false;

  if (!context.mounted) return false;
  await context.push('/settings/trongrid-key');
  if (!context.mounted) return false;
  return context.read<AppState>().hasTronGridApiKey;
}
