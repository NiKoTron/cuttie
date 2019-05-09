import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:logging/logging.dart';
import 'package:video_cutie/app.dart';
import 'package:video_cutie/bloc/recorder_bloc.dart';
import 'package:video_player/video_player.dart';

class RecorderPage extends StatefulWidget {
  @override
  _RecorderPageState createState() {
    return _RecorderPageState();
  }
}

class _RecorderPageState extends State<RecorderPage>
    with WidgetsBindingObserver {
  final log = Logger('RecorderPage');
  VoidCallback videoPlayerListener;
  AppProvider provider;
  RecorderBloc bloc;

  final _scafoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    provider = AppProvider.of(context);
    final cameras = provider.cameras
        .where((c) =>
            c.lensDirection == CameraLensDirection.front ||
            c.lensDirection == CameraLensDirection.back)
        .toList();

    bloc = RecorderBloc(provider.libraryRepository, cameras);
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      bloc.lifeCycleStateChanged;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scafoldKey,
      body: Stack(
        children: <Widget>[
          Column(children: <Widget>[
            Expanded(
                child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black),
              child: Center(child: _cameraPreviewWidget()),
            )),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: _captureControlRowWidget(),
            ),
          ]),
          Container(
              padding: EdgeInsets.all(35.0),
              alignment: Alignment.topCenter,
              child: _timerWidget()),
        ],
      ),
    );
  }

  Widget _timerWidget() {
    return StreamBuilder<Duration>(
        stream: bloc.timer,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                      Text(
                          '${snapshot.data.inMinutes.toString().padLeft(2, '0')}:${snapshot.data.inSeconds.toString().padLeft(2, '0')}',
                          style: TextStyle(color: Colors.white))
                    ])
              : Container();
        });
  }

  Widget _cameraPreviewWidget() {
    return StreamBuilder<CameraController>(
      stream: bloc.cameraController,
      builder: (context, snapshot) {
        return snapshot.hasData
            ? AspectRatio(
                aspectRatio: snapshot.data.value.aspectRatio,
                child: CameraPreview(snapshot.data),
              )
            : SpinKitRing(color: Colors.white);
      },
    );
  }

  Widget _captureControlRowWidget() {
    return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Expanded(child: _thumbnailWidget()),
                Expanded(child: _recordWidget()),
                Expanded(child: _cameraToggleWidget())
              ],
            ),
            constraints: BoxConstraints(minHeight: 40.0, maxHeight: 72.0)));
  }

  Widget _thumbnailWidget() {
    return StreamBuilder<VideoPlayerController>(
      stream: bloc.videoController,
      builder: (context, snapshot) {
        return snapshot.hasData
            ? SizedBox(
                child: InkWell(
                    onTap: () async {
                      final list = await provider.libraryRepository.getAll();

                      final videoFile = list.reduce((v1, v2) =>
                          v1.creationDate.millisecondsSinceEpoch >
                                  v2.creationDate.millisecondsSinceEpoch
                              ? v1
                              : v2);
                      await Navigator.pushNamed(
                        context,
                        '/editor/${videoFile.name}',
                      );
                    },
                    child: Container(
                      child: Center(
                        child: AspectRatio(
                            aspectRatio: snapshot.data.value.size != null
                                ? snapshot.data.value.aspectRatio
                                : 1.0,
                            child: VideoPlayer(snapshot.data)),
                      ),
                    )),
                width: 64.0,
                height: 64.0,
              )
            : SpinKitFadingFour(
                color: Colors.red,
              );
      },
    );
  }

  Widget _recordWidget() {
    return StreamBuilder<bool>(
        stream: bloc.isRecording,
        builder: (context, snapshot) {
          return RawMaterialButton(
              shape: CircleBorder(),
              fillColor: snapshot.hasData ? Colors.red : Colors.grey,
              splashColor: Colors.amber,
              highlightColor: Colors.amberAccent.withOpacity(0.5),
              elevation: 10.0,
              highlightElevation: 5.0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: snapshot.hasData && snapshot.data
                    ? const Icon(Icons.stop)
                    : const Icon(Icons.videocam),
              ),
              onPressed: snapshot.hasData
                  ? (snapshot.data
                      ? () => bloc.stopRecording()
                      : () => bloc.startRecording())
                  : null);
        });
  }

  Widget _cameraToggleWidget() {
    return StreamBuilder<CameraController>(
        stream: bloc.cameraController,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? IconButton(
                  icon: Icon(CameraLensDirection.back ==
                          snapshot.data.description.lensDirection
                      ? Icons.camera_rear
                      : Icons.camera_front),
                  onPressed: () => bloc.toggleCamera(),
                )
              : Container();
        });
  }
}
