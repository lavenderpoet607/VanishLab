import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/inpaint_repository.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/inpaint/inpaint_bloc.dart';
import '../blocs/inpaint/inpaint_event.dart';
import '../blocs/inpaint/inpaint_state.dart';
import '../blocs/task_tracker/task_tracker_bloc.dart';
import '../blocs/task_tracker/task_tracker_event.dart';
import '../widgets/inpaint_canvas/drawing_canvas.dart';
import '../widgets/inpaint_canvas/drawing_controller.dart';
import 'auth_dialog.dart';

enum InpaintMediaMode { photo, video }
enum VideoSelectionMode { preset, box, brush }

class InpaintPage extends StatefulWidget {
  final Function(int) onNavigateTab;

  const InpaintPage({super.key, required this.onNavigateTab});

  @override
  State<InpaintPage> createState() => _InpaintPageState();
}

class _InpaintPageState extends State<InpaintPage> {
  final DrawingController _photoDrawingController = DrawingController();
  final DrawingController _videoDrawingController = DrawingController();
  Size _renderedCanvasSize = Size.zero;

  InpaintMediaMode _mediaMode = InpaintMediaMode.photo;

  Uint8List? _videoBytes;
  String? _videoFilename;
  int _videoSizeBytes = 0;
  Uint8List? _videoPreviewFrameBytes;
  double _videoAspectRatio = 16 / 9;
  int _videoOriginalWidth = 1280;
  int _videoOriginalHeight = 720;
  bool _isLoadingVideoPreview = false;
  Size _renderedVideoCanvasSize = Size.zero;

  VideoSelectionMode _videoSelectionMode = VideoSelectionMode.preset;
  String _videoCornerPreset = 'bottom_right';

  double _videoBoxX = 0.65;
  double _videoBoxY = 0.83;
  double _videoBoxW = 0.32;
  double _videoBoxH = 0.14;

