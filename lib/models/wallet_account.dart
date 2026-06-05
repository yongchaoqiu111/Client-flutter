/// 本地钱包账户（对标 pmsj wallet_storage，无私钥上云）
class WalletAccount {
  WalletAccount({
    required this.address,
    required this.chain,
    this.label,
    this.createdAt,
  });

  final String address;
  final String chain; // TRON | BSC
  final String? label;
  final int? createdAt;

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      address: json['address'] as String,
      chain: json['chain'] as String? ?? 'TRON',
      label: json['label'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'chain': chain,
        if (label != null) 'label': label,
        if (createdAt != null) 'createdAt': createdAt,
      };

  String get shortAddress =>
      address.length > 12 ? '${address.substring(0, 8)}...${address.substring(address.length - 4)}' : address;
}
