import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppState>().dashboard;
    final state = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('团队考核详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _block('打卡统计', d?.checkinRate ?? 0),
          _block('感谢信统计', d?.thankRate ?? 0),
          ListTile(
            title: const Text('综合等级'),
            trailing: Text(d?.assessmentLevel ?? '—'),
          ),
          ListTile(
            title: const Text('今日排单券价'),
            trailing: Text('${d?.ticketPriceToday ?? 100} TRX/张'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              try {
                await state.dailyCheckin();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('打卡成功')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('今日打卡'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              try {
                await state.submitThankLetter(content: '感谢团队支持');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('感谢信已提交')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('提交感谢信'),
          ),
        ],
      ),
    );
  }

  Widget _block(String title, num rate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('完成率 ${rate.toStringAsFixed(0)}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (rate / 100).clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }
}
