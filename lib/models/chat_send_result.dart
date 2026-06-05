class ChatSendResult {
  const ChatSendResult({required this.ok, this.reason});

  final bool ok;
  final String? reason;

  factory ChatSendResult.success() => const ChatSendResult(ok: true);

  factory ChatSendResult.fail(String reason) => ChatSendResult(ok: false, reason: reason);
}
