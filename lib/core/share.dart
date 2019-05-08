import 'package:flutter/services.dart';

class Share {
  static const MethodChannel _channel = MethodChannel('com.video_cutie/trim');

  static Future<void> share(String sourcePath) async {
    final utilMap = <String, dynamic>{
      'sourcePath': sourcePath,
    };
    await _channel.invokeMethod('share', utilMap);
  }
}
