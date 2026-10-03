import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanishlab/core/theme/app_theme.dart';
import 'package:vanishlab/data/models/quota_model.dart';
import 'package:vanishlab/data/models/task_models.dart';
import 'package:vanishlab/presentation/widgets/download_result_panel.dart';
import 'package:vanishlab/presentation/widgets/segmented_selector.dart';
import 'package:vanishlab/presentation/widgets/top_utility_bar.dart';
import 'package:vanishlab/presentation/widgets/adaptive_navigation.dart';

void main() {
  group('Tactical Minimalist UI Tests - VanishLab', () {
    testWidgets('TopUtilityBar displays brand and quota badge with countdown', (tester) async {
      final quota = QuotaInfo(
        dailyQuota: 50,
        usedQuotaToday: 4,
        remainingQuota: 46,
        resetAt: DateTime.now().toUtc().add(const Duration(hours: 15, minutes: 48, seconds: 29)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TopUtilityBar(
              quotaInfo: quota,
              serverCheckToken: 0,
              onServerTap: () {},
              onQuotaTap: () {},
              onQuotaResetElapsed: () {},
            ),
          ),
        ),
      );

      expect(find.text('VanishLab'), findsOneWidget);

      expect(find.textContaining('46 / 50'), findsOneWidget);
      expect(find.textContaining('left'), findsOneWidget);
    });

    testWidgets('SegmentedSelector toggles between Video and Audio cleanly', (tester) async {
      bool isAudio = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SegmentedSelector<bool>(
                  segments: const [
                    (false, 'Video (MP4)'),
                    (true, 'Audio (MP3)'),
                  ],
                  selected: isAudio,
                  onChanged: (val) {
                    setState(() => isAudio = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Video (MP4)'), findsOneWidget);
      expect(find.text('Audio (MP3)'), findsOneWidget);

      await tester.tap(find.text('Audio (MP3)'));
      await tester.pumpAndSettle();

      expect(isAudio, isTrue);
    });

    testWidgets('ProcessedResultCard renders completed media details and action buttons', (tester) async {
      final task = TaskDetail(
        taskId: 'e2b3c4d5-1234-5678-90ab-cdef12345678',
        taskType: TaskType.downloadMedia,
        status: TaskStatus.completed,
        progress: 100,
        resultMetadata: {
          'title': 'High Precision Aesthetic Reel',
          'width': 1080,
          'height': 1920,
          'duration': 15,
        },
        outputFiles: [
          MediaFile(
            id: 'file-1',
            fileName: 'clean_e2b3c4d5.mp4',
            fileType: 'video',
            fileSizeBytes: (2.9 * 1024 * 1024).round(),
            isOutput: true,
            downloadUrl: 'http://localhost:8000/media/outputs/clean_e2b3c4d5.mp4',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProcessedResultCard(task: task),
            ),
          ),
        ),
      );

      expect(find.text('High Precision Aesthetic Reel'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);

      expect(find.textContaining('MP4'), findsOneWidget);
      expect(find.textContaining('2.9 MB'), findsOneWidget);
      expect(find.textContaining('1080p'), findsOneWidget);

      expect(find.widgetWithText(FilledButton, 'Download File'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Copy Link'), findsOneWidget);
    });

    testWidgets('BottomDock renders Inpaint, Downloader, and Tasks navigation tabs', (tester) async {
      int activeIndex = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            bottomNavigationBar: BottomDock(
              selectedIndex: activeIndex,
              onSelected: (idx) => activeIndex = idx,
            ),
          ),
        ),
      );

      expect(find.text('Inpaint'), findsOneWidget);
      expect(find.text('Downloader'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);

      await tester.tap(find.text('Tasks'));
      await tester.pump();
      expect(activeIndex, 2);
    });

    testWidgets('ProcessedResultCard renders completed MP3 audio media details', (tester) async {
      final task = TaskDetail(
        taskId: 'a1b2c3d4-9999-8888-7777-666655554444',
        taskType: TaskType.downloadMedia,
        status: TaskStatus.completed,
        progress: 100,
        resultMetadata: {
          'title': 'Aesthetic Audio Track',
          'duration': 185,
        },
        outputFiles: [
          MediaFile(
            id: 'file-mp3',
            fileName: 'clean_a1b2c3d4.mp3',
            fileType: 'audio',
            fileSizeBytes: (4.2 * 1024 * 1024).round(),
            isOutput: true,
            downloadUrl: 'http://localhost:8000/media/outputs/clean_a1b2c3d4.mp3',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProcessedResultCard(task: task),
            ),
          ),
        ),
      );

      expect(find.text('Aesthetic Audio Track'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.textContaining('MP3'), findsOneWidget);
      expect(find.textContaining('4.2 MB'), findsOneWidget);
      expect(find.textContaining('3:05'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Download File'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Copy Link'), findsOneWidget);
    });
  });
}
