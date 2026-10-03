import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/downloader_repository.dart';
import 'downloader_event.dart';
import 'downloader_state.dart';

class DownloaderBloc extends Bloc<DownloaderEvent, DownloaderState> {
  final DownloaderRepository _downloaderRepository;

  DownloaderBloc({required this._downloaderRepository})
      : super(const DownloaderState()) {
    on<SubmitDownloaderJobEvent>(_onSubmitDownloaderJob);
    on<ResetDownloaderEvent>(_onResetDownloader);
  }

  Future<void> _onSubmitDownloaderJob(
    SubmitDownloaderJobEvent event,
    Emitter<DownloaderState> emit,
  ) async {
    emit(state.copyWith(status: DownloaderStatus.submitting));
    try {
      final response = await _downloaderRepository.submitDownload(event.request);
      emit(state.copyWith(
        status: DownloaderStatus.success,
        taskId: response.taskId,
        message: response.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DownloaderStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onResetDownloader(
    ResetDownloaderEvent event,
    Emitter<DownloaderState> emit,
  ) {
    emit(const DownloaderState());
  }
}
