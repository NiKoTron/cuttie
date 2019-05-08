import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_cutie/core/thumbnailer.dart';
import 'package:video_player/video_player.dart';

class VideoFile {
  File file;
  File thumbFile;
  Duration duration;

  DateTime get creationDate =>
      file == null ? DateTime.now() : file.statSync().changed;

  String get name => file == null ? '' : file.uri.pathSegments.last;

  VideoFile(this.file, this.thumbFile, this.duration);

  static Future<VideoFile> createFromPath(String path) async {
    final completer = Completer<VideoFile>();

    final videoFile = File(path);
    if (!videoFile.existsSync()) {
      completer.completeError('no_exist');
    }

    final extDir = await getApplicationDocumentsDirectory();

    var thumbnailFile = File(
        '${extDir.path}/thumbs/${videoFile.uri.pathSegments.last.replaceAll('.mp4', ".jpg")}');
    if (!thumbnailFile.existsSync()) {
      thumbnailFile = await Thumbnailer.getThumb(path);
    }

    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();

    final duration = controller.value.duration;
    await controller.dispose();

    completer.complete(VideoFile(videoFile, thumbnailFile, duration));

    return completer.future;
  }
}
