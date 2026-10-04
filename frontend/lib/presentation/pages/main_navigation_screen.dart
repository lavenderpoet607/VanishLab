import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/di/injection.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../widgets/adaptive_navigation.dart';
import '../widgets/top_utility_bar.dart';
import 'auth_dialog.dart';
import 'downloader_page.dart';
import 'inpaint_page.dart';
import 'task_result_page.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1;
  int _serverCheckToken = 0;

  void _onNavigateTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showBackendSettingsDialog() {
    final apiClient = sl<ApiClient>();
    final controller = TextEditingController(text: apiClient.currentBaseUrl);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Text('Backend API Server Config'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set the VanishLab FastAPI backend URL. Media downloads and outputs will resolve to your chosen server host:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Base API URL',
                    hintText: 'http://localhost:8000/api/v1',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      backgroundColor: AppTheme.surfaceRaised,
                      label: const Text('localhost:8000', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() {
                        controller.text = 'http://localhost:8000/api/v1';
                      }),
                    ),
                    ActionChip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      backgroundColor: AppTheme.surfaceRaised,
                      label: const Text('127.0.0.1:8000', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() {
                        controller.text = 'http://127.0.0.1:8000/api/v1';
                      }),
                    ),
                    ActionChip(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      backgroundColor: AppTheme.surfaceRaised,
                      label: const Text('Android (10.0.2.2)', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() {
                        controller.text = 'http://10.0.2.2:8000/api/v1';
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newUrl = controller.text.trim();
                if (newUrl.isNotEmpty) {
                  apiClient.updateBaseUrl(newUrl);
                  context.read<AuthBloc>().add(CheckAuthStatusEvent());
                  setState(() {
                    _serverCheckToken++;
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Server updated: $newUrl (outputs mapped to this host)'),
                      backgroundColor: AppTheme.surfaceRaised,
                    ),
                  );
                }
              },
              child: const Text('Save & Reconnect'),
            ),
          ],
        ),
      ),
    );
  }

  void _onQuotaTap(AuthState authState) {
    if (!authState.isAuthenticated) {
      AuthDialog.show(context);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: const Text('Account & Quota'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in as:',
                style: AppTheme.label,
              ),
              const SizedBox(height: 2),
              Text(
                authState.user?.email ?? 'User',
                style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                'DAILY QUOTA',
                style: AppTheme.label,
              ),
              const SizedBox(height: 4),
              Text(
                '${authState.quotaInfo?.remainingQuota ?? 0} remaining of ${authState.quotaInfo?.dailyQuota ?? 50} requests',
                style: AppTheme.body.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Resets in: ${authState.quotaInfo?.timeUntilReset ?? "--:--:--"} (UTC 00:00)',
                style: AppTheme.readout,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                context.read<AuthBloc>().add(ResetQuotaEvent());
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quota has been reset to 50 requests.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.accent),
              label: const Text('Reset Quota', style: TextStyle(color: AppTheme.accent)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<AuthBloc>().add(LogoutEvent());
              },
              icon: const Icon(Icons.logout, size: 16, color: AppTheme.error),
              label: const Text('Log Out', style: TextStyle(color: AppTheme.error)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        return AdaptiveNavigationScaffold(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onNavigateTab,
          trailingHeader: IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Server Settings',
            onPressed: _showBackendSettingsDialog,
          ),
          body: SafeArea(
            child: Column(
              children: [

                TopUtilityBar(
                  quotaInfo: authState.quotaInfo,
                  serverCheckToken: _serverCheckToken,
                  onServerTap: _showBackendSettingsDialog,
                  onQuotaTap: () => _onQuotaTap(authState),
                  onQuotaResetElapsed: () => context.read<AuthBloc>().add(RefreshQuotaEvent()),
                ),

                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      InpaintPage(onNavigateTab: _onNavigateTab),
                      DownloaderPage(onNavigateTab: _onNavigateTab),
                      const TaskResultPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
