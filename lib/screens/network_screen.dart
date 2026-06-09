import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/referral_qr.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _referrerCtrl = TextEditingController();
  bool _binding = false;

  @override
  void dispose() {
    _referrerCtrl.dispose();
    super.dispose();
  }

  String _shortAddr(String? a) {
    if (a == null || a.length < 12) return a ?? '—';
    return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
  }

  Future<void> _submitBind(AppState state) async {
    final raw = _referrerCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写推荐人 TRON 地址')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认绑定推荐人'),
        content: Text(
          '绑定后不可修改。\n\n推荐人：${ReferralQr.parseParent(raw) ?? raw}\n\n'
          '未绑定时，付款转单将默认分配给平台服务中心网络。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认绑定')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _binding = true);
    try {
      await state.bindReferrer(raw);
      if (!mounted) return;
      _referrerCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('推荐人绑定成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final d = state.dashboard;
    final net = state.network;
    final chain = state.transferChain;
    final parent = state.parentAddress;
    final hasParent = state.hasBoundReferrer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的团队'),
        actions: [
          TextButton(
            onPressed: () => context.push('/network/assessment'),
            child: const Text('考核详情'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _miniStat('团队', '${d?.teamCount ?? net?['teamCount'] ?? 0}'),
                _miniStat('一代', '${net?['gen1Count'] ?? 0}'),
                _miniStat('二代', '${net?['gen2Count'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('推荐人绑定', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (hasParent) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('已绑定上级'),
                        subtitle: SelectableText(parent!),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: parent));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制推荐人地址')),
                            );
                          },
                        ),
                      ),
                      const Text(
                        '已绑定，不可修改。下级未绑定时将挂在你名下。',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ] else ...[
                      const Text(
                        '仅可填写一次。绑定后关系网生效；未绑定则付款转单默认走平台服务中心网络。',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _referrerCtrl,
                        decoration: const InputDecoration(
                          labelText: '推荐人地址（T 开头）',
                          hintText: '粘贴或扫码填入',
                          border: OutlineInputBorder(),
                        ),
                        autocorrect: false,
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: (_binding || state.loading) ? null : () => _submitBind(state),
                        child: _binding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('绑定推荐人（仅一次）'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (chain != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('付款转单链（谁付谁收）', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        hasParent ? '已绑上级 · L1 为你的推荐人' : '未绑上级 · L1 为分配的服务中心',
                        style: const TextStyle(fontSize: 12, color: Colors.cyan),
                      ),
                      const SizedBox(height: 10),
                      ...((chain['chain'] as List<dynamic>? ?? []).map((item) {
                        final m = item as Map<String, dynamic>;
                        final level = m['level'];
                        final label = m['label'] ?? m['role'];
                        final addr = m['address'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text('L$level', style: const TextStyle(color: Colors.amber, fontSize: 12)),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$label', style: const TextStyle(fontSize: 12)),
                                    SelectableText(
                                      _shortAddr(addr),
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('团队考核（今日）', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('打卡率 ${d?.checkinRate ?? 0}%'),
                    Text('感谢信 ${d?.thankRate ?? 0}%'),
                    Text('等级 ${d?.assessmentLevel ?? '—'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('今日排单券价格'),
                trailing: Text('${d?.ticketPriceToday ?? 100} TRX/张'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  net?['treeText'] as String? ?? '暂无下级',
                  style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
