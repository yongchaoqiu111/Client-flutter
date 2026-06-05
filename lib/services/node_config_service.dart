import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/gateway_presets.dart';
import '../models/node_config.dart';

class NodeConfigService {
  static const _currentKey = 'mmm_current_node';
  static const _nodesKey = 'mmm_nodes';

  static Future<NodeConfig> loadCurrentNode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentKey);
    if (raw != null) {
      return NodeConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    return NodeConfig.defaultGateway();
  }

  static Future<void> saveCurrentNode(NodeConfig node) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, jsonEncode(node.toJson()));
  }

  static Future<List<NodeConfig>> loadNodes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_nodesKey);
    if (raw == null) {
      return GatewayPresets.defaultNodes();
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => NodeConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveNodes(List<NodeConfig> nodes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _nodesKey,
      jsonEncode(nodes.map((n) => n.toJson()).toList()),
    );
  }
}
