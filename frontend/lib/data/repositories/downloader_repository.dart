import '../models/downloader_models.dart';
import '../models/task_models.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';

class DownloaderRepository {
  final ApiClient _apiClient;

  DownloaderRepository({required this._apiClient});

  Future<SubmitTaskResponse> submitDownload(DownloaderRequest request) async {
    final response = await _apiClient.post(
      ApiConfig.downloaderProcessEndpoint,
      data: request.toJson(),
    );
    return SubmitTaskResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
