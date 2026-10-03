import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/quota_model.dart';
import 'app_logo_3d.dart';

class TopUtilityBar extends StatelessWidget {
  final QuotaInfo? quotaInfo;
  final int serverCheckToken;
  final VoidCallback onServerTap;
  final VoidCallback onQuotaTap;
  final VoidCallback onQuotaResetElapsed;

  const TopUtilityBar({
    super.key,
    required this.quotaInfo,
    required this.serverCheckToken,
    required this.onServerTap,
    required this.onQuotaTap,
    required this.onQuotaResetElapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Flexible(
            child: _BrandCluster(
              checkToken: serverCheckToken,
              onTap: onServerTap,
            ),
          ),
          const SizedBox(width: 8),
          QuotaBadge(
            quotaInfo: quotaInfo,
            onTap: onQuotaTap,
            onResetElapsed: onQuotaResetElapsed,
          ),
        ],
      ),
    );
  }
}

class _BrandCluster extends StatelessWidget {
  final int checkToken;
  final VoidCallback onTap;

  const _BrandCluster({required this.checkToken, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ServerStatusProbe(
      checkToken: checkToken,
      builder: (context, status) {
        return Tooltip(
          message: 'Server ${status.label}. Tap to configure.',
          child: Semantics(
            button: true,
            label: 'VanishLab. Server ${status.label}. Open server settings.',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo3D(size: AppLogoSize.small, showGlow: false),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'VanishLab',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headline.copyWith(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum ServerStatus {
  checking('checking', AppTheme.textMuted),
  online('online', AppTheme.success),
  degraded('degraded', AppTheme.warning),
  offline('unreachable', AppTheme.error);

  final String label;
  final Color color;
  const ServerStatus(this.label, this.color);
}

class ServerStatusProbe extends StatefulWidget {
  final int checkToken;
  final Widget Function(BuildContext, ServerStatus) builder;

  const ServerStatusProbe({super.key, required this.checkToken, required this.builder});

  @override
  State<ServerStatusProbe> createState() => _ServerStatusProbeState();
}

class _ServerStatusProbeState extends State<ServerStatusProbe> {
  static const _interval = Duration(seconds: 30);
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  ServerStatus _status = ServerStatus.checking;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  @override
  void didUpdateWidget(covariant ServerStatusProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkToken != widget.checkToken) {
      setState(() => _status = ServerStatus.checking);
      _check();
    }
  }

  Future<void> _check() async {
    ServerStatus next;
    try {
      final base = Uri.parse(sl<ApiClient>().effectiveNetworkBaseUrl);
      final healthUri = base.replace(path: '/health', query: null);
      final res = await _dio.getUri<Map<String, dynamic>>(healthUri);
      next = res.data?['status'] == 'healthy' ? ServerStatus.online : ServerStatus.degraded;
    } catch (_) {
      next = ServerStatus.offline;
    }
    if (mounted && next != _status) setState(() => _status = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _status);
}

class QuotaBadge extends StatefulWidget {
  final QuotaInfo? quotaInfo;
  final VoidCallback onTap;
  final VoidCallback onResetElapsed;

  const QuotaBadge({
    super.key,
    required this.quotaInfo,
    required this.onTap,
    required this.onResetElapsed,
  });

  @override
  State<QuotaBadge> createState() => _QuotaBadgeState();
}

class _QuotaBadgeState extends State<QuotaBadge> {
  Timer? _ticker;
  bool _resetReported = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant QuotaBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotaInfo?.resetAt != widget.quotaInfo?.resetAt) {
      _resetReported = false;
    }
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _remaining();
    if (remaining != null && remaining <= Duration.zero && !_resetReported) {
      _resetReported = true;
      widget.onResetElapsed();
    }
    setState(() {});
  }

  Duration? _remaining() {
    final resetAt = widget.quotaInfo?.resetAt;
    if (resetAt == null) return null;
    return resetAt.difference(DateTime.now().toUtc());
  }

  static String formatCountdown(Duration? d) {
    if (d == null) return '--:--:--';
    if (d.isNegative) return '00:00:00';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.quotaInfo;
    final countdown = formatCountdown(_remaining());
    final exhausted = info != null && info.remainingQuota <= 0;
    final countText = info == null ? '-- / --' : '${info.remainingQuota} / ${info.dailyQuota}';

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: info == null
          ? 'Quota unavailable. Open account.'
          : '${info.remainingQuota} of ${info.dailyQuota} requests left today. '
              'Resets in $countdown. Open account.',
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: countText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: exhausted ? AppTheme.error : AppTheme.textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text: ' left',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ]),
                    style: AppTheme.body.copyWith(
                      fontSize: 12,
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppTheme.border,
                  ),
                  Text(countdown, style: AppTheme.readout),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
