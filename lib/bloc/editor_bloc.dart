import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';
import 'package:video_cutie/core/editor/editor.dart';
import 'package:video_cutie/core/editor/ffmpeg_editor.dart';
import 'package:video_cutie/core/editor/mediacodec_editor.dart';
import 'package:video_cutie/core/share.dart';
import 'package:video_player/video_player.dart';

import 'bloc.dart';

enum VideoState { playing, stopped, paused }

class EditorNotSupportedError extends Error {}

class EditorBloc extends Bloc {
  final log = Logger('EditorBloc');

  final _playerController = StreamController<VideoPlayerController>();
  final _rangeController = StreamController<Tuple2<int, int>>();
  final _positionController = StreamController<Duration>();
  final _playerStateController = StreamController<VideoState>();
  final _currentFileController = StreamController<File>();
  final _muteController = StreamController<bool>();
  final _loopController = StreamController<bool>();
  final _editorBusyController = StreamController<bool>();

  var _playerListener;

  Stream<VideoPlayerController> get videoController => _playerController.stream;
  Stream<VideoState> get playerState => _playerStateController.stream;
  Stream<Tuple2<int, int>> get range => _rangeController.stream;
  Stream<Duration> get position => _positionController.stream;
  Stream<File> get currentFile => _currentFileController.stream;
  Stream<bool> get isMute => _muteController.stream;
  Stream<bool> get isLooped => _loopController.stream;
  Stream<bool> get editorBusy => _editorBusyController.stream;

  Editor editor;

  EditorBloc({String editorType}) {
    editor = editorType != null && editorType == 'ffmpeg'
        ? FFMpegEditor()
        : MediaCodecEditor();
    _playerListener = () => _controller.value.initialized
        ? _positionController.add(_controller.value.position)
        : log.info('_controller did not not initialised');
  }

  VideoPlayerController _controller;
  File _videoFile;
  Tuple2<int, int> _selectedRange;

  Future<DateTime> get fileChangeDate async =>
      (await _videoFile.stat()).changed;

  int get clipDurationMs =>
      _controller == null || !_controller.value.initialized
          ? 0
          : _controller.value.duration.inMilliseconds;

  Future<File> _getFile(String path) async {
    final extDir = await getApplicationDocumentsDirectory();
    final dirPath = '${extDir.path}/recorded';
    return File('$dirPath/$path');
  }

  Future<void> setPath(String path) async {
    final file = await _getFile(path);
    await setFile(file);
  }

  Future<void> setFile(File videoFile) async {
    if (videoFile != null && await videoFile.exists()) {
      _videoFile = videoFile;
      _currentFileController.add(_videoFile);

      _controller = VideoPlayerController.file(_videoFile)
        ..removeListener(_playerListener)
        ..addListener(_playerListener);

      await _controller.initialize();
      _playerController.add(_controller);

      _positionController.add(Duration(milliseconds: 0));
      _rangeController.add(Tuple2(0, clipDurationMs));
    } else {
      log.info('video does not exists');
    }
  }

  @override
  void dispose() {
    _playerController.close();
    _playerStateController.close();
    _rangeController.close();
    _positionController.close();
    _muteController.close();
    _editorBusyController.close();

    _controller
      ..removeListener(_playerListener)
      ..dispose();
    _controller = null;
  }

  void setRange(Tuple2<int, int> range) {
    if (_selectedRange?.item1 != range.item1) {
      setPosition(range.item1);
    } else if (_selectedRange?.item2 != range.item2) {
      setPosition(range.item2);
    }
    _selectedRange = range;
    _rangeController.sink.add(_selectedRange);
  }

  void setPosition(int position) {
    final pos = Duration(milliseconds: position);
    _controller.seekTo(pos);
    _positionController.add(pos);
  }

  void playState(VideoState state) {
    _playerStateController.add(state);
    switch (state) {
      case VideoState.playing:
        _controller.play();
        break;
      case VideoState.paused:
        _controller.pause();
        break;
      case VideoState.stopped:
        setPosition(0);
        _controller.pause();
        break;
    }
  }

  Future<File> trim() async {
    _editorBusyController.add(true);
    final isSupported = await editor.isItSupported();
    if (!isSupported) {
      _editorBusyController.add(false);
      throw EditorNotSupportedError();
    }
    try {
      final file = await editor.trim(
          _videoFile, _selectedRange.item1, _selectedRange.item2);
      _editorBusyController.add(false);
      return file;
    } catch (e) {
      _editorBusyController.add(false);
      rethrow;
    }
  }

  Future<void> share() async {
    await Share.share(_videoFile.path);
  }

  Future<void> toggleSound() async {
    final isMute = !(_controller.value.volume == 0.0);
    await _controller.setVolume(isMute ? 0.0 : 1.0);
    _muteController.add(isMute);
  }

  Future<void> toggleLooping() async {
    final newLooping = !_controller.value.isLooping;
    await _controller.setLooping(newLooping);
    _loopController.add(newLooping);
  }
}
