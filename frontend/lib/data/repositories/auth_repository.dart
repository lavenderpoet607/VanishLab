import '../models/auth_models.dart';
import '../models/quota_model.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final StorageService _storageService;

  AuthRepository({
    required this._apiClient,
    required this._storageService,
  });

  Future<AuthToken> login({required String email, required String password}) async {
    final response = await _apiClient.post(
      ApiConfig.loginEndpoint,
      data: {'email': email, 'password': password},
    );
    final token = AuthToken.fromJson(response.data as Map<String, dynamic>);
    await _storageService.saveToken(token.accessToken);
    return token;
  }

  Future<User> register({required String email, required String password}) async {
    final response = await _apiClient.post(
      ApiConfig.registerEndpoint,
      data: {'email': email, 'password': password},
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> getCurrentUser() async {
    final response = await _apiClient.get(ApiConfig.meEndpoint);
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<QuotaInfo> getQuota() async {
    final response = await _apiClient.get(ApiConfig.quotaEndpoint);
    return QuotaInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<QuotaInfo> resetQuota() async {
    final response = await _apiClient.post(ApiConfig.quotaResetEndpoint);
    return QuotaInfo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> isAuthenticated() async {
    final token = await _storageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _storageService.clearToken();
  }
}
