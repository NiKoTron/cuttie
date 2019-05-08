import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_cutie/bloc/bloc.dart';
import 'package:video_cutie/model/video_file.dart';
import 'package:video_cutie/repositories/repository.dart';
import 'package:video_player/video_player.dart';

class RecorderBloc extends Bloc {
  final log = Logger('RecorderBloc');

  Repository<VideoFile> _filesRepository;

  final _cameraStreamController =
      StreamController<CameraController>.broadcast();
  final _videoStreamController = StreamController<VideoPlayerController>();

  final _isRecordingController = StreamController<bool>();

  final _timerController = StreamController<Duration>();

  Stream<VideoPlayerController> get videoController =>
      _videoStreamController.stream;

  Stream<CameraController> get cameraController =>
      _cameraStreamController.stream;

  Stream<bool> get isRecording => _isRecordingController.stream;

  Stream<Duration> get timer => _timerController.stream;

  CameraController _cameraController;
  VideoPlayerController _videoPreviewController;
  Timer _timer;

  RecorderBloc(this._filesRepository) {
    _isRecordingController.add(false);
    init();
  }

  String _recordingPath;

  @override
  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
    _videoPreviewController.dispose();
    _videoPreviewController = null;

    _videoStreamController.close();
    _cameraStreamController.close();
    _isRecordingController.close();
    _timerController.close();
  }

  void init() async {
    final list = await _filesRepository.getAll();
    if (list.isNotEmpty) {
      final videoFile = list.reduce((v1, v2) =>
          v1.creationDate.millisecondsSinceEpoch >
                  v2.creationDate.millisecondsSinceEpoch
              ? v1
              : v2);
      await setVideo(videoFile.file);
    }
  }

  Future<void> setCamera(CameraDescription camera) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(camera, ResolutionPreset.high);
    await _cameraController.initialize();
    if (_cameraController.value.isInitialized) {
      _cameraStreamController.add(_cameraController);
    }
  }

  Future<void> setVideo(File videoFile) async {
    if (videoFile != null && await videoFile.exists()) {
      _videoPreviewController = VideoPlayerController.file(videoFile);
      await _videoPreviewController.setVolume(0.0);
      await _videoPreviewController.setLooping(true);
      await _videoPreviewController.initialize();

      _videoStreamController.add(_videoPreviewController);
    } else {
      log.info('video does not exists');
    }
  }

  Future<void> startRecording() async {
    if (!_cameraController.value.isInitialized ||
        _cameraController.value.isRecordingVideo) {
      return;
    }

    final extDir = await getApplicationDocumentsDirectory();
    final dirPath = '${extDir.path}/recorded';
    await Directory(dirPath).create(recursive: true);
    _recordingPath =
        '$dirPath/${DateTime.now().millisecondsSinceEpoch.toString()}.mp4';
    try {
      log.info('start video recording to: $_recordingPath');
      await _cameraController.startVideoRecording(_recordingPath);
      _isRecordingController.add(true);
      _timer = Timer.periodic(Duration(seconds: 1),
          (t) => _timerController.add(Duration(seconds: t.tick)));
    } on CameraException catch (e) {
      log.shout(e.description, e);
      return;
    }
  }

  Future<void> stopRecording() async {
    if (!_cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await _cameraController.stopVideoRecording();
      _isRecordingController.add(false);
      _timer.cancel();
      _timerController.add(null);
    } on CameraException catch (e) {
      log.shout(e.description, e);
      return;
    }

    log.info('video recorded to: $_recordingPath');

    final videoFile = await VideoFile.createFromPath(_recordingPath);

    _filesRepository.add(videoFile);

    await setVideo(videoFile.file);
    _recordingPath = null;
  }

  @override
  void lifeCycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController != null) {
        setCamera(_cameraController.description);
      }
    }
  }
}
