import 'package:equatable/equatable.dart';
import '../../../data/models/downloader_models.dart';

abstract class DownloaderEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SubmitDownloaderJobEvent extends DownloaderEvent {
  final DownloaderRequest request;

  SubmitDownloaderJobEvent(this.request);

  @override
  List<Object?> get props => [request];
}

class ResetDownloaderEvent extends DownloaderEvent {}
