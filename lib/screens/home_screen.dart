import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reservoir = state.reservoir;
    final d = state.dashboard;

    return RefreshIndicator(
      onRefresh: state.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(context, state),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard('链上余额', state.balanceLabel),
              const SizedBox(width: 8),
              _statCard('排单券', '${state.ticketBalance} 张'),
              const SizedBox(width: 8),
              _statCard('收益', '${d?.rewardBalance ?? 0} TRX'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.read<AppState>().setShellTab(1),
                  child: const Text('立即排单'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/ticket'),
                  child: const Text('购买排单券'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (reservoir != null) ...[
            Text('蓄水池 第 ${reservoir.roundNumber} 轮', style: Theme.of(context).textTheme.titleMedium),
            LinearProgressIndicator(value: reservoir.fillRatio),
            Text(
              '${reservoir.currentAmount.toStringAsFixed(0)} / ${reservoir.currentTarget.toStringAsFixed(0)} TRX',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 16),
          ],
          const Text('最新公告', style: TextStyle(fontWeight: FontWeight.bold)),
          ...state.announcements.map(
            (a) => Card(
              child: ListTile(
                title: Text(a['title']?.toString() ?? ''),
                subtitle: Text(a['content']?.toString() ?? ''),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('我的订单概览', style: TextStyle(fontWeight: FontWeight.bold)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _orderStat('排队', d?.orderCounts['queued'] ?? 0),
                  _orderStat('支付', d?.orderCounts['paying'] ?? 0),
                  _orderStat('收益', d?.orderCounts['earning'] ?? 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('团队业绩', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              _statCard('团队人数', '${d?.teamCount ?? 0}'),
              const SizedBox(width: 8),
              _statCard('考核完成', '${d?.checkinRate.toStringAsFixed(0)}%'),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(color: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(state.address ?? '未登录', style: const TextStyle(fontSize: 13))),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    if (state.address != null) {
                      Clipboard.setData(ClipboardData(text: state.address!));
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code, size: 18),
                  onPressed: state.address == null
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              content: QrImageView(data: state.address!, size: 180),
                            ),
                          ),
                ),
              ],
            ),
            if (state.referralCode != null)
              Text('推荐码: ${state.referralCode}', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderStat(String label, int n) => Column(children: [Text('$n'), Text(label, style: const TextStyle(fontSize: 11))]);
}
