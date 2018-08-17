import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_notifications/local_notifications.dart';
import 'package:music_player/albums.dart';
import 'package:music_player/drawer.dart';
import 'package:music_player/localizations.dart';
import 'package:music_player/player.dart';
import 'package:music_player/play.dart';
import 'package:music_player/playlist.dart';
import 'package:music_player/search.dart';
import 'package:music_player/song.dart';
import 'package:music_player/songs.dart';
import 'package:path_provider/path_provider.dart';

bool isSearch = false;
TextEditingController controller = TextEditingController();
final GlobalKey<ScaffoldState> scaffoldState = GlobalKey();
bool anySelected = false;
_TabViewState tabState;
MyPlayer player;
IconData playIcon = Icons.pause;

class TabView extends StatefulWidget {
  TabView({key}):super(key:key);
  static List<Song> songList;
  Songs song = Songs();
  Albums album = Albums();
  MyPlayer player;

  @override
  _TabViewState createState() => tabState = _TabViewState();
}

void search(BuildContext context) {
  String searchKey = controller.text;
  List<Song> searchList = [];
  if (searchKey.isNotEmpty) {
    TabView.songList.forEach((song) {
      if (song.title.contains(searchKey) || song.artist.contains(searchKey))
        searchList.add(song);
    });
    if (searchList.isNotEmpty)
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SearchResult(searchKey, searchList, null)));
    else
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SearchResult(
                  searchKey, null, MyLocalizations.of(context).noSong)));
  } else
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SearchResult(
                searchKey, null, MyLocalizations.of(context).invalidName)));

  context.rootAncestorStateOfType(TypeMatcher()).setState(() {
    controller.text = '';
    isSearch = !isSearch;
  });
}

void getPlayList() async {
  final appDir = await getApplicationDocumentsDirectory();
  String path = appDir.path;
  File playList = File('$path/playlist.txt');
  if (!playList.existsSync()) playList.create();
  String content = await playList.readAsString();
  content.split('***').forEach((group) {
    List<String> details = group.split('>>>');
    if (details.length != 1) {
      List userSongs = json.decode(details[1]);
      List<Song> list = userSongs.map(Song.fromJson).toList();
      playlist.add(Album(details[0], list[0].albumArt));
      playlist.last.addAlbum(list);
    }
  });
}

void showMessage(ScaffoldState scaffold, String message) {
  scaffold.showSnackBar(SnackBar(
    content: Text(
      message,
      overflow: TextOverflow.fade,
    ),
    action: SnackBarAction(
        label: MyLocalizations.of(scaffold.context).ok, onPressed: () {}),
    duration: Duration(seconds: 1, milliseconds: 500),
  ));
}

Widget songBar() {
  double width = MediaQuery.of(scaffoldState.currentContext).size.width;
  double height = MediaQuery.of(scaffoldState.currentContext).size.height;
  return Container(
    width: width - width * 0.05,
    padding:
        const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0, right: 8.0),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: CircleAvatar(
              backgroundImage: player.currentSong.albumArt != null
                  ? FileImage(File(player.currentSong.albumArt))
                  : AssetImage('img/placeholder.png'),
              radius: width * 0.05),
        ),
        Expanded(
            flex: 3,
            child: FlatButton(
                padding: EdgeInsets.only(top: height*0.02,bottom: height*0.02),
                onPressed: () {
                  player.playMusic(player.currentSong);
                  Navigator.push(
                      scaffoldState.currentContext,
                      MaterialPageRoute(
                          builder: (context) => Play(TabView.songList,
                              player.currentSong, Songs.indexSelected)));
                },
                child: Text(
                  player.currentSong.title,
                  style: TextStyle(fontSize: 20.0, color: Colors.white),
                  overflow: TextOverflow.clip,
                  maxLines: 2,
                ))),
        IconButton(
            icon: Icon(
              Icons.skip_previous,
              color: Colors.white,
              size: width * 0.05,
            ),
            onPressed: () => player.prevSong()),
        IconButton(
            icon: Icon(playIcon, color: Colors.white, size: width * 0.05),
            onPressed: () => player.toggle()),
        IconButton(
            icon:
                Icon(Icons.skip_next, color: Colors.white, size: width * 0.05),
            onPressed: () => player.nextSong(true)),
      ],
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(width * 0.1)),
      color: Colors.brown[900],
    ),
  );
}

class _TabViewState extends State<TabView> {

  @override
  void initState() {
    super.initState();
    widget.player = MyPlayer();
    widget.player.initAudioPlayer();
    getPlayList();
  }

  @override
  void dispose() {
    // widget.player.positionSubscription.cancel();
    widget.player.audioPlayerStateSubscription.cancel();
    widget.player.stop();
    controller.dispose();
    LocalNotifications.removeNotification(0);
    super.dispose();
  }

  void selectAll() {
    stateSong.addList = List();
    TabView.songList.forEach((song) {
      song.isSelected = true;
      stateSong.addList.add(song);
    });
    stateSong.setState(() {
      stateSong.widget.songList;
    });
  }

  void add() {
    print(stateSong.addList);
    addSongs(stateSong.addList);
    TabView.songList.forEach((song) {
      song.isSelected = false;
    });
    stateSong.setState(() {
      stateSong.addList = List();
      stateSong.widget.songList;
      Songs.indexSelected = null;
    });
    tabState.setState(() => anySelected = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: player != null ? songBar() : null,
        key: scaffoldState,
        drawer: NavDrawer(),
        appBar: AppBar(
          title: !isSearch
              ? Text(MyLocalizations.of(context).music)
              : Container(
                  child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '     ${MyLocalizations
                .of(context)
                .search}',
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      onSubmitted: (_) => search(context)),
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(15.0)),
                ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: isSearch ? Icon(Icons.clear) : Icon(Icons.search),
                onPressed: () => setState(() {
                      isSearch = !isSearch;
                      controller.text = '';
                    }),
              ),
            ),
            anySelected
                ? IconButton(icon: Icon(Icons.select_all), onPressed: selectAll)
                : Container(),
            anySelected
                ? IconButton(icon: Icon(Icons.add_circle), onPressed: add)
                : Container(),
          ],
          bottom: TabBar(tabs: <Widget>[
            new Tab(text: MyLocalizations.of(context).songs),
            new Tab(text: MyLocalizations.of(context).albums)
          ]),
        ),
        body: TabBarView(children: <Widget>[
          widget.song,
          widget.album,
        ]),
      ),
    );
  }

}
