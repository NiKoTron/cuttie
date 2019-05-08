import 'dart:io';

abstract class Editor {
  Future<File> trim(File src, int startMs, int endMs);
  Future<bool> isItSupported();
}
