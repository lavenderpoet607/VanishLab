import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_models.dart';
import '../utils/download_actions.dart';

class SlateCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool outlinedOnly;

  const SlateCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.outlinedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: outlinedOnly ? Colors.transparent : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const SectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTheme.label.copyWith(color: color),
    );
  }
}

class StatusTag extends StatelessWidget {
  final String text;
  final Color color;

  const StatusTag(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusTag),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.label.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

String shortJobId(String id) =>
    id.replaceAll('-', '').substring(0, math.min(8, id.replaceAll('-', '').length)).toUpperCase();

class OutputEmptyHint extends StatelessWidget {
  const OutputEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    return SlateCard(
      outlinedOnly: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Output'),
          const SizedBox(height: 6),
          Text(
            'Your clean file shows up here when processing finishes.',
            style: AppTheme.body.copyWith(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class JobProgressCard extends StatelessWidget {
  final String taskId;
  final TaskDetail? task;
  final VoidCallback onStop;

  const JobProgressCard({
    super.key,
    required this.taskId,
    required this.task,
    required this.onStop,
  });

  static String phaseFor(int? progress) {
    if (progress == null) return 'Connecting to job';
    if (progress < 10) return 'Queued for a worker';
    if (progress < 15) return 'Reading media info';
    if (progress < 55) return 'Downloading source stream';
    if (progress < 85) return 'Re-encoding and stripping metadata';
    if (progress < 100) return 'Uploading clean file';
    return 'Finishing';
  }

  @override
  Widget build(BuildContext context) {
    final progress = task?.progress;
    final percent = progress == null ? null : (progress / 100).clamp(0.0, 1.0);

    return SlateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SectionLabel('Processing'),
              const Spacer(),
              Text('JOB ${shortJobId(taskId)}', style: AppTheme.readout),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  phaseFor(progress),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                progress == null ? '--%' : '$progress%',
                style: AppTheme.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Job progress',
            value: progress == null ? 'connecting' : '$progress percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: percent, minHeight: 4),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 0),
              ),
              child: const Text('Stop tracking'),
            ),
          ),
        ],
      ),
    );
  }
}

class JobFailedCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  const JobFailedCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SlateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SectionLabel('Output'),
              const Spacer(),
              const StatusTag('Failed', AppTheme.error),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body.copyWith(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onRetry != null) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProcessedResultCard extends StatelessWidget {
  final TaskDetail task;

  const ProcessedResultCard({super.key, required this.task});

  static String _formatDuration(num seconds) {
    final total = seconds.round();
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    if (m >= 60) {
      return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}:$s';
    }
    return '$m:$s';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final file = task.primaryOutput!;
    final meta = task.resultMetadata ?? const <String, dynamic>{};
    final isAudio = file.fileType == 'audio';

    final title = (meta['title'] as String?)?.trim().isNotEmpty == true
        ? (meta['title'] as String).trim()
        : file.fileName;
    final ext = file.fileName.contains('.')
        ? file.fileName.split('.').last.toUpperCase()
        : file.fileType.toUpperCase();
    final bytes = file.fileSizeBytes > 0 ? file.fileSizeBytes : (meta['file_size'] as num?)?.toInt() ?? 0;
    final width = meta['width'] as num?;
    final height = meta['height'] as num?;
    final duration = meta['duration'] as num?;
    final thumbnail = meta['thumbnail'] as String?;

    final facts = <String>[
      ext,
      if (bytes > 0) _formatBytes(bytes),
      if (!isAudio && width != null && height != null) '${math.min(width, height).round()}p',
      if (isAudio && duration != null && duration > 0) _formatDuration(duration),
    ];

    return SlateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SectionLabel('Output'),
              const SizedBox(width: 8),
              Text('JOB ${shortJobId(task.taskId)}', style: AppTheme.readout),
              const Spacer(),
              const StatusTag('Completed', AppTheme.success),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Thumbnail(url: thumbnail, isAudio: isAudio),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      facts.join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final download = FilledButton.icon(
                onPressed: () => openDownloadUrl(context, file.downloadUrl),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download File'),
              );
              final copy = OutlinedButton.icon(
                onPressed: () => copyDownloadLink(context, file.downloadUrl),
                icon: const Icon(Icons.content_copy_outlined, size: 16),
                label: const Text('Copy Link'),
              );

              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [download, const SizedBox(height: 8), copy],
                );
              }
              return Row(
                children: [
                  Expanded(child: download),
                  const SizedBox(width: 8),
                  Expanded(child: copy),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  final bool isAudio;

  const _Thumbnail({required this.url, required this.isAudio});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppTheme.surfaceRaised,
      alignment: Alignment.center,
      child: Icon(
        isAudio ? Icons.graphic_eq : Icons.movie_outlined,
        size: 20,
        color: AppTheme.textSecondary,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: SizedBox(
        width: 48,
        height: 48,
        child: url == null || url!.isEmpty
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
