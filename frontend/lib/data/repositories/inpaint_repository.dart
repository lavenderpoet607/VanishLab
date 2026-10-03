import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../models/task_models.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';

class InpaintRepository {
  final ApiClient _apiClient;

  InpaintRepository({required this._apiClient});

  Future<SubmitTaskResponse> submitInpaint({
    required Uint8List imageBytes,
    required String imageFilename,
    required Uint8List maskBytes,
  }) async {
    final imageExt = imageFilename.split('.').last.toLowerCase();
    final imageSubtype = (imageExt == 'jpg' || imageExt == 'jpeg') ? 'jpeg' : 'png';

    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: imageFilename,
        contentType: MediaType('image', imageSubtype),
      ),
      'mask': MultipartFile.fromBytes(
        maskBytes,
        filename: 'mask.png',
        contentType: MediaType('image', 'png'),
      ),
    });

    final response = await _apiClient.post(
      ApiConfig.inpaintImageEndpoint,
      data: formData,
    );

    return SubmitTaskResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SubmitTaskResponse> submitVideoInpaint({
    required Uint8List videoBytes,
    required String videoFilename,
    String cornerPreset = 'bottom_right',
    int? boxX,
    int? boxY,
    int? boxW,
    int? boxH,
    Uint8List? maskBytes,
  }) async {
    final videoExt = videoFilename.split('.').last.toLowerCase();
    final map = <String, dynamic>{
      'video': MultipartFile.fromBytes(
        videoBytes,
        filename: videoFilename,
        contentType: MediaType('video', videoExt == 'mov' ? 'quicktime' : 'mp4'),
      ),
      'corner_preset': cornerPreset,
    };
    if (boxX != null) map['box_x'] = boxX;
    if (boxY != null) map['box_y'] = boxY;
    if (boxW != null) map['box_w'] = boxW;
    if (boxH != null) map['box_h'] = boxH;
    if (maskBytes != null) {
      map['mask'] = MultipartFile.fromBytes(
        maskBytes,
        filename: 'mask.png',
        contentType: MediaType('image', 'png'),
      );
    }

    final formData = FormData.fromMap(map);

    final response = await _apiClient.post(
      ApiConfig.inpaintVideoEndpoint,
      data: formData,
    );

    return SubmitTaskResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getVideoPreview({
    required Uint8List videoBytes,
    required String videoFilename,
    double timestampSec = 0.5,
  }) async {
    final videoExt = videoFilename.split('.').last.toLowerCase();
    final formData = FormData.fromMap({
      'video': MultipartFile.fromBytes(
        videoBytes,
        filename: videoFilename,
        contentType: MediaType('video', videoExt == 'mov' ? 'quicktime' : 'mp4'),
      ),
      'timestamp_sec': timestampSec,
    });

    final response = await _apiClient.post(
      ApiConfig.inpaintVideoPreviewEndpoint,
      data: formData,
    );

    return response.data as Map<String, dynamic>;
  }
}
