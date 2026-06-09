import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  final _apiKeyCtrl = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = context.read<AppState>().tronGridApiKey;
      if (key != null && _apiKeyCtrl.text.isEmpty) {
        _apiKeyCtrl.text = key;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(AppState state) async {
    await state.setTronGridApiKey(_apiKeyCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.hasTronGridApiKey ? 'TronGrid API Key 已保存' : '已清除 API Key',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chain = context.watch<AppState>().chain ?? 'TRON';
    final demo = context.watch<AppState>().demoPayments;
    final hasKey = context.watch<AppState>().hasTronGridApiKey;

    return Scaffold(
      appBar: AppBar(title: const Text('系统设置')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TronGrid API Key', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      '看全队排单读平台快照，无需 Key。'
                      '付出场池后验款、刷新本人链上状态、快照失败时本地回放，须个人 Key。'
                      '建议每人注册 trongrid.io，避免公共限流。',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => context.push('/settings/trongrid-key'),
                      child: const Text('查看注册步骤与说明'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apiKeyCtrl,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        labelText: 'TRON-PRO-API-KEY',
                        hintText: '在 trongrid.io 注册后粘贴',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => _saveApiKey(context.read<AppState>()),
                          child: const Text('保存 Key'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            _apiKeyCtrl.clear();
                            _saveApiKey(context.read<AppState>());
                          },
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                    if (hasKey)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('✓ 已配置个人 Key', style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('清除排单链上缓存'),
            subtitle: const Text('数据异常时全量重拉 TronGrid（不影响钱包）'),
            trailing: const Icon(Icons.delete_outline),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('清除链上缓存'),
                  content: const Text('将删除本地已缓存的买券/出场转账记录，下次刷新会重新从 TronGrid 拉取。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<AppState>().clearPoolTxCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('链上缓存已清除')),
                );
              }
            },
          ),
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
