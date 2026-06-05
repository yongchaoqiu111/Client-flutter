import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/pin_dialog.dart';

class TicketPurchaseScreen extends StatefulWidget {
  const TicketPurchaseScreen({super.key});

  @override
  State<TicketPurchaseScreen> createState() => _TicketPurchaseScreenState();
}

class _TicketPurchaseScreenState extends State<TicketPurchaseScreen> {
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadTicketQuote();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final quote = state.ticketQuote;

    return Scaffold(
      appBar: AppBar(title: const Text('购买排单券')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('基准价 ${quote?['basePrice'] ?? 100} TRX/张'),
                  Text('本次应付 ${quote?['payAmount'] ?? '—'} TRX（随机尾数）'),
                  Text('收款: ${quote?['treasury'] ?? '—'}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              const Text('购买数量'),
              const Spacer(),
              IconButton(onPressed: () => setState(() => _qty = (_qty - 1).clamp(1, 999)), icon: const Icon(Icons.remove)),
              Text('$_qty'),
              IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add)),
            ],
          ),
          FilledButton(
            onPressed: () async {
              if (!await showPayPinDialog(context)) return;
              await state.buyTickets(_qty);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('购票成功（已记账）')));
            },
            child: const Text('确认购买'),
          ),
        ],
      ),
    );
  }
}
