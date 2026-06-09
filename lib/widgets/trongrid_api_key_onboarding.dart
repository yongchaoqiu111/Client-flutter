import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/pool_data_policy.dart';
import '../providers/app_state.dart';

/// TronGrid API Key 注册引导 + 填写（付款/验款/本地回放须配置）
class TronGridApiKeyOnboarding extends StatefulWidget {
  const TronGridApiKeyOnboarding({
    super.key,
    this.compact = false,
    this.reason,
    this.onConfigured,
  });

  final bool compact;
  final String? reason;
  final VoidCallback? onConfigured;

  @override
  State<TronGridApiKeyOnboarding> createState() => _TronGridApiKeyOnboardingState();
}

class _TronGridApiKeyOnboardingState extends State<TronGridApiKeyOnboarding> {
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppState state) async {
    final raw = _keyCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请粘贴 TronGrid API Key')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await state.setTronGridApiKey(raw);
      if (!mounted) return;
      widget.onConfigured?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key 已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildBanner(context);
    }
    return _buildFullGuide(context);
  }

  Widget _buildBanner(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2208),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text('TronGrid API Key', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.reason ??
                  '查看全队排单大盘无需 Key（读平台快照）。'
                  '付出场池、刷新本人链上验款、快照失败时本地回放，须配置个人 Key。',
              style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: () => context.push('/settings/trongrid-key'),
                  child: const Text('去配置 API Key'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showGuideDialog(context),
                  child: const Text('注册说明'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullGuide(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.vpn_key, size: 48, color: Colors.amber),
        const SizedBox(height: 16),
        Text(
          '配置 TronGrid API Key',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (widget.reason != null) ...[
          const SizedBox(height: 8),
          Text(widget.reason!, style: const TextStyle(color: Colors.orange)),
        ],
        const SizedBox(height: 12),
        const _RegistrationSteps(),
        const SizedBox(height: 16),
        TextField(
          controller: _keyCtrl,
          obscureText: _obscure,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'TRON-PRO-API-KEY',
            hintText: '粘贴 API Key',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : () => _save(state),
          child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('保存 Key'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('稍后配置'),
        ),
      ],
    );
  }

  static void _showGuideDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TronGrid 注册步骤'),
        content: const SingleChildScrollView(child: _RegistrationSteps()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/settings/trongrid-key');
            },
            child: const Text('去填写 Key'),
          ),
        ],
      ),
    );
  }
}

class _RegistrationSteps extends StatelessWidget {
  const _RegistrationSteps();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '何时需要 Key？',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          '• 不需要：看各档池状态、今日匹配、全队积压（读平台快照）\n'
          '• 需要：付出场池后验款、刷新本人链上状态、快照不可用时的本地回放',
          style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 14),
        const Text('注册步骤', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const _StepRow(n: '1', text: '浏览器打开 trongrid.io 并注册账号'),
        const _StepRow(n: '2', text: '登录后进入 Dashboard'),
        const _StepRow(n: '3', text: '点击 Create API Key，复制生成的 Key'),
        const _StepRow(n: '4', text: '回到本 App 粘贴并保存（每人独立 Key，避免公共限流）'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                PoolDataPolicy.trongridRegisterUrl,
                style: const TextStyle(fontSize: 12, color: Colors.cyan),
              ),
            ),
            IconButton(
              tooltip: '复制网址',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: PoolDataPolicy.trongridRegisterUrl),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制 trongrid.io 地址')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.text});

  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: Colors.amber.withOpacity(0.25),
            child: Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}

/// 排单 Tab 顶部：未配置 Key 时展示引导条
class TronGridApiKeyBanner extends StatelessWidget {
  const TronGridApiKeyBanner({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final hasKey = context.watch<AppState>().hasTronGridApiKey;
    if (hasKey) return const SizedBox.shrink();
    return TronGridApiKeyOnboarding(compact: true, reason: reason);
  }
}
