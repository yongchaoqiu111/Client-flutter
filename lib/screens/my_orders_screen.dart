import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/queue_order.dart';
import '../providers/app_state.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _filter = 'all';

  static const _tabs = [
    ('all', '全部'),
    ('queued', '排队中'),
    ('paying', '支付中'),
    ('earning', '收益中'),
    ('done', '已完成'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.orders.where((o) {
      if (_filter == 'all') return true;
      return o.filterKey == _filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('我的订单')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _tabs.map((t) {
                final selected = _filter == t.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = t.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.loadOrders,
              child: list.isEmpty
                  ? const ListTile(title: Text('暂无订单'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _tile(context, list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, QueueOrder o) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text('${o.tierName.isNotEmpty ? o.tierName : "排单"} ${o.amount} TRX'),
        subtitle: Text('${o.statusLabel} · 券 ${o.ticketCost} 张'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/order/${o.id}'),
      ),
    );
  }
}
