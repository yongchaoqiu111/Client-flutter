import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:provider/provider.dart';



import '../config/pool_rules_config.dart';

import '../models/pool_cycle_models.dart';

import '../providers/app_state.dart';

import '../services/pool_matcher_service.dart';
import '../utils/tron_address_util.dart';



/// 无服务器排单：花 ticketPrice 买券 → 计 poolCredit 入池；拆分匹配出场

class PoolQueueScreen extends StatefulWidget {

  const PoolQueueScreen({super.key});



  @override

  State<PoolQueueScreen> createState() => _PoolQueueScreenState();

}



class _PoolQueueScreenState extends State<PoolQueueScreen> {

  bool _loading = false;

  String? _error;

  Map<String, PoolCycleResult>? _pools;

  PoolTierConfig? _selectedTier;

  final PoolMatcherService _matcher = PoolMatcherService();



  Future<void> _refresh() async {

    setState(() {

      _loading = true;

      _error = null;

    });

    try {

      final pools = await _matcher.runFullMatcher();

      if (!mounted) return;

      setState(() => _pools = pools);

    } catch (e) {

      if (mounted) setState(() => _error = '$e');

    } finally {

      if (mounted) setState(() => _loading = false);

    }

  }



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());

  }



  @override

  Widget build(BuildContext context) {

    final state = context.watch<AppState>();

    final me = state.address;

    final matchCtx = PoolRulesConfig.dailyMatchContext();



    return Scaffold(

      appBar: AppBar(

        title: const Text('链上排单（买券即排队）'),

        actions: [

          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refresh),

        ],

      ),

      body: RefreshIndicator(

        onRefresh: _refresh,

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            _infoCard(matchCtx),

            if (_error != null)

              Padding(

                padding: const EdgeInsets.only(bottom: 12),

                child: Text(_error!, style: const TextStyle(color: Colors.orange)),

              ),

            if (_loading && _pools == null)

              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),

            ...kPoolTiers.map((tier) => _tierSection(tier)),

            if (_pools != null && me != null) _myStatus(me),

            const SizedBox(height: 24),

            const Text(
              '规则 v4：买券 → 打款池排队；池满 30 万且满 15 天后，每日 08:00 将溢出额度'
              '生成 pay_in 任务付至出场池；主网验款通过 → 收款池；收款池按 3900 整数 recv_out，'
              '零头 recv_partial 或打排单券地址。点「刷新链上状态」仅查 TronGrid，无需自报 anchor。',
              style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
            ),

          ],

        ),

      ),

    );

  }



  Widget _infoCard(DailyMatchContext matchCtx) {
    final next = DateTime.fromMillisecondsSinceEpoch(matchCtx.nextMatchAtMs, isUtc: true).toLocal();
    final nextLabel =
        '${next.month}/${next.day} ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('方案 A · 本日匹配 ${matchCtx.matchDayId}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              '每日 ${matchCtx.beijingMatchHour}:00（北京）匹配一次 · 下次 $nextLabel',
              style: const TextStyle(fontSize: 12, color: Colors.cyan),
            ),
            const SizedBox(height: 4),
            Text(
              '进场期 ${PoolRulesConfig.entryPeriodDays} 天 · 出场期 ${PoolRulesConfig.exitPeriodDays} 天 · '
              '最多 ${PoolRulesConfig.maxSplitsPerPayer} 笔拆分打款',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }



  Widget _tierSection(PoolTierConfig tier) {

    final result = _pools?[tier.id];

    final fill = result?.fill;

    final isSelected = _selectedTier?.id == tier.id;



    return Card(

      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(tier.name, style: Theme.of(context).textTheme.titleMedium),

            Text(

              '付 ${tier.ticketPriceTrx.toStringAsFixed(0)} TRX 买券 → 计 ${tier.poolCreditTrx.toStringAsFixed(0)} 入池',

              style: const TextStyle(fontSize: 12),

            ),

            Text('出场应收 ${tier.exitAmountTrx.toStringAsFixed(0)} TRX', style: const TextStyle(fontSize: 12, color: Colors.white54)),

            const SizedBox(height: 8),

            SelectableText('买券地址：${tier.purchaseAddress}', style: const TextStyle(fontSize: 11)),
            SelectableText('出场池地址：${tier.exitPoolAddress}', style: const TextStyle(fontSize: 11, color: Colors.cyan)),

            if (fill != null) ...[

              const SizedBox(height: 8),

              Text(

                '池 ${fill.totalPoolCreditTrx.toStringAsFixed(0)} / ${fill.targetTrx.toStringAsFixed(0)}'
                '${(fill.overflowPoolCreditTrx ?? 0) > 0 ? ' · 今日可匹配溢出 ${fill.overflowPoolCreditTrx!.toStringAsFixed(0)}' : ''} · '

                '${fill.entryCount} 笔 · 已积累 ${fill.daysSinceFirstEntry} 天',

                style: const TextStyle(fontSize: 12),

              ),

              Text(
                fill.canMatch
                    ? '✓ 今日可匹配（池满且满 ${PoolRulesConfig.entryPeriodDays} 天）'
                    : !fill.isFull
                        ? '池未满 ${fill.targetTrx.toStringAsFixed(0)}，今日不匹配'
                        : '池已消耗，今日不匹配（需重新积满）',
                style: TextStyle(fontSize: 12, color: fill.canMatch ? Colors.greenAccent : Colors.orange),
              ),
              if ((fill.consumedPoolCreditTrx ?? 0) > 0)
                Text(
                  '历史已匹配消耗 ${fill.consumedPoolCreditTrx!.toStringAsFixed(0)} · 剩余 ${fill.totalPoolCreditTrx.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              if (result!.payAssignments.isNotEmpty || result.recvAssignments.isNotEmpty)
                Text(
                  '本日溢出 ${result.overflowPoolCreditTrx.toStringAsFixed(0)} → '
                  'pay_in ${result.payAssignments.length} 笔 · recv_out ${result.recvAssignments.length} 笔 · '
                  '收款池 ${result.recvPoolCount} 人',
                  style: const TextStyle(fontSize: 11, color: Colors.cyan),
                ),
              if (result.remainderToReceiverTrx > 0)
                Text(
                  '零头 ${result.remainderToReceiverTrx.toStringAsFixed(0)} 排给下一位收款'
                  '（凑满 3900 明日继续）',
                  style: const TextStyle(fontSize: 11, color: Colors.amber),
                ),
              if (result.ticketRemainderTrx > 0)
                Text(
                  '零头 ${result.ticketRemainderTrx.toStringAsFixed(0)} 打排单券地址',
                  style: const TextStyle(fontSize: 11, color: Colors.amber),
                ),

            ],

            const SizedBox(height: 10),

            Row(

              children: [

                TextButton(

                  onPressed: () {

                    Clipboard.setData(ClipboardData(text: tier.purchaseAddress));

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('买券地址已复制')));

                  },

                  child: const Text('复制买券地址'),

                ),

                FilledButton(

                  onPressed: () => setState(() => _selectedTier = tier),

                  child: Text(isSelected ? '已选此档' : '选此档排单'),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }



  Widget _myStatus(String me) {

    PoolCycleResult? mine;

    PoolEntry? myEntry;

    final myPay = <SplitAssignment>[];
    final myRecv = <SplitAssignment>[];
    final myTicketSurplus = <TicketSurplusAssignment>[];

    for (final p in _pools!.values) {
      for (final e in p.entries) {
        if (TronAddressUtil.equal(e.payer, me) && e.status != 'blocked') myEntry = e;
      }
      for (final a in p.payAssignments) {
        if (TronAddressUtil.equal(a.payer, me)) myPay.add(a);
      }
      for (final a in p.recvAssignments) {
        if (TronAddressUtil.equal(a.beneficiary, me)) myRecv.add(a);
      }
      for (final t in p.ticketSurplusAssignments) {
        if (TronAddressUtil.equal(t.payer, me)) myTicketSurplus.add(t);
      }
      if (myEntry != null || myPay.isNotEmpty || myRecv.isNotEmpty || myTicketSurplus.isNotEmpty) {
        mine = p;
        break;
      }
    }



    if (mine == null) {

      return const Card(

        child: Padding(

          padding: EdgeInsets.all(14),

          child: Text('您尚未在本日快照内检测到买券进场记录'),

        ),

      );

    }



    return Card(

      color: const Color(0xFF1A2744),

      child: Padding(

        padding: const EdgeInsets.all(14),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text('我的排单', style: TextStyle(fontWeight: FontWeight.w600)),

            if (myEntry != null)
              Text(
                '状态：${_statusLabel(myEntry.status)} · 队列 #${myEntry.queueIndex}',
                style: const TextStyle(fontSize: 12),
              ),

            if (myRecv.isNotEmpty) ...[

              const SizedBox(height: 8),

              Text(

                '应收出场 ${myRecv.first.exitAmountTrx.toStringAsFixed(0)} TRX · '

                '收款地址 ${myRecv.first.collectorAddress}',

                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),

              ),

            ],

            if (myPay.isNotEmpty) ...[

              const SizedBox(height: 8),

              const Text('我的出场打款（pay_in → 出场池）', style: TextStyle(fontWeight: FontWeight.w500)),
              ...myPay.map((a) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '付 ${a.amountTrx.toStringAsFixed(0)} TRX 至出场池'
                          '${a.deadlineMs > 0 ? ' · 截止 ${_fmtDeadline(a.deadlineMs)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        SelectableText('出场池：${a.collectorAddress}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  )),

              const SizedBox(height: 8),

              OutlinedButton(

                onPressed: () {

                  ScaffoldMessenger.of(context).showSnackBar(

                    const SnackBar(

                      content: Text('付清出场池任务后点「刷新链上状态」→ 自动查主网出场池入账'),

                    ),

                  );

                },

                child: const Text('刷新链上状态'),

              ),

            ],

            if (myTicketSurplus.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('多余额度 → 排单券地址', style: TextStyle(fontSize: 12, color: Colors.amber)),
              ...myTicketSurplus.map((t) => SelectableText(
                    '付 ${t.amountTrx.toStringAsFixed(0)} TRX 至 ${t.collectorAddress}',
                    style: const TextStyle(fontSize: 11),
                  )),
            ],

          ],

        ),

      ),

    );

  }

  static String _statusLabel(String status) {
    const labels = {
      'pay_queued': '打款池排队',
      'pay_pending': '待付出场池',
      'pay_expired': '出场打款超时',
      'recv_queued': '收款池排队',
      'recv_partial': '收款零头待凑满',
      'recv_pending': '待收出场款',
      'done': '已完成',
      'blocked': '已屏蔽',
      'consumed': '已消耗',
    };
    return labels[status] ?? status;
  }

  static String _fmtDeadline(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

}


