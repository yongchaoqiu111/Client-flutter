import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(state.wallet?.shortAddress ?? '未登录'),
            subtitle: Text('${state.balanceLabel} · 券 ${state.ticketBalance} 张'),
          ),
          _menu(context, Icons.account_balance_wallet, '钱包管理', '/me/wallet'),
          _menu(context, Icons.confirmation_number, '我的排单券', '/ticket'),
          _menu(context, Icons.bar_chart, '我的业绩', '/me/performance'),
          _menu(context, Icons.security, '安全设置', '/me/security'),
          _menu(context, Icons.payments, '收款账户', '/me/payment-address'),
          _menu(context, Icons.dns, '服务器配置', '/me/nodes'),
          _menu(context, Icons.card_giftcard, '烧伤奖励', '/me/rewards'),
          _menu(context, Icons.help_outline, '帮助中心', '/help'),
          _menu(context, Icons.settings, '系统设置', '/settings'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('刷新数据'),
            onTap: () => state.refreshAll(),
          ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, String path) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
  }
}
