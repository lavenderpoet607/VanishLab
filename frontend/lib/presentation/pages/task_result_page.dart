import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_models.dart';
import '../blocs/task_tracker/task_tracker_bloc.dart';
import '../blocs/task_tracker/task_tracker_event.dart';
import '../blocs/task_tracker/task_tracker_state.dart';
import '../utils/download_actions.dart';
import '../widgets/comparison_slider.dart';

class TaskResultPage extends StatefulWidget {
  const TaskResultPage({super.key});

  @override
  State<TaskResultPage> createState() => _TaskResultPageState();
}

class _TaskResultPageState extends State<TaskResultPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _lookupTaskId() {
    final id = _searchController.text.trim();
    if (id.isNotEmpty) {
      context.read<TaskTrackerBloc>().add(StartTrackingTaskEvent(id));
    }
  }

  Future<void> _openDownloadUrl(String url) async {
    await openDownloadUrl(context, url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Task Tracker & Results',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 24),
                BlocBuilder<TaskTrackerBloc, TaskTrackerState>(
                  builder: (context, state) {
                    if (state.status == TaskTrackerStatus.idle) {
                      return _buildEmptyState();
                    }

                    if (state.status == TaskTrackerStatus.failed) {
                      return _buildFailedCard(state);
                    }

                    final task = state.task;
                    if (task == null && state.isProcessing) {
                      return _buildConnectingCard();
                    }

                    if (task != null) {
                      if (task.status.isSuccess) {
                        return _buildCompletedView(task);
                      } else {
                        return _buildProgressCard(task);
                      }
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTheme.body,
              decoration: const InputDecoration(
                hintText: 'Cari berdasarkan Task ID (UUID)...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _lookupTaskId(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.content_paste, size: 18),
            tooltip: 'Tempel dari clipboard',
            color: AppTheme.textSecondary,
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                _searchController.text = data!.text!.trim();
                _lookupTaskId();
              }
            },
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _lookupTaskId,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: const Size(60, 38),
              elevation: 0,
            ),
            child: const Text('Lacak', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingCard() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accent),
          ),
          SizedBox(height: 20),
          Text(
            'Menghubungkan ke Pemantau Tugas...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 6),
          Text(
            'Memeriksa status antrean worker backend...',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(TaskDetail task) {
    final percent = (task.progress / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.taskType == TaskType.inpaintVideo
                          ? 'Video Watermark Job'
                          : task.taskType == TaskType.inpaintImage
                              ? 'AI Inpainting Job'
                              : 'Media Extraction Job',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      'Task ID: ${task.taskId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(task.status.name.toUpperCase(), AppTheme.accent),
            ],
          ),
          const SizedBox(height: 36),

          CircularPercentIndicator(
            radius: 70.0,
            lineWidth: 10.0,
            percent: percent,
            center: Text(
              '${task.progress}%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            progressColor: AppTheme.accent,
            backgroundColor: AppTheme.surfaceElevated,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animateFromLastPercent: true,
          ),
          const SizedBox(height: 28),

          Text(
            task.progress < 20
                ? 'Job queued and assigned to background worker...'
                : task.progress < 80
                    ? 'Processing media with AI neural engine...'
                    : 'Finalizing encoding and generating clean download link...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          LinearPercentIndicator(
            lineHeight: 6.0,
            percent: percent,
            barRadius: const Radius.circular(3),
            progressColor: AppTheme.accent,
            backgroundColor: AppTheme.surfaceElevated,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(TaskDetail task) {
    final outputFile = task.primaryOutput;
    final resolvedOutputUrl = outputFile != null ? ApiConfig.resolveForNetwork(outputFile.downloadUrl) : '';

    final rawInputUrl = task.resultMetadata?['input_image_url'] as String? ??
        task.inputParams['image_url'] as String? ??
        task.inputParams['original_url'] as String?;
    final resolvedInputUrl = (rawInputUrl != null && rawInputUrl.isNotEmpty) ? ApiConfig.resolveForNetwork(rawInputUrl) : null;

    final canShowComparison = task.taskType == TaskType.inpaintImage &&
        resolvedInputUrl != null &&
        resolvedOutputUrl.isNotEmpty &&
        resolvedInputUrl != resolvedOutputUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Processing Complete!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      'Task ${task.taskId} finished successfully.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill('READY', AppTheme.success),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (canShowComparison) ...[
          Container(
            height: 440,
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: BeforeAfterComparison(
              beforeImageUrl: resolvedInputUrl,
              afterImageUrl: resolvedOutputUrl,
            ),
          ),
          const SizedBox(height: 16),
        ] else if (outputFile != null && outputFile.fileType == 'image') ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 400,
              color: AppTheme.surfaceCard,
              child: Image.network(
                resolvedOutputUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_outlined, color: AppTheme.error, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load image preview',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _openDownloadUrl(outputFile.downloadUrl),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download Image'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (outputFile != null && outputFile.fileType == 'video') ...[
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 48,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Watermark-Free Video Ready',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    outputFile.fileName,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (outputFile != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 440;
                final downloadButtonWidget = ElevatedButton.icon(
                  onPressed: () => _openDownloadUrl(outputFile.downloadUrl),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                );

                final copyButtonWidget = IconButton.filledTonal(
                  onPressed: () => copyDownloadLink(context, outputFile.downloadUrl),
                  tooltip: 'Copy download link',
                  icon: const Icon(Icons.copy, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceElevated,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.all(12),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              outputFile.fileType == 'video'
                                  ? Icons.videocam
                                  : outputFile.fileType == 'audio'
                                      ? Icons.audiotrack
                                      : Icons.image,
                              color: AppTheme.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outputFile.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${outputFile.fileType.toUpperCase()} • ${outputFile.humanReadableSize}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: downloadButtonWidget),
                          const SizedBox(width: 8),
                          copyButtonWidget,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        outputFile.fileType == 'video'
                            ? Icons.videocam
                            : outputFile.fileType == 'audio'
                                ? Icons.audiotrack
                                : Icons.image,
                        color: AppTheme.accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outputFile.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${outputFile.fileType.toUpperCase()} • ${outputFile.humanReadableSize}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    downloadButtonWidget,
                    const SizedBox(width: 8),
                    copyButtonWidget,
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFailedCard(TaskTrackerState state) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, size: 36, color: AppTheme.error),
          ),
          const SizedBox(height: 16),
          const Text(
            'Task Processing Failed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            state.errorMessage ?? 'An unexpected error occurred during execution.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusControl)),
            ),
            onPressed: () {
              context.read<TaskTrackerBloc>().add(StopTrackingTaskEvent());
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Dismiss Error'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.radar_rounded, size: 36, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          const Text(
            'No Active Tasks in Queue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jobs submitted in Photo/Video Inpainting or Media Downloader will automatically appear here with real-time status and logs.\n\nYou can also enter a valid Task ID in the field above.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusTag),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
