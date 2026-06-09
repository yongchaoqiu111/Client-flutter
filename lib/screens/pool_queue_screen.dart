import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/pool_rules_config.dart';
import '../models/pool_cycle_models.dart';
import '../providers/app_state.dart';
import '../utils/tron_address_util.dart';
import '../widgets/trongrid_api_key_gate.dart';
import '../widgets/trongrid_api_key_onboarding.dart';

/// 链上排单：平台快照看大盘；本人付款/验款须 TronGrid Key
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
  String? _snapshotMeta;

  Future<void> _refreshSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matcher = context.read<AppState>().createPoolMatcher();
      final result = await matcher.runMatcher();
      if (!mounted) return;
      setState(() {
        _pools = result.pools;
        _snapshotMeta = result.isRemoteSnapshot
            ? '平台快照${_shortHash(result.contentHash)}'
            : '本地 TronGrid 回放';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshChainVerify() async {
    final ok = await ensureTronGridApiKey(
      context,
      actionTitle: '刷新链上验款',
      message: '将用您的 TronGrid Key 拉取链上转账并重新验款，确认本人是否已付出场池。',
    );
    if (!ok || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matcher = context.read<AppState>().createPoolMatcher();
      final result = await matcher.runChainVerify();
      if (!mounted) return;
      setState(() {
        _pools = result.pools;
        _snapshotMeta = '链上验款（本地回放）';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshSnapshot();
    });
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshSnapshot,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSnapshot,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const TronGridApiKeyBanner(),
            if (_snapshotMeta != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '数据来源：$_snapshotMeta',
                  style: const TextStyle(fontSize: 11, color: Colors.cyan),
                ),
              ),
            _infoCard(matchCtx),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.orange)),
              ),
            if (_loading && _pools == null)
              const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
            ...kPoolTiers.map(_tierSection),
            if (_pools != null && me != null) _myStatus(context, me),
            const SizedBox(height: 24),
            const Text(
              '规则 v4：支付进场 → 打款池；本档池满且满 15 天后，每日 08:00 匹配溢出；'
              'pay_in 付出场池 → 主网验款 → 收款池。付款钱包即排单身份。'
              '看队读平台快照；付钱、验款认链上 tx（须个人 TronGrid Key）。',
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
              '付 ${tier.ticketPriceTrx.toStringAsFixed(0)} TRX 进场 → 计 ${tier.poolCreditTrx.toStringAsFixed(0)} 入池',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '排单 ${tier.poolCreditTrx.toStringAsFixed(0)} → 出场 ${tier.exitAmountTrx.toStringAsFixed(0)} TRX'
              '（收益 ${(tier.profitRate * 100).toStringAsFixed(0)}%）',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
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
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tier.purchaseAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('买券地址已复制')),
                    );
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

  Widget _myStatus(BuildContext context, String me) {
    final state = context.watch<AppState>();

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
            const Text(
              '以下状态来自平台快照；付出场池后请用「刷新链上验款」核对链上 tx。',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
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
              Row(
                children: [
                  FilledButton(
                    onPressed: _loading ? null : () => _payExitPool(context, state, myPay.first),
                    child: const Text('立即付出场池'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _refreshChainVerify,
                    child: const Text('刷新链上验款'),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '付款后须用 TronGrid Key 验款；快照仅用于展示，不认链上到账。',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
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

  static String _shortHash(String? hash) {
    if (hash == null || hash.isEmpty) return '';
    final n = hash.length < 12 ? hash.length : 12;
    return ' · ${hash.substring(0, n)}…';
  }

  static String _fmtDeadline(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _payExitPool(
    BuildContext context,
    AppState state,
    SplitAssignment assignment,
  ) async {
    final amount = assignment.amountTrx;
    final to = assignment.collectorAddress;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认付出场池'),
        content: Text(
          '将从您的钱包转出 ${amount.toStringAsFixed(0)} TRX\n'
          '至出场池：$to\n\n'
          '须由当前付款地址发出（谁付谁收）。付清后请配置 TronGrid Key 并点「刷新链上验款」。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认付款')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final tx = await state.payExitPoolAssignment(
        toAddress: to,
        amountTrx: amount,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已提交打款${state.demoPayments ? '（演示）' : ''}。'
            '请配置 TronGrid Key 后点「刷新链上验款」。\n$tx',
          ),
        ),
      );
      if (state.hasTronGridApiKey) {
        await _refreshChainVerify();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打款失败: $e')));
    }
  }
}
