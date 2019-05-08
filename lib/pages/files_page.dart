import 'package:flutter/material.dart';
import 'package:video_cutie/app.dart';
import 'package:video_cutie/bloc/files_bloc.dart';
import 'package:video_cutie/model/video_file.dart';

class FilesPage extends StatefulWidget {
  FilesPage({Key key}) : super(key: key);

  @override
  _FilesPageState createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  FilesBloc bloc;
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final _scafoldKey = GlobalKey<ScaffoldState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = AppProvider.of(context, aspect: ASPECT.library);
    bloc = FilesBloc(provider.libraryRepository)..fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scafoldKey,
      appBar: AppBar(
        title: Text('Video Library'),
      ),
      body: Center(child: _filesWidget()),
    );
  }

  Widget _filesWidget() {
    return StreamBuilder<List<VideoFile>>(
      stream: bloc.files,
      builder: (context, snapshot) {
        return RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () => bloc.refresh(),
            child: (snapshot.hasData)
                ? GridView.builder(
                    itemCount: snapshot.data.length,
                    itemBuilder: (context, i) =>
                        _fileItemWidget(snapshot.data[i]),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2),
                  )
                : Text('there is nothing'));
      },
    );
  }

  @override
  void dispose() {
    bloc.dispose();
    super.dispose();
  }

  Widget _fileItemWidget(VideoFile data) {
    return Card(
        child: InkWell(
            splashColor: Colors.red,
            onTap: () => Navigator.pushNamedAndRemoveUntil(
                context, '/editor/${data.name}', ModalRoute.withName('/')),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.file(
                          data.thumbFile,
                          fit: BoxFit.cover,
                          height: 150,
                        ),
                      ),
                      Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            'created at:\n${data.creationDate.day}:${data.creationDate.month}:${data.creationDate.year}',
                            style: TextStyle(color: Colors.white),
                          ))
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Text(
                    data.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              ],
            )));
  }
}
