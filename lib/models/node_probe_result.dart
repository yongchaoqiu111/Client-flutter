class NodeProbeResult {
  const NodeProbeResult({required this.online, this.latencyMs});

  final bool online;
  final int? latencyMs;
}
