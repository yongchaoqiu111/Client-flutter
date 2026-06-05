import 'package:go_router/go_router.dart';

import '../screens/assessment_screen.dart';
import '../screens/bootstrap_screen.dart';
import '../screens/chat_hall_screen.dart';
import '../screens/help_screen.dart';
import '../screens/live_room_screen.dart';
import '../screens/mnemonic_backup_screen.dart';
import '../screens/my_orders_screen.dart';
import '../screens/node_config_screen.dart';
import '../screens/node_pick_screen.dart';
import '../screens/order_confirm_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/payment_address_screen.dart';
import '../screens/performance_screen.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/rewards_screen.dart';
import '../screens/security_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/ticket_purchase_screen.dart';
import '../models/queue_tier.dart';
import '../screens/wallet_management_screen.dart';
import '../screens/wallet_setup_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/pin_service.dart';
import '../services/wallet_service.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/bootstrap',
    routes: [
      GoRoute(path: '/bootstrap', builder: (_, __) => const BootstrapScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/wallet-setup', builder: (_, __) => const WalletSetupScreen()),
      GoRoute(
        path: '/mnemonic-backup',
        builder: (_, state) => MnemonicBackupScreen(
          mnemonic: state.extra as String? ?? '',
        ),
      ),
      GoRoute(path: '/pin-setup', builder: (_, __) => const PinSetupScreen()),
      GoRoute(path: '/app', builder: (_, __) => const ShellScreen()),
      GoRoute(
        path: '/order/confirm',
        builder: (_, state) => OrderConfirmScreen(tier: state.extra! as QueueTier),
      ),
      GoRoute(path: '/order/my', builder: (_, __) => const MyOrdersScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/ticket', builder: (_, __) => const TicketPurchaseScreen()),
      GoRoute(path: '/me/wallet', builder: (_, __) => const WalletManagementScreen()),
      GoRoute(path: '/me/security', builder: (_, __) => const SecurityScreen()),
      GoRoute(path: '/me/payment-address', builder: (_, __) => const PaymentAddressScreen()),
      GoRoute(path: '/me/nodes', builder: (_, __) => const NodeConfigScreen()),
      GoRoute(path: '/me/nodes/pick', builder: (_, __) => const NodePickScreen()),
      GoRoute(path: '/network/assessment', builder: (_, __) => const AssessmentScreen()),
      GoRoute(
        path: '/podcast/room/:id',
        builder: (_, state) => LiveRoomScreen(roomId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/chat', builder: (_, __) => const ChatHallScreen()),
      GoRoute(path: '/me/performance', builder: (_, __) => const PerformanceScreen()),
      GoRoute(path: '/me/rewards', builder: (_, __) => const RewardsScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}

/// 启动后根据状态跳转
Future<String> resolveStartupRoute() async {
  final wallet = await WalletService.getActiveAccount();
  if (wallet == null) return '/welcome';
  final hasPin = await PinService.hasPin();
  if (!hasPin) return '/pin-setup';
  return '/app';
}
