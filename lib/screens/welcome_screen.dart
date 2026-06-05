import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.water_drop, size: 72, color: AppTheme.accent),
              const SizedBox(height: 16),
              Text('MMM 蓄水池互助', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                '本地钱包 · Raft 共识 · 无服务器私钥',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/wallet-setup'),
                child: const Text('创建钱包'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/wallet-setup'),
                child: const Text('导入钱包'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
