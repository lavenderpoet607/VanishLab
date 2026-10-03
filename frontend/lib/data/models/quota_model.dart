class QuotaInfo {
  final int dailyQuota;
  final int usedQuotaToday;
  final int remainingQuota;
  final DateTime? resetAt;

  QuotaInfo({
    required this.dailyQuota,
    required this.usedQuotaToday,
    required this.remainingQuota,
    this.resetAt,
  });

  factory QuotaInfo.fromJson(Map<String, dynamic> json) {
    return QuotaInfo(
      dailyQuota: json['daily_quota'] as int? ?? 5,
      usedQuotaToday: json['used_quota_today'] as int? ?? 0,
      remainingQuota: json['remaining_quota'] as int? ?? 5,
      resetAt: json['reset_at'] != null ? DateTime.tryParse(json['reset_at']) : null,
    );
  }

  double get usagePercent {
    if (dailyQuota <= 0) return 0.0;
    return (usedQuotaToday / dailyQuota).clamp(0.0, 1.0);
  }

  String get timeUntilReset {
    if (resetAt == null) return '--:--:--';
    final now = DateTime.now().toUtc();
    final diff = resetAt!.difference(now);
    if (diff.isNegative) return 'Resetting...';
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
