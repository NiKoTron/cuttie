import 'dart:io';

import 'package:flutter/services.dart';

import 'editor.dart';

class FFMpegEditor extends Editor {
  static const MethodChannel _channel = MethodChannel('com.video_cutie/trim');

  Future<String> _trim(
      String sourcePath, String destinationPath, int startMs, int endMs) async {
    final utilMap = <String, dynamic>{
      'sourcePath': sourcePath,
      'destinationPath': destinationPath,
      'startMs': startMs,
      'endMs': endMs
    };
    return await _channel.invokeMethod('trimFFMPEG', utilMap);
  }

  @override
  Future<File> trim(File src, int startMs, int endMs) async {
    return File(await _trim(src.path, '${src.path}_cuted.mp4', startMs, endMs));
  }

  @override
  Future<bool> isItSupported() async {
    return await _channel.invokeMethod('checkFFMPEG', {});
  }
}