  @override
  void dispose() {
    _photoDrawingController.dispose();
    _videoDrawingController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width.toDouble();
    final height = frame.image.height.toDouble();

    _photoDrawingController.clear();

    if (mounted) {
      context.read<InpaintBloc>().add(
            ImageSelectedEvent(
              imageBytes: bytes,
              filename: xFile.name,
              width: width,
              height: height,
            ),
          );
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickVideo(source: ImageSource.gallery);
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    setState(() {
      _videoBytes = bytes;
      _videoFilename = xFile.name;
      _videoSizeBytes = bytes.length;
      _isLoadingVideoPreview = true;
      _videoPreviewFrameBytes = null;
    });

    _fetchVideoPreview(bytes, xFile.name);
  }

  Future<void> _fetchVideoPreview(Uint8List bytes, String filename) async {
    try {
      final repo = sl<InpaintRepository>();
      final data = await repo.getVideoPreview(
        videoBytes: bytes,
        videoFilename: filename,
      );

      final b64 = data['preview_frame_base64'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        final frameBytes = base64Decode(b64);
        final w = (data['width'] as num?)?.toInt() ?? 1280;
        final h = (data['height'] as num?)?.toInt() ?? 720;
        final ar = (data['aspect_ratio'] as num?)?.toDouble() ?? (w / h);

        if (mounted) {
          setState(() {
            _videoPreviewFrameBytes = frameBytes;
            _videoOriginalWidth = w;
            _videoOriginalHeight = h;
            _videoAspectRatio = ar > 0 ? ar : 16 / 9;
            _isLoadingVideoPreview = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingVideoPreview = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVideoPreview = false);
    }
  }

  Future<void> _submitInpainting(InpaintState state) async {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      AuthDialog.show(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib login terlebih dahulu untuk melakukan inpainting & pembersihan watermark.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (!state.hasImage) return;

    if (!_photoDrawingController.hasStrokes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan tandai area watermark dengan Brush, Box, atau Lasso terlebih dahulu.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      final maskBytes = await _photoDrawingController.generateBinaryMaskPng(
        originalWidth: state.originalWidth,
        originalHeight: state.originalHeight,
        renderedSize: _renderedCanvasSize.isEmpty
            ? Size(state.originalWidth, state.originalHeight)
            : _renderedCanvasSize,
      );

      if (mounted) {
        context.read<InpaintBloc>().add(SubmitInpaintJobEvent(maskBytes: maskBytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat mask: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _submitVideoInpainting() async {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      AuthDialog.show(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wajib login terlebih dahulu untuk menghapus watermark video.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (_videoBytes == null || _videoFilename == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih file video terlebih dahulu.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    Uint8List? customMaskBytes;
    int? bX, bY, bW, bH;

    if (_videoSelectionMode == VideoSelectionMode.brush) {
      if (_videoDrawingController.hasStrokes) {
        try {
          customMaskBytes = await _videoDrawingController.generateBinaryMaskPng(
            originalWidth: _videoOriginalWidth.toDouble(),
            originalHeight: _videoOriginalHeight.toDouble(),
            renderedSize: _renderedVideoCanvasSize.isEmpty
                ? Size(_videoOriginalWidth.toDouble(), _videoOriginalHeight.toDouble())
                : _renderedVideoCanvasSize,
          );
        } catch (_) {}
      }
    } else if (_videoSelectionMode == VideoSelectionMode.box) {

      bX = (_videoBoxX * 1000).toInt();
      bY = (_videoBoxY * 1000).toInt();
      bW = (_videoBoxW * 1000).toInt();
      bH = (_videoBoxH * 1000).toInt();
    }

    if (mounted) {
      context.read<InpaintBloc>().add(
            SubmitVideoInpaintJobEvent(
              videoBytes: _videoBytes!,
              filename: _videoFilename!,
              cornerPreset: _videoCornerPreset,
              boxX: bX,
              boxY: bY,
              boxW: bW,
              boxH: bH,
              maskBytes: customMaskBytes,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InpaintBloc, InpaintState>(
      listener: (context, state) {
        if (state.status == InpaintStatus.success && state.taskId != null) {
          context.read<AuthBloc>().add(RefreshQuotaEvent());
          context.read<TaskTrackerBloc>().add(StartTrackingTaskEvent(state.taskId!));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _mediaMode == InpaintMediaMode.video
                    ? 'Tugas pembersihan video telah diantrekan! Melacak progres...'
                    : 'Tugas inpainting foto telah diantrekan! Melacak progres...',
              ),
              backgroundColor: AppTheme.success,
            ),
          );

          if (_mediaMode == InpaintMediaMode.video) {
            setState(() {
              _videoBytes = null;
              _videoFilename = null;
              _videoSizeBytes = 0;
            });
          }

          widget.onNavigateTab(2);
        } else if (state.status == InpaintStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state.status == InpaintStatus.submitting;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 12,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_fix_high, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Watermark Remover',
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
            actions: [
              if (_mediaMode == InpaintMediaMode.photo && state.hasImage) ...[
                TextButton.icon(
                  onPressed: isSubmitting ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Ganti Foto'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (_mediaMode == InpaintMediaMode.video && _videoBytes != null) ...[
                TextButton.icon(
                  onPressed: isSubmitting ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined, size: 16),
                  label: const Text('Ganti Video'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          body: Column(
            children: [
              _buildModeSelector(),
              Expanded(
                child: _mediaMode == InpaintMediaMode.photo
                    ? _buildPhotoBody(state, isSubmitting)
                    : _buildVideoBody(isSubmitting),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTabItem(
              title: 'Foto / Gambar',
              icon: Icons.image_outlined,
              isSelected: _mediaMode == InpaintMediaMode.photo,
              onTap: () {
                setState(() => _mediaMode = InpaintMediaMode.photo);
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeTabItem(
              title: 'Video',
              icon: Icons.videocam_outlined,
              isSelected: _mediaMode == InpaintMediaMode.video,
              badge: 'AI CLEAN',
              onTap: () {
                setState(() => _mediaMode = InpaintMediaMode.video);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.black : AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBody(InpaintState state, bool isSubmitting) {
    if (!state.hasImage) {
      return _buildPhotoUploadPlaceholder();
    }

    final authState = context.watch<AuthBloc>().state;
    final isAuth = authState.isAuthenticated;

    return Column(
      children: [
        if (!isAuth) _buildLoginReminderBanner(),

        Expanded(
          child: DrawingCanvas(
            imageBytes: state.imageBytes!,
            controller: _photoDrawingController,
            onSizeMeasured: (size) {
              _renderedCanvasSize = size;
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceCard,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.filename ?? 'image.png',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${state.originalWidth.toInt()} x ${state.originalHeight.toInt()} px • Brush / Box / Lasso AI Inpainting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : () => _submitInpainting(state),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isAuth ? Icons.flash_on : Icons.lock_outline, size: 18),
                label: Text(
                  isSubmitting
                      ? 'Memproses...'
                      : (isAuth ? 'Hapus Watermark' : 'Login & Hapus'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAuth ? AppTheme.primary : AppTheme.surfaceRaised,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUploadPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unggah Foto untuk AI Watermark Remover',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gunakan Brush, Box (kotak), atau Lasso untuk menandai watermark logo, teks, atau objek. Dilengkapi generative background fill yang merekonstruksi tekstur latar belakang secara clean & bebas cacat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Pilih Foto / Gambar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoBody(bool isSubmitting) {
    if (_videoBytes == null) {
      return _buildVideoUploadPlaceholder();
    }

    final authState = context.watch<AuthBloc>().state;
    final isAuth = authState.isAuthenticated;
    final sizeMb = (_videoSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isAuth) ...[
                _buildLoginReminderBanner(),
                const SizedBox(height: 12),
              ],

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.movie_outlined, color: AppTheme.accent, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _videoFilename ?? 'video.mp4',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$sizeMb MB • Audio Asli & 60 FPS Dipertahankan 100%',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: isSubmitting ? null : _pickVideo,
                      tooltip: 'Ganti video',
                      icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune, size: 18, color: AppTheme.accent),
                        SizedBox(width: 8),
                        Text(
                          'Metode Pemilihan Watermark Video',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildVideoToolTab(
                            title: 'Corner Preset',
                            icon: Icons.crop_free,
                            isSelected: _videoSelectionMode == VideoSelectionMode.preset,
                            onTap: () => setState(() => _videoSelectionMode = VideoSelectionMode.preset),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildVideoToolTab(
                            title: 'Custom Box',
                            icon: Icons.crop_square,
                            isSelected: _videoSelectionMode == VideoSelectionMode.box,
                            onTap: () => setState(() => _videoSelectionMode = VideoSelectionMode.box),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildVideoToolTab(
                            title: 'Brush / Mask',
                            icon: Icons.brush,
                            isSelected: _videoSelectionMode == VideoSelectionMode.brush,
                            onTap: () => setState(() => _videoSelectionMode = VideoSelectionMode.brush),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (_videoSelectionMode == VideoSelectionMode.preset)
                      _buildVideoPresetOptions()
                    else if (_videoSelectionMode == VideoSelectionMode.box)
                      _buildVideoBoxEditor()
                    else
                      _buildVideoBrushCanvas(),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 18, color: AppTheme.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Clean Background Synthesis: Area watermark direkonstruksi menyesuaikan tekstur latar belakang dengan feathered blending tanpa blur berlebih.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: isSubmitting ? null : _submitVideoInpainting,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(isAuth ? Icons.movie_creation_outlined : Icons.lock_outline, size: 20),
                label: Text(
                  isSubmitting
                      ? 'Menjalankan Worker Video...'
                      : (isAuth ? 'Hapus Watermark Video' : 'Login & Hapus Watermark'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAuth ? AppTheme.primary : AppTheme.surfaceRaised,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginReminderBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Wajib login untuk menjalankan AI Watermark Remover & Inpainting.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => AuthDialog.show(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppTheme.accent,
            ),
            child: const Text('Login / Daftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoToolTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPresetOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pilih sudut letak watermark di dalam video:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
            if (_isLoadingVideoPreview)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              ),
          ],
        ),
        const SizedBox(height: 10),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: AspectRatio(
              aspectRatio: _videoAspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_videoPreviewFrameBytes != null)
                        Image.memory(
                          _videoPreviewFrameBytes!,
                          fit: BoxFit.contain,
                        )
                      else
                        Center(
                          child: _isLoadingVideoPreview
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                    SizedBox(height: 10),
                                    Text('Memuat preview video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                )
                              : const Icon(Icons.movie_filter, color: Colors.white24, size: 50),
                        ),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          final boxW = w * 0.35;
                          final boxH = h * 0.14;
                          final mx = w * 0.02;
                          final my = h * 0.02;

                          List<Rect> targetRects = [];
                          if (_videoCornerPreset == 'top_left') {
                            targetRects.add(Rect.fromLTWH(mx, my, boxW, boxH));
                          } else if (_videoCornerPreset == 'top_right') {
                            targetRects.add(Rect.fromLTWH(w - boxW - mx, my, boxW, boxH));
                          } else if (_videoCornerPreset == 'bottom_left') {
                            targetRects.add(Rect.fromLTWH(mx, h - boxH - my, boxW, boxH));
                          } else if (_videoCornerPreset == 'tiktok_both') {
                            targetRects.add(Rect.fromLTWH(mx, my, boxW, boxH));
                            targetRects.add(Rect.fromLTWH(w - boxW - mx, h - boxH - my, boxW, boxH));
                          } else {

                            targetRects.add(Rect.fromLTWH(w - boxW - mx, h - boxH - my, boxW, boxH));
                          }

                          return Stack(
                            children: targetRects.map((rect) {
                              return Positioned(
                                left: rect.left,
                                top: rect.top,
                                width: rect.width,
                                height: rect.height,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.accent, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'WATERMARK',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCornerOption(
              key: 'bottom_right',
              title: 'Bottom Right',
              subtitle: 'TikTok / IG Reels / Shorts',
              icon: Icons.south_east,
              recommended: true,
            ),
            _buildCornerOption(
              key: 'tiktok_both',
              title: 'Kedua Sudut',
              subtitle: 'TikTok Bouncing (Atas+Bwh)',
              icon: Icons.swap_calls,
              recommended: true,
            ),
            _buildCornerOption(
              key: 'top_left',
              title: 'Top Left',
              icon: Icons.north_west,
            ),
            _buildCornerOption(
              key: 'top_right',
              title: 'Top Right',
              icon: Icons.north_east,
            ),
            _buildCornerOption(
              key: 'bottom_left',
              title: 'Bottom Left',
              icon: Icons.south_west,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoBoxEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Geser & sesuaikan posisi kotak pada watermark:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
            if (_isLoadingVideoPreview)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              ),
          ],
        ),
        const SizedBox(height: 10),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: AspectRatio(
              aspectRatio: _videoAspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final frameW = constraints.maxWidth;
                      final frameH = constraints.maxHeight;

                      final left = (_videoBoxX * frameW).clamp(0.0, frameW - 20);
                      final top = (_videoBoxY * frameH).clamp(0.0, frameH - 20);
                      final boxWidth = (_videoBoxW * frameW).clamp(20.0, frameW - left);
                      final boxHeight = (_videoBoxH * frameH).clamp(15.0, frameH - top);

                      return Stack(
                        fit: StackFit.expand,
                        children: [

                          if (_videoPreviewFrameBytes != null)
                            Image.memory(
                              _videoPreviewFrameBytes!,
                              fit: BoxFit.contain,
                            )
                          else
                            Center(
                              child: _isLoadingVideoPreview
                                  ? const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                        SizedBox(height: 10),
                                        Text('Memuat frame video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    )
                                  : const Icon(Icons.movie_filter, color: Colors.white24, size: 50),
                            ),

                          Positioned(
                            left: left,
                            top: top,
                            width: boxWidth,
                            height: boxHeight,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _videoBoxX = ((left + details.delta.dx) / frameW).clamp(0.0, 1.0 - _videoBoxW);
                                  _videoBoxY = ((top + details.delta.dy) / frameH).clamp(0.0, 1.0 - _videoBoxH);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.accent, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'WATERMARK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        _buildSliderRow(
          label: 'Posisi X (Kiri-Kanan)',
          value: _videoBoxX,
          min: 0.0,
          max: 0.9,
          onChanged: (v) => setState(() => _videoBoxX = v),
        ),
        _buildSliderRow(
          label: 'Posisi Y (Atas-Bawah)',
          value: _videoBoxY,
          min: 0.0,
          max: 0.9,
          onChanged: (v) => setState(() => _videoBoxY = v),
        ),
        _buildSliderRow(
          label: 'Lebar Kotak (W)',
          value: _videoBoxW,
          min: 0.05,
          max: 0.8,
          onChanged: (v) => setState(() => _videoBoxW = v),
        ),
        _buildSliderRow(
          label: 'Tinggi Kotak (H)',
          value: _videoBoxH,
          min: 0.03,
          max: 0.5,
          onChanged: (v) => setState(() => _videoBoxH = v),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accent,
                thumbColor: Colors.white,
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).toInt()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBrushCanvas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gunakan Brush, Box, atau Lasso di atas frame video:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
            if (_isLoadingVideoPreview)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: AspectRatio(
              aspectRatio: _videoAspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _renderedVideoCanvasSize = Size(constraints.maxWidth, constraints.maxHeight);

                      return Stack(
                        fit: StackFit.expand,
                        children: [

                          if (_videoPreviewFrameBytes != null)
                            Image.memory(
                              _videoPreviewFrameBytes!,
                              fit: BoxFit.contain,
                            )
                          else
                            Center(
                              child: _isLoadingVideoPreview
                                  ? const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                        SizedBox(height: 10),
                                        Text('Memuat frame video...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    )
                                  : const Text(
                                      'Frame Video',
                                      style: TextStyle(color: Colors.white24, fontSize: 13),
                                    ),
                            ),

                          Positioned.fill(
                            child: GestureDetector(
                              onPanStart: (d) => _videoDrawingController.startStroke(d.localPosition),
                              onPanUpdate: (d) => _videoDrawingController.addPoint(d.localPosition),
                              onPanEnd: (_) => _videoDrawingController.endStroke(),
                              child: ListenableBuilder(
                                listenable: _videoDrawingController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: MaskPainter(
                                      items: _videoDrawingController.items,
                                      previewColor: _videoDrawingController.strokeColor,
                                      activeTool: _videoDrawingController.activeTool,
                                      activeDragStart: _videoDrawingController.activeDragStart,
                                      activeDragCurrent: _videoDrawingController.activeDragCurrent,
                                      currentPoints: _videoDrawingController.currentPoints,
                                    ),
                                    size: Size.infinite,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: _videoDrawingController,
          builder: (context, _) {
            final activeTool = _videoDrawingController.activeTool;
            return Row(
              children: [
                _buildSmallToolBtn(
                  icon: Icons.brush,
                  isSelected: activeTool == InpaintTool.brush,
                  onTap: () => _videoDrawingController.setTool(InpaintTool.brush),
                ),
                const SizedBox(width: 6),
                _buildSmallToolBtn(
                  icon: Icons.crop_square,
                  isSelected: activeTool == InpaintTool.box,
                  onTap: () => _videoDrawingController.setTool(InpaintTool.box),
                ),
                const SizedBox(width: 6),
                _buildSmallToolBtn(
                  icon: Icons.gesture,
                  isSelected: activeTool == InpaintTool.lasso,
                  onTap: () => _videoDrawingController.setTool(InpaintTool.lasso),
                ),
                const SizedBox(width: 6),
                _buildSmallToolBtn(
                  icon: Icons.cleaning_services_outlined,
                  isSelected: activeTool == InpaintTool.eraser,
                  onTap: () => _videoDrawingController.setTool(InpaintTool.eraser),
                ),
                const Spacer(),
                IconButton(
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.undo, size: 18),
                  tooltip: 'Urungkan (Undo)',
                  onPressed: _videoDrawingController.canUndo ? _videoDrawingController.undo : null,
                ),
                IconButton(
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.redo, size: 18),
                  tooltip: 'Ulangi (Redo)',
                  onPressed: _videoDrawingController.canRedo ? _videoDrawingController.redo : null,
                ),
                IconButton(
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Hapus Semua Mask',
                  color: _videoDrawingController.hasStrokes ? AppTheme.error : AppTheme.textMuted,
                  onPressed: _videoDrawingController.hasStrokes ? _videoDrawingController.clear : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSmallToolBtn({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppTheme.primary : AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border),
          ),
          child: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildCornerOption({
    required String key,
    required String title,
    required IconData icon,
    String? subtitle,
    bool recommended = false,
  }) {
    final isSelected = _videoCornerPreset == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _videoCornerPreset = key;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.2)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, size: 16, color: AppTheme.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoUploadPlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.video_library_outlined,
                        size: 40,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unggah Video untuk Hapus Watermark',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bisa gunakan Corner Preset, Custom Box, atau Brush langsung pada video. Menghilangkan logo TikTok, Reels, atau teks berjalan tanpa merusak resolusi dan kualitas suara.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.video_file_outlined),
                      label: const Text('Pilih File Video'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
