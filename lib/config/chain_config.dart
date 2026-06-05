/// 链配置（借鉴 pmsj wallet_core.CHAIN_CONFIG，仅客户端只读 RPC）
class ChainConfig {
  const ChainConfig({
    required this.id,
    required this.name,
    required this.decimals,
    required this.nodes,
    required this.addressPrefix,
  });

  final String id;
  final String name;
  final int decimals;
  final List<String> nodes;
  final String addressPrefix;

  static const tron = ChainConfig(
    id: 'TRON',
    name: '波场 TRX',
    decimals: 6,
    addressPrefix: 'T',
    nodes: [
      'https://api.trongrid.io',
      'https://rpc.trongrid.io',
    ],
  );

  static const bsc = ChainConfig(
    id: 'BSC',
    name: '币安智能链',
    decimals: 18,
    addressPrefix: '0x',
    nodes: [
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-rpc.publicnode.com',
    ],
  );

  static ChainConfig? byId(String id) {
    switch (id.toUpperCase()) {
      case 'TRON':
        return tron;
      case 'BSC':
        return bsc;
      default:
        return null;
    }
  }

  static List<ChainConfig> get supported => [tron, bsc];
}
