import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/pin_service.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('安全设置')),
      body: ListView(
        children: [
          FutureBuilder<bool>(
            future: PinService.hasPin(),
            builder: (_, snap) {
              final set = snap.data == true;
              return ListTile(
                title: const Text('二级密码（支付密码）'),
                subtitle: Text(set ? '已设置' : '未设置'),
                trailing: TextButton(
                  onPressed: () => context.push('/pin-setup'),
                  child: Text(set ? '修改' : '设置'),
                ),
              );
            },
          ),
          const ListTile(
            title: Text('生物识别'),
            subtitle: Text('待接入'),
            trailing: Icon(Icons.fingerprint),
          ),
        ],
      ),
    );
  }
}
