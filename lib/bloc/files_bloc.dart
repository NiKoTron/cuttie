import 'dart:async';

import 'package:video_cutie/bloc/bloc.dart';
import 'package:video_cutie/model/video_file.dart';
import 'package:video_cutie/repositories/repository.dart';

class FilesBloc extends Bloc {
  Repository<VideoFile> _repository;

  final _controller = StreamController<List<VideoFile>>();

  Stream<List<VideoFile>> get files => _controller.stream;

  FilesBloc(this._repository);

  Future<void> refresh() async {
    _controller.sink.add(await _repository.getAll(forceUpdate: true));
  }

  Future<void> fetchAll() async {
    _controller.sink.add(await _repository.getAll());
  }

  @override
  void dispose() {
    _controller.close();
  }
}
