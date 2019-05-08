import 'dart:io';

import 'package:flutter/services.dart';

class Thumbnailer {
  static const MethodChannel _channel = MethodChannel('com.video_cutie/trim');

  static Future<File> getThumb(String sourcePath) async {
    final utilMap = <String, dynamic>{
      'sourcePath': sourcePath,
    };
    return File(await _channel.invokeMethod('getThumb', utilMap));
  }
}
