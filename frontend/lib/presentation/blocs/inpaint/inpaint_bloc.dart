import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/inpaint_repository.dart';
import 'inpaint_event.dart';
import 'inpaint_state.dart';

class InpaintBloc extends Bloc<InpaintEvent, InpaintState> {
  final InpaintRepository _inpaintRepository;

  InpaintBloc({required this._inpaintRepository})
      : super(const InpaintState()) {
    on<ImageSelectedEvent>(_onImageSelected);
    on<SubmitInpaintJobEvent>(_onSubmitInpaintJob);
    on<SubmitVideoInpaintJobEvent>(_onSubmitVideoInpaintJob);
    on<ResetInpaintEvent>(_onResetInpaint);
  }

  void _onImageSelected(
    ImageSelectedEvent event,
    Emitter<InpaintState> emit,
  ) {
    emit(state.copyWith(
      status: InpaintStatus.imageLoaded,
      imageBytes: event.imageBytes,
      filename: event.filename,
      originalWidth: event.width,
      originalHeight: event.height,
      errorMessage: null,
    ));
  }

  Future<void> _onSubmitInpaintJob(
    SubmitInpaintJobEvent event,
    Emitter<InpaintState> emit,
  ) async {
    if (state.imageBytes == null) {
      emit(state.copyWith(
        status: InpaintStatus.error,
        errorMessage: 'Please select an image first.',
      ));
      return;
    }

    emit(state.copyWith(status: InpaintStatus.submitting));
    try {
      final response = await _inpaintRepository.submitInpaint(
        imageBytes: state.imageBytes!,
        imageFilename: state.filename ?? 'input_image.png',
        maskBytes: event.maskBytes,
      );

      emit(state.copyWith(
        status: InpaintStatus.success,
        taskId: response.taskId,
        message: response.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: InpaintStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitVideoInpaintJob(
    SubmitVideoInpaintJobEvent event,
    Emitter<InpaintState> emit,
  ) async {
    emit(state.copyWith(status: InpaintStatus.submitting));
    try {
      final response = await _inpaintRepository.submitVideoInpaint(
        videoBytes: event.videoBytes,
        videoFilename: event.filename,
        cornerPreset: event.cornerPreset,
        boxX: event.boxX,
        boxY: event.boxY,
        boxW: event.boxW,
        boxH: event.boxH,
        maskBytes: event.maskBytes,
      );

      emit(state.copyWith(
        status: InpaintStatus.success,
        taskId: response.taskId,
        message: response.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: InpaintStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onResetInpaint(
    ResetInpaintEvent event,
    Emitter<InpaintState> emit,
  ) {
    emit(const InpaintState());
  }
}
