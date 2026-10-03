import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/downloader_repository.dart';
import 'data/repositories/inpaint_repository.dart';
import 'data/repositories/task_repository.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/downloader/downloader_bloc.dart';
import 'presentation/blocs/inpaint/inpaint_bloc.dart';
import 'presentation/blocs/task_tracker/task_tracker_bloc.dart';
import 'presentation/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const VanishLabApp());
}

class VanishLabApp extends StatelessWidget {
  const VanishLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            authRepository: sl<AuthRepository>(),
          )..add(CheckAuthStatusEvent()),
        ),
        BlocProvider<DownloaderBloc>(
          create: (_) => DownloaderBloc(
            downloaderRepository: sl<DownloaderRepository>(),
          ),
        ),
        BlocProvider<InpaintBloc>(
          create: (_) => InpaintBloc(
            inpaintRepository: sl<InpaintRepository>(),
          ),
        ),
        BlocProvider<TaskTrackerBloc>(
          create: (_) => TaskTrackerBloc(
            taskRepository: sl<TaskRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'VanishLab - AI Watermark Remover & Clean Media Downloader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
