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
import 'package:flutter/foundation.dart'; // Add this import

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
  bool isAudioPlaying = false;

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

  // Save all changes
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
                  'dy': textData.position.dy,
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
          'textData': textDataJson,
          'doodlePoints': doodlePoints
              .map((point) => {'dx': point.dx, 'dy': point.dy})
              .toList(),
          'folderId': widget.folderId,
          'userId': widget.userId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving content: ${e.toString()}')),
        );
      }
      print('Error saving content: $e');
    }
  }

  // Load saved content
  Future<void> _loadSavedContent() async {
    try {
      final doc = await databases.getDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
      );
      if (!mounted) return; // Check if the widget is still mounted

      setState(() async {
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
              position: Offset(
                  textJson['position']['dx'], textJson['position']['dy']),
            ));
          }
        }

        // Load doodle points
        List<Offset> loadedDoodlePoints = [];
        if (doc.data['doodlePoints'] != null) {
          for (var point in doc.data['doodlePoints']) {
            loadedDoodlePoints.add(Offset(point['dx'], point['dy']));
          }
        }

        media = mediaData;
        textDataList = loadedTextData;
        doodlePoints = loadedDoodlePoints;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No saved content found: $e')),
        );
      }
      print('No saved content found: $e');
    }
  }

  // Add media (image or video)
  Future<void> _addMedia(String type) async {
    final XFile? file;
    try {
      if (type == 'image') {
        file = await _picker.pickImage(source: ImageSource.gallery);
      } else if (type == 'video') {
        file = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        return;
      }
      if (file != null && mounted) {
        if (kIsWeb) {
          // Convert file to data URL for web
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          final imageUrl = "data:image/png;base64,$base64Image";

          setState(() {
            media.add({
              'type': type,
              'value': imageUrl, // Use the data URL for web
            });
          });
        } else {
          setState(() {
            media.add({
              'type': type,
              'value': file!.path, // Use the file path for mobile
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load media: ${e.toString()}')),
        );
      }
    }
  }

  // Play audio from URL
  void _playAudioFromUrl(String url) {
    setState(() {
      _audioUrl = url;
      isAudioPlaying = true;
    });
    _audioPlayer.play(UrlSource(url));
  }

  // Play audio from YouTube video ID
  void _playAudioFromVideoId(String videoId) {
    setState(() {
      _audioUrl = "https://www.youtube.com/watch?v=$videoId";
      isAudioPlaying = true;
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(videoId: videoId),
        ),
      );
    }
  }

  // Change background color
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

  // Show font picker
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
                  isAddingText = true;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // Show text color picker
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

  // Show doodle panel
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
                      Navigator.pop(context);
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

  // Clear doodles
  void _clearDoodles() {
    setState(() {
      doodlePoints.clear();
    });
  }

  // Show options menu
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Clear Doodles'),
              onTap: () {
                Navigator.pop(context);
                _clearDoodles();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Add text at a specific position
  void _addText(Offset position) {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Text"),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: "Type something..."),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.pop(context); // Close the dialog without saving
            },
          ),
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  textDataList.add(TextData(
                    text: text,
                    font: selectedFont,
                    color: selectedTextColor,
                    position: position,
                  ));
                  isAddingText = false;
                });
              }
              Navigator.pop(context); // Close the dialog
            },
          ),
        ],
      ),
    );
  }

  // Show audio picker
  void _showAudioPicker() async {
    final TextEditingController _searchController = TextEditingController();
    List<Map<String, dynamic>> _searchResults = [];

    if (!mounted) return; // Ensure the widget is still mounted

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
                if (query.isNotEmpty && mounted) {
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
                      if (mounted) {
                        Navigator.pop(context);
                        _playAudioFromVideoId(video['id']['videoId']);
                      }
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageName),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveContent,
          ),
        ],
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
        onTap: () {
          if (isAddingText) {
            _addText(textPosition ?? Offset.zero);
          }
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
            ...media.map((mediaItem) {
              if (mediaItem['type'] == 'image') {
                if (kIsWeb) {
                  // Use Image.network for web
                  return Positioned(
                    left: 50,
                    top: 50,
                    child: Image.network(
                      mediaItem['value'], // Use the file path directly
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  );
                } else {
                  // Use Image.file for mobile
                  return Positioned(
                    left: 50,
                    top: 50,
                    child: Image.file(
                      File(mediaItem['value']),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            }).toList(),
            RepaintBoundary(
              child: DoodleCanvas(
                points: doodlePoints,
                color: doodleColor,
                strokeWidth: doodleStrokeWidth,
              ),
            ),
            if (isAudioPlaying)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: AudioPlayerWidget(
                  audioPlayer: _audioPlayer,
                  audioUrl: _audioUrl,
                ),
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

class AudioPlayerWidget extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final String? audioUrl;

  const AudioPlayerWidget({
    Key? key,
    required this.audioPlayer,
    this.audioUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (audioUrl != null)
          Text(
            "Now Playing: ${audioUrl!.split('/').last}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                if (audioUrl != null) {
                  audioPlayer.play(UrlSource(audioUrl!));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () {
                audioPlayer.pause();
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                audioPlayer.stop();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class DoodleCanvas extends StatelessWidget {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const DoodleCanvas({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: DoodlePainter(
            points: points,
            color: color,
            strokeWidth: strokeWidth,
          ),
        );
      },
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
