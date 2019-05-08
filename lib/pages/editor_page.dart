import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_range_slider/flutter_range_slider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:tuple/tuple.dart';
import 'package:video_cutie/bloc/editor_bloc.dart';
import 'package:video_player/video_player.dart';

class EditorPage extends StatefulWidget {
  final String path;
  EditorPage({@required this.path, Key key}) : super(key: key);

  @override
  _EditorPageState createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  EditorBloc bloc;

  final _scafoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scafoldKey,
      appBar: AppBar(
        title: Text('Editor'),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _videoPreviewWidget(),
            ),
            _seekBarWidget(),
            _rangeBarWidget(),
            Padding(
                padding: const EdgeInsets.all(6.0),
                child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _controlRowWidget()))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    bloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    bloc = EditorBloc(editorType: 'ffmpeg');
    bloc.trimmedFile.listen(_onNewTrimmedFile);
    bloc.setPath(widget.path);
    super.initState();
  }

  Widget _controlRowWidget() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: <
        Widget>[
      Expanded(
          child: IconButton(
        icon: Icon(Icons.view_list),
        onPressed: () => Navigator.pushNamed(context, '/library'),
      )),
      Expanded(
        child: StreamBuilder<bool>(
            stream: bloc.isMute,
            initialData: false,
            builder: (context, snapshot) {
              return IconButton(
                icon: Icon(snapshot.data ? Icons.volume_off : Icons.volume_up),
                onPressed: () => bloc.toggleSound(),
              );
            }),
      ),
      Expanded(
          child: StreamBuilder<VideoState>(
              stream: bloc.playerState,
              builder: (context, snapshot) {
                return RawMaterialButton(
                  shape: CircleBorder(),
                  fillColor: Colors.red,
                  splashColor: Colors.amber,
                  highlightColor: Colors.amberAccent.withOpacity(0.5),
                  elevation: 10.0,
                  highlightElevation: 5.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child:
                        snapshot.hasData && snapshot.data == VideoState.playing
                            ? const Icon(Icons.stop)
                            : const Icon(Icons.play_arrow),
                  ),
                  onPressed: () => bloc.playState(
                      snapshot.data == VideoState.playing
                          ? VideoState.paused
                          : VideoState.playing),
                );
              })),
      Expanded(
        child: StreamBuilder<bool>(
            stream: bloc.isLooped,
            initialData: false,
            builder: (context, snapshot) {
              return IconButton(
                icon: Icon(snapshot.data ? Icons.loop : Icons.keyboard_tab),
                onPressed: () => bloc.toggleLooping(),
              );
            }),
      ),
      Expanded(
          child: IconButton(
        icon: Icon(Icons.share),
        onPressed: () => bloc.share(),
      ))
    ]);
  }

  void _editorNotSupportedSnack() {
    final snackBar = SnackBar(
      content: Text('Editor not supported'),
    );
    _scafoldKey.currentState.showSnackBar(snackBar);
  }

  void _onNewTrimmedFile(File f) {
    final snackBar = SnackBar(
      content: Text('File successfully trimmed'),
      action: SnackBarAction(label: 'Open', onPressed: () => bloc.setFile(f)),
    );
    _scafoldKey.currentState.showSnackBar(snackBar);
  }

  Widget _rangeBarWidget() {
    return StreamBuilder<Tuple2<int, int>>(
        stream: bloc.range,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Row(children: <Widget>[
                  Expanded(
                      child: RangeSlider(
                    divisions: 100,
                    showValueIndicator: true,
                    min: 0.0,
                    max: bloc.clipDurationMs.toDouble(),
                    lowerValue: snapshot.data.item1.toDouble(),
                    upperValue: snapshot.data.item2.toDouble(),
                    onChanged: (s, e) =>
                        bloc.setRange(Tuple2(s.toInt(), e.toInt())),
                  )),
                  IconButton(
                      onPressed: () {
                        bloc
                            .trim(snapshot.data.item1, snapshot.data.item2)
                            .then(
                                (s) => !s ? _editorNotSupportedSnack() : null);
                      },
                      icon: Icon(Icons.content_cut))
                ])
              : Divider();
        });
  }

  Widget _seekBarWidget() {
    return StreamBuilder<Duration>(
        stream: bloc.position,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Slider(
                  value: snapshot.data.inMilliseconds.toDouble(),
                  min: 0.0,
                  max: bloc.clipDurationMs.toDouble(),
                  divisions: 100,
                  onChanged: (i) => bloc.setPosition(i.toInt()))
              : Container();
        });
  }

  Widget _videoPreviewWidget() {
    return StreamBuilder<VideoPlayerController>(
        stream: bloc.videoController,
        builder: (context, snapshot) {
          return snapshot.hasData && snapshot.data.value.initialized
              ? Stack(children: <Widget>[
                  AspectRatio(
                    aspectRatio: snapshot.data.value.aspectRatio,
                    child: VideoPlayer(snapshot.data),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FutureBuilder<DateTime>(
                        future: bloc.fileChangeDate,
                        builder: (context, snapshot) {
                          return Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(snapshot.hasData
                                  ? 'created at: ${snapshot.data.day}.${snapshot.data.month}.${snapshot.data.year}'
                                  : '...'));
                        },
                      ),
                      StreamBuilder<File>(
                        stream: bloc.currentFile,
                        builder: (context, snapshot) {
                          return Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(snapshot.hasData
                                  ? 'file: ${snapshot.data.uri.pathSegments.last}'
                                  : '...'));
                        },
                      )
                    ],
                  )
                ])
              : SpinKitRing(color: Colors.black);
        });
  }
}
