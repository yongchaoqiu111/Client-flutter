import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_build_info.dart';
import '../config/chain_config.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final chain = context.watch<AppState>().chain ?? 'TRON';
    final demo = context.watch<AppState>().demoPayments;

    return Scaffold(
      appBar: AppBar(title: const Text('系统设置')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('默认链'),
            subtitle: Text(chain),
            trailing: DropdownButton<String>(
              value: chain,
              items: ChainConfig.supported
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
          SwitchListTile(
            title: const Text('演示支付'),
            subtitle: const Text('开启后不生成本地链上广播，仅生成 tx 哈希提交共识'),
            value: demo,
            onChanged: (v) => context.read<AppState>().setDemoPayments(v),
          ),
          ListTile(
            title: const Text('版本'),
            subtitle: Text(AppBuildInfo.buildTag),
            trailing: Text(AppBuildInfo.versionLabel),
          ),
          const ListTile(
            title: Text('出场加速'),
            subtitle: Text('node1 默认 DEMO_FAST_EXIT=1（约 1 分钟入队、30 秒/日发放）'),
          ),
        ],
      ),
    );
  }
}
