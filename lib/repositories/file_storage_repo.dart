import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_cutie/model/video_file.dart';
import 'package:video_cutie/repositories/repository.dart';

class FileStorageRepository extends Repository<VideoFile> {
  final log = Logger('LibraryRepository');

  Directory workingDirectory;
  bool _needToUpdate = true;

  List<VideoFile> cache;

  bool initialised = false;

  Future<void> init() async {
    final extDir = await getApplicationDocumentsDirectory();
    final dirPath = '${extDir.path}/recorded';
    workingDirectory = Directory(dirPath);
    if (workingDirectory.existsSync() == false) {
      await workingDirectory.create(recursive: true);
    }
    initialised = true;
  }

  @override
  void add(item) {
    cache?.add(item);
  }

  @override
  void delete(item) {
    cache?.remove(item);
    item.file.delete();
    item.thumbFile.delete();
  }

  @override
  Future<VideoFile> getByName(String name) async {
    final list = await getAll();
    return list.firstWhere((f) => f.file.uri.pathSegments.last == name);
  }

  @override
  Future<Iterable<VideoFile>> getAll({bool forceUpdate}) async {
    final completer = Completer<Iterable<VideoFile>>();
    if (!initialised) {
      log.info('repository does not initialized');
      await init();
    }

    _needToUpdate = forceUpdate == null ? _needToUpdate : forceUpdate;

    if (_needToUpdate || cache == null) {
      cache = await workingDirectory
          .list(recursive: false, followLinks: false)
          .where((t) =>
              t.statSync().type == FileSystemEntityType.file &&
              t.path.endsWith('.mp4'))
          .asyncMap((f) => VideoFile.createFromPath(f.path))
          .toList();
      completer.complete(cache);
      _needToUpdate = false;
    } else {
      completer.complete(cache);
    }

    return completer.future;
  }
}
