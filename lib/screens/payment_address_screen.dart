import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/network_debug.dart';
import '../services/raft_api_service.dart';
import '../widgets/network_debug_panel.dart';
import '../widgets/pin_dialog.dart';

class PaymentAddressScreen extends StatefulWidget {
  const PaymentAddressScreen({super.key});

  @override
  State<PaymentAddressScreen> createState() => _PaymentAddressScreenState();
}

class _PaymentAddressScreenState extends State<PaymentAddressScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().refreshAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change(AppState state) async {
    if (state.paymentAddressChangesLeft <= 0) return;
    final current = state.paymentAddress ?? '';
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更换收款地址'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'TRON 收款地址',
            hintText: 'T 开头的波场地址',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final next = ctrl.text.trim();
    if (!RaftApiService.isTreasuryConfigured(next)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的 TRON 地址（T 开头，非占位符）')),
      );
      return;
    }
    if (!await showPayPinDialog(context)) return;

    try {
      await state.updatePaymentAddress(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收款地址已更新')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final addr = state.paymentAddress;
    final changesLeft = state.paymentAddressChangesLeft;
    final hasCustom = RaftApiService.isTreasuryConfigured(state.user?['paymentAddress'] as String?);
    final addrType = hasCustom ? '自定义收款地址' : '默认（当前钱包地址）';

    return Scaffold(
      appBar: AppBar(
        title: const Text('收款账户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading && addr == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前收款账户', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (addr != null)
                            SelectableText(addr, style: const TextStyle(height: 1.4))
                          else
                            const Text(
                              '请先创建或导入钱包',
                              style: TextStyle(color: Colors.orange),
                            ),
                          const SizedBox(height: 8),
                          Text('类型：$addrType', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '剩余更换次数: $changesLeft',
                    style: TextStyle(color: changesLeft > 0 ? Colors.orange : Colors.red),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '匹配出场时，其他用户将向此地址转账。未设置时使用本机钱包地址。',
                    style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (changesLeft > 0 && addr != null) ? () => _change(state) : null,
                    child: const Text('更换收款地址'),
                  ),
                  if (addr != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: addr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制收款地址')),
                        );
                      },
                      child: const Text('复制地址'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    '设置后写入共识节点；生产环境更换需多签确认。',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const NetworkDebugPanel(
                    title: '收款排查日志',
                    compact: true,
                  ),
                ],
              ),
            ),
    );
  }
}
