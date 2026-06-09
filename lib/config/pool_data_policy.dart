/// 排单数据来源与 TronGrid API Key 门禁（一期 Vercel 快照 / 二期 WSS）
///
/// | 功能 | 数据来源 | 需要用户 TronGrid Key |
/// |------|----------|----------------------|
/// | 看各档池满不满、今日匹配、全队积压 | 平台快照（Vercel / 后期 WSS） | 否 |
/// | 看「我的排单」列表（快照筛本人地址） | 同上 | 否 |
/// | 快照失败时本地全量回放 | TronGrid 拉公共地址 | 是 |
/// | 刷新「本人是否已付出场池」 | TronGrid 查本人相关 tx | 是 |
/// | 立即付出场池（链上广播） | 钱包 + 可选 TronGrid 查资源 | 是（验款/刷新） |
///
/// 原则：**快照用于看队；付钱、收钱认链，用户 Key 抽检本人 tx。**
class PoolDataPolicy {
  PoolDataPolicy._();

  static const trongridRegisterUrl = 'https://www.trongrid.io/';
  static const trongridDashboardHint = 'https://www.trongrid.io/ → 注册 → Dashboard → Create API Key';

  /// 付款、验款、本地回放等须个人 Key 的操作
  static bool requiresUserApiKeyFor(String action) {
    switch (action) {
      case 'pay_exit':
      case 'verify_chain':
      case 'local_replay':
      case 'clear_cache_refresh':
        return true;
      case 'view_pool':
      case 'view_my_status':
      case 'refresh_snapshot':
        return false;
      default:
        return false;
    }
  }
}
