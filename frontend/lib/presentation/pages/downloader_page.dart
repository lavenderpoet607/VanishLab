import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/downloader_models.dart';
import '../../data/models/task_models.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/downloader/downloader_bloc.dart';
import '../blocs/downloader/downloader_event.dart';
import '../blocs/downloader/downloader_state.dart';
import '../blocs/task_tracker/task_tracker_bloc.dart';
import '../blocs/task_tracker/task_tracker_event.dart';
import '../blocs/task_tracker/task_tracker_state.dart';
import '../widgets/download_result_panel.dart';
import '../widgets/segmented_selector.dart';

class DownloaderPage extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DownloaderPage({super.key, required this.onNavigateTab});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();

  bool _extractAudioOnly = false;
  bool _cropWatermarkBars = false;
  String? _activeTaskId;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
      _formKey.currentState?.validate();
    }
  }

  void _submitDownload() {
    if (!_formKey.currentState!.validate()) return;

    final request = DownloaderRequest(
      url: _urlController.text.trim(),
      extractAudioOnly: _extractAudioOnly,
      cropWatermarkBars: _cropWatermarkBars,
      maxResolution: '1080p',
    );

    context.read<DownloaderBloc>().add(SubmitDownloaderJobEvent(request));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<DownloaderBloc, DownloaderState>(
          listener: (context, state) {
            if (state.status == DownloaderStatus.success && state.taskId != null) {
              setState(() {
                _activeTaskId = state.taskId;
              });
              context.read<AuthBloc>().add(RefreshQuotaEvent());
              context.read<TaskTrackerBloc>().add(StartTrackingTaskEvent(state.taskId!));
            } else if (state.status == DownloaderStatus.error && state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppTheme.surfaceRaised,
                ),
              );
            }
          },
        ),
      ],
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                _buildExtractionHubCard(),

                const SizedBox(height: 16),

                _buildResultSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractionHubCard() {
    return BlocBuilder<DownloaderBloc, DownloaderState>(
      builder: (context, dlState) {
        final isLoading = dlState.status == DownloaderStatus.submitting;

        return SlateCard(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                const SectionLabel('URL Extraction Hub'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _urlController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.url,
                  style: AppTheme.body,
                  decoration: InputDecoration(
                    hintText: 'Paste media link (TikTok, IG, YT)...',
                    prefixIcon: const Icon(Icons.link, size: 20, color: AppTheme.textMuted),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton(
                        onPressed: isLoading ? null : _pasteFromClipboard,
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.surfaceRaised,
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(48, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                        ),
                        child: const Text(
                          'Paste',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please paste or enter a media URL';
                    }
                    final trimmed = val.trim();
                    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                      return 'URL must start with http:// or https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                SegmentedSelector<bool>(
                  segments: const [
                    (false, 'Video (MP4)'),
                    (true, 'Audio (MP3)'),
                  ],
                  selected: _extractAudioOnly,
                  onChanged: isLoading ? null : (val) => setState(() => _extractAudioOnly = val),
                ),
                const SizedBox(height: 14),

                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceInset,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Crop black bars / watermark strips',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body.copyWith(fontSize: 13),
                        ),
                      ),
                      Switch(
                        value: _cropWatermarkBars,
                        onChanged: isLoading ? null : (val) => setState(() => _cropWatermarkBars = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.onAccent,
                      disabledBackgroundColor: AppTheme.surfaceRaised,
                      disabledForegroundColor: AppTheme.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppTheme.onAccent,
                            ),
                          )
                        : const Text(
                            'Download Clean Media',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultSection() {
    return BlocBuilder<TaskTrackerBloc, TaskTrackerState>(
      builder: (context, trackerState) {
        final currentTask = trackerState.task;

        if (_activeTaskId != null) {
          if (trackerState.status == TaskTrackerStatus.failed) {
            return JobFailedCard(
              title: 'Extraction Job Failed',
              message: trackerState.errorMessage ?? 'Media stream could not be extracted cleanly.',
              onRetry: _submitDownload,
              onDismiss: () {
                setState(() => _activeTaskId = null);
                context.read<TaskTrackerBloc>().add(StopTrackingTaskEvent());
              },
            );
          }

          if (currentTask != null) {
            if (currentTask.status == TaskStatus.completed && currentTask.primaryOutput != null) {
              return ProcessedResultCard(task: currentTask);
            } else {
              return JobProgressCard(
                taskId: currentTask.taskId,
                task: currentTask,
                onStop: () {
                  setState(() => _activeTaskId = null);
                  context.read<TaskTrackerBloc>().add(StopTrackingTaskEvent());
                },
              );
            }
          }

          if (trackerState.status == TaskTrackerStatus.tracking) {
            return JobProgressCard(
              taskId: _activeTaskId!,
              task: null,
              onStop: () {
                setState(() => _activeTaskId = null);
                context.read<TaskTrackerBloc>().add(StopTrackingTaskEvent());
              },
            );
          }
        }

        return const OutputEmptyHint();
      },
    );
  }
}
