import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/quota_model.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class QuotaCard extends StatelessWidget {
  final QuotaInfo? quotaInfo;
  final bool isAuthenticated;
  final VoidCallback? onLoginTap;
  final VoidCallback? onRefresh;

  const QuotaCard({
    super.key,
    required this.quotaInfo,
    required this.isAuthenticated,
    this.onLoginTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final info = quotaInfo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceCard,
            AppTheme.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt, color: AppTheme.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuthenticated ? 'User Quota' : 'Guest Daily Quota',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            isAuthenticated
                                ? '50 requests/day'
                                : '5 requests/day • Log in for 50',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isAuthenticated && onLoginTap != null)
                TextButton.icon(
                  onPressed: onLoginTap,
                  icon: const Icon(Icons.login, size: 16, color: AppTheme.accent),
                  label: const Text(
                    'Log In',
                    style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppTheme.textSecondary),
                  onPressed: onRefresh,
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (info != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${info.remainingQuota} remaining',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${info.usedQuotaToday} / ${info.dailyQuota} used',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearPercentIndicator(
              lineHeight: 8.0,
              percent: info.usagePercent,
              padding: EdgeInsets.zero,
              barRadius: const Radius.circular(4),
              backgroundColor: AppTheme.surfaceElevated,
              linearGradient: LinearGradient(
                colors: info.usagePercent > 0.8
                    ? [AppTheme.warning, AppTheme.error]
                    : [AppTheme.accent, AppTheme.primaryLight],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Resets at 00:00 UTC',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                Flexible(
                  child: Text(
                    'Reset in: ${info.timeUntilReset}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
