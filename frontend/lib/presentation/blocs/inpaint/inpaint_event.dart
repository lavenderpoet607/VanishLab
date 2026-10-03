import 'dart:typed_data';
import 'package:equatable/equatable.dart';

abstract class InpaintEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ImageSelectedEvent extends InpaintEvent {
  final Uint8List imageBytes;
  final String filename;
  final double width;
  final double height;

  ImageSelectedEvent({
    required this.imageBytes,
    required this.filename,
    required this.width,
    required this.height,
  });

  @override
  List<Object?> get props => [filename, width, height];
}

class SubmitInpaintJobEvent extends InpaintEvent {
  final Uint8List maskBytes;

  SubmitInpaintJobEvent({required this.maskBytes});

  @override
  List<Object?> get props => [maskBytes.length];
}

class SubmitVideoInpaintJobEvent extends InpaintEvent {
  final Uint8List videoBytes;
  final String filename;
  final String cornerPreset;
  final int? boxX;
  final int? boxY;
  final int? boxW;
  final int? boxH;
  final Uint8List? maskBytes;

  SubmitVideoInpaintJobEvent({
    required this.videoBytes,
    required this.filename,
    this.cornerPreset = 'bottom_right',
    this.boxX,
    this.boxY,
    this.boxW,
    this.boxH,
    this.maskBytes,
  });

  @override
  List<Object?> get props => [filename, videoBytes.length, cornerPreset, boxX, boxY, boxW, boxH, maskBytes?.length];
}

class ResetInpaintEvent extends InpaintEvent {}
