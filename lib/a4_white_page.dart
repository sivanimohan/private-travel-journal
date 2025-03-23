import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:appwrite/appwrite.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class A4WhitePage extends StatefulWidget {
  final String pageId;
  final String folderId;
  final String userId;
  final String pageName;
  final Client client;

  const A4WhitePage({
    super.key,
    required this.pageId,
    required this.folderId,
    required this.userId,
    required this.pageName,
    required this.client,
  });

  @override
  _A4WhitePageState createState() => _A4WhitePageState();
}

class _A4WhitePageState extends State<A4WhitePage> {
  List<Map<String, dynamic>> media = [];
  Color backgroundColor = Colors.white;
  late Databases databases;
  late Storage storage;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioUrl;

  // New state variables for additional features
  String selectedFont = 'Delius Swash Caps';
  Color selectedTextColor = Colors.black;
  List<Offset> doodlePoints = [];
  Color doodleColor = Colors.black;
  double doodleStrokeWidth = 5.0;

  // Text input feature
  List<TextData> textDataList = [];
  bool isAddingText = false;
  Offset? textPosition;

  // Font and color options
  List<String> fonts = [
    'Delius Swash Caps',
    'Delicious Handrawn',
    'Sacramento',
    'Schoolbell',
    'Indie Flower',
  ];

