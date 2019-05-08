import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/services.dart';

import 'editor.dart';

class MediaCodecEditor extends Editor {
  static const MethodChannel _channel = MethodChannel('com.video_cutie/trim');

  Future<String> _trim(
      String sourcePath, String destinationPath, int startMs, int endMs) async {
    final utilMap = <String, dynamic>{
      'sourcePath': sourcePath,
      'destinationPath': destinationPath,
      'startMs': startMs,
      'endMs': endMs
    };
    return await _channel.invokeMethod('trim', utilMap);
  }

  @override
  Future<File> trim(File src, int startMs, int endMs) async {
    return File(await _trim(src.path, '${src.path}_cuted.mp4', startMs, endMs));
  }

  // https://android.googlesource.com/platform/packages/apps/Camera2/+/b50b5cb/src/com/android/camera/util/ApiHelper.java#189
  // just check that is a jelly bean mr2 i.e. API level 18
  @override
  Future<bool> isItSupported() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo != null && androidInfo.version.sdkInt >= 18;
  }
}
