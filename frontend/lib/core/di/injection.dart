import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/downloader_repository.dart';
import '../../data/repositories/inpaint_repository.dart';
import '../../data/repositories/task_repository.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();

  sl.registerSingleton<SharedPreferences>(prefs);
  sl.registerSingleton<FlutterSecureStorage>(secureStorage);

  sl.registerLazySingleton<StorageService>(
    () => StorageService(
      secureStorage: sl<FlutterSecureStorage>(),
      prefs: sl<SharedPreferences>(),
    ),
  );

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(storageService: sl<StorageService>()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      apiClient: sl<ApiClient>(),
      storageService: sl<StorageService>(),
    ),
  );

  sl.registerLazySingleton<DownloaderRepository>(
    () => DownloaderRepository(apiClient: sl<ApiClient>()),
  );

  sl.registerLazySingleton<InpaintRepository>(
    () => InpaintRepository(apiClient: sl<ApiClient>()),
  );

  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepository(apiClient: sl<ApiClient>()),
  );
}