  List<Color> colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
    storage = Storage(widget.client);
    _loadSavedContent();
  }

  Future<void> _saveContent() async {
    try {
      final mediaIds = media.map((m) => m['mediaId']).toList();
      final textDataJson = textDataList
          .map((textData) => {
                'text': textData.text,
                'font': textData.font,
                'color': textData.color.value,
                'position': {
                  'dx': textData.position.dx,
                  'dy': textData.position.dy
                },
              })
          .toList();

      await databases.updateDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
        data: {
          'backgroundColor': backgroundColor.value,
          'mediaIds': mediaIds,
          'textData': textDataJson, // Save text data
          'folderId': widget.folderId,
          'userId': widget.userId,
        },
      );
    } catch (e) {
      print('Error saving content: $e');
    }
  }

  Future<void> _loadSavedContent() async {
    try {
      final doc = await databases.getDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
      );
      backgroundColor =
          Color(doc.data['backgroundColor'] ?? Colors.white.value);
      List<String> mediaIds = List<String>.from(doc.data['mediaIds'] ?? []);
      List<Map<String, dynamic>> mediaData = [];
      for (String mediaId in mediaIds) {
        final mediaDoc = await databases.getDocument(
          databaseId: '67c32fc700070ceeadac',
          collectionId: '67cd34960000649f059d',
          documentId: mediaId,
        );
        mediaData.add(mediaDoc.data);
      }

      // Load text data
      List<TextData> loadedTextData = [];
      if (doc.data['textData'] != null) {
        for (var textJson in doc.data['textData']) {
          loadedTextData.add(TextData(
            text: textJson['text'],
            font: textJson['font'],
            color: Color(textJson['color']),
            position:
                Offset(textJson['position']['dx'], textJson['position']['dy']),
          ));
        }
      }

      setState(() {
        media = mediaData;
        textDataList = loadedTextData; // Update textDataList
      });
    } catch (e) {
      print('No saved content found: $e');
    }
  }

  Future<void> _addMedia(String type) async {
    final XFile? file;
    if (type == 'image') {
      file = await _picker.pickImage(source: ImageSource.gallery);
    } else if (type == 'video') {
      file = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      return;
    }
    if (file != null) {
      setState(() {
        media.add({'type': type, 'value': file?.path});
      });
    }
  }

  void _playAudioFromVideoId(String videoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioPlayerScreen(videoId: videoId),
      ),
    );
  }

  void _playAudioFromUrl(String url) {
    _audioPlayer.play(UrlSource(url));
    setState(() {
      _audioUrl = url;
    });
  }

  void _changeBackgroundColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Background Color"),
        content: BlockPicker(
          pickerColor: backgroundColor,
          onColorChanged: (color) {
            setState(() {
              backgroundColor = color;
            });
          },
        ),
        actions: [
          TextButton(
            child: const Text("Done"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showFontPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Font"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fonts.map((font) {
            return ListTile(
              title: Text(
                font,
                style: TextStyle(fontFamily: font),
              ),
              onTap: () {
                setState(() {
                  selectedFont = font;
                  isAddingText = true; // Enable text input mode
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showTextColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Text Color"),
        content: BlockPicker(
          pickerColor: selectedTextColor,
          onColorChanged: (color) {
            setState(() {
              selectedTextColor = color;
            });
          },
        ),
        actions: [
          TextButton(
            child: const Text("Done"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showDoodlePanel() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Doodle Options"),
            Row(
              children: [
                const Text("Brush Color:"),
                ...colors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        doodleColor = color;
                      });
                      Navigator.pop(context); // Close the panel
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      width: 24,
                      height: 24,
                      color: color,
                    ),
                  );
                }).toList(),
              ],
            ),
            Slider(
              value: doodleStrokeWidth,
              min: 1,
              max: 20,
              onChanged: (value) {
                setState(() {
                  doodleStrokeWidth = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Text'),
            onTap: () {
              Navigator.pop(context);
              _showFontPicker();
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Text Color'),
            onTap: () {
              Navigator.pop(context);
              _showTextColorPicker();
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image'),
            onTap: () {
              Navigator.pop(context);
              _addMedia('image');
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Video'),
            onTap: () {
              Navigator.pop(context);
              _addMedia('video');
            },
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Songs'),
            onTap: () {
              Navigator.pop(context);
              _showAudioPicker();
            },
          ),
          ListTile(
            leading: const Icon(Icons.brush),
            title: const Text('Drawing'),
            onTap: () {
              Navigator.pop(context);
              _showDoodlePanel();
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_paint),
            title: const Text('Background Color'),
            onTap: () {
              Navigator.pop(context);
              _changeBackgroundColor();
            },
          ),
        ],
      ),
    );
  }

  void _addText(Offset position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Text"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Type something..."),
          onSubmitted: (text) {
            setState(() {
              textDataList.add(TextData(
                text: text,
                font: selectedFont,
                color: selectedTextColor,
                position: position,
              ));
              isAddingText = false; // Disable text input mode
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showAudioPicker() async {
    final TextEditingController _searchController = TextEditingController();
    List<Map<String, dynamic>> _searchResults = [];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Search Songs"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration:
                  const InputDecoration(hintText: "Search for a song..."),
              onChanged: (query) async {
                if (query.isNotEmpty) {
                  _searchResults = await YouTubeAPI.searchVideos(query);
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final video = _searchResults[index];
                  return ListTile(
                    title: Text(video['snippet']['title']),
                    subtitle: Text(video['snippet']['channelTitle']),
                    onTap: () {
                      Navigator.pop(context);
                      _playAudioFromVideoId(
                          video['id']['videoId']); // Use _playAudioFromVideoId
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageName),
        backgroundColor: Colors.redAccent,
      ),
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            doodlePoints.add(details.localPosition);
          });
        },
        onPanEnd: (details) {
          setState(() {
            doodlePoints.add(Offset.infinite);
          });
        },
        child: Stack(
          children: [
            Container(color: backgroundColor),
            ...textDataList.map((textData) {
              return Positioned(
                left: textData.position.dx,
                top: textData.position.dy,
                child: Text(
                  textData.text,
                  style: TextStyle(
                    fontFamily: textData.font,
                    color: textData.color,
                    fontSize: 24,
                  ),
                ),
              );
            }).toList(),
            LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth,
                      constraints.maxHeight), // Use parent constraints
                  painter: DoodlePainter(
                    points: doodlePoints,
                    color: doodleColor,
                    strokeWidth: doodleStrokeWidth,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _showOptionsMenu,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class DoodlePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DoodlePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TextData {
  final String text;
  final String font;
  final Color color;
  final Offset position;

  TextData({
    required this.text,
    required this.font,
    required this.color,
    required this.position,
  });
}

class YouTubeAPI {
  static const String _apiKey = "AIzaSyBgWM2m_UatmmrEfO8y41fos3E12qjkv4E";

  // Search for videos
  static Future<List<Map<String, dynamic>>> searchVideos(String query) async {
    final response = await http.get(
      Uri.parse(
          "https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&maxResults=10&key=$_apiKey"),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['items']);
    } else {
      throw Exception("Failed to load videos");
    }
  }
}

class AudioPlayerScreen extends StatefulWidget {
  final String videoId;

  const AudioPlayerScreen({required this.videoId});

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true, // Hide video controls for audio-only playback
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Now Playing"),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blueAccent,
        ),
      ),
    );
  }
}
