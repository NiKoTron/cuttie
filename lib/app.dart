import 'package:camera/camera.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:video_cutie/pages/editor_page.dart';
import 'package:video_cutie/pages/files_page.dart';
import 'package:video_cutie/pages/recorder_page.dart';
import 'package:video_cutie/repositories/file_storage_repo.dart';

import 'model/video_file.dart';
import 'repositories/repository.dart';

Future<void> main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  final log = Logger('main');

  List<CameraDescription> cameras;
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    log.warning('Could not find available cameras ${e.code} ${e.description}');
  }
  runApp(CuttieApp(cameras));
}

class CuttieApp extends StatelessWidget {
  final _router = Router();

  final List<CameraDescription> cameras;

  CuttieApp(this.cameras) {
    _router
      ..define('/',
          handler: Handler(handlerFunc: (context, params) => RecorderPage()))
      ..define('/editor/:path',
          handler: Handler(
              handlerFunc: (context, params) =>
                  EditorPage(path: params['path'][0])))
      ..define('/library',
          handler: Handler(handlerFunc: (context, params) => FilesPage()));
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider(
      child: _materialWidget(context),
      cameras: cameras,
      libraryRepository: FileStorageRepository(),
    );
  }

  Widget _materialWidget(BuildContext context) {
    return MaterialApp(
        title: 'Video Cuttie Demo',
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        initialRoute: '/',
        onGenerateRoute: _router.generator);
  }
}

enum ASPECT { cameras, library }

class AppProvider extends InheritedModel<ASPECT> {
  final List<CameraDescription> cameras;
  final Repository<VideoFile> libraryRepository;

  AppProvider({
    @required this.cameras,
    @required this.libraryRepository,
    @required Widget child,
  }) : super(child: child);

  @override
  bool updateShouldNotify(AppProvider oldWidget) {
    return cameras != oldWidget.cameras ||
        libraryRepository != oldWidget.libraryRepository;
  }

  @override
  bool updateShouldNotifyDependent(
      AppProvider oldWidget, Set<ASPECT> dependencies) {
    return (dependencies.contains(ASPECT.cameras) &&
            oldWidget.cameras != cameras) ||
        (dependencies.contains(ASPECT.library) &&
            oldWidget.libraryRepository != libraryRepository);
  }

  static AppProvider of(BuildContext context, {ASPECT aspect}) {
    return InheritedModel.inheritFrom<AppProvider>(context, aspect: aspect);
  }
}
