import 'package:flutter/material.dart';

import '../widgets/trongrid_api_key_onboarding.dart';

/// 系统设置 · TronGrid API Key 注册与填写
class TronGridApiKeyScreen extends StatelessWidget {
  const TronGridApiKeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TronGrid API Key')),
      body: const TronGridApiKeyOnboarding(),
    );
  }
}
