import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('帮助中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(title: Text('如何排单？'), subtitle: Text('排单 Tab → 选档位 → 支付 TRX')),
          ListTile(title: Text('如何买券？'), subtitle: Text('首页或购票页购买排单券')),
          ListTile(title: Text('节点配置'), subtitle: Text('我的 → 服务器配置')),
        ],
      ),
    );
  }
}
