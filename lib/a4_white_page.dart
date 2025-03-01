import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import 'dart:convert';

class A4WhitePage extends StatefulWidget {
  final String pageName;

  const A4WhitePage({super.key, required this.pageName});

  @override
  _A4WhitePageState createState() => _A4WhitePageState();
}

class _A4WhitePageState extends State<A4WhitePage> {
  List<Map<String, dynamic>> content = [];
  List<TextEditingController> controllers = [];
  Color backgroundColor = Colors.white;
  bool isScribbling = false;

  @override
  void initState() {
    super.initState();
    _loadSavedContent();
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveContent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('savedContent_${widget.pageName}', jsonEncode(content));
    prefs.setInt('backgroundColor_${widget.pageName}', backgroundColor.value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Content saved successfully!')),
    );
  }

  Future<void> _loadSavedContent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('savedContent_${widget.pageName}');
    int? savedColor = prefs.getInt('backgroundColor_${widget.pageName}');

    if (savedData != null) {
      List<dynamic> savedList = jsonDecode(savedData);
      setState(() {
        content = savedList.map((item) {
          return {
            'type': item['type'],
            'value': item['value'],
            'dx': item['dx'],
            'dy': item['dy']
          };
        }).toList();

        controllers = List.generate(content.length, (index) {
          return TextEditingController(
              text: content[index]['type'] == 'text'
                  ? content[index]['value']
                  : '');
        });
      });
    }

    if (savedColor != null) {
      setState(() {
        backgroundColor = Color(savedColor);
      });
    }
  }

  void _addText() {
    setState(() {
      content.add({'type': 'text', 'value': '', 'dx': 50.0, 'dy': 50.0});
      controllers.add(TextEditingController());
    });
  }

  void _updateText(int index, String newText) {
    content[index]['value'] = newText;
  }

  Future<void> _addPhoto() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        content.add(
            {'type': 'photo', 'value': image.path, 'dx': 50.0, 'dy': 50.0});
      });
    }
  }

  Future<void> _addVideo() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        content.add({'type': 'video', 'value': video.path});
      });
    }
  }

  void _changeBackgroundColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Choose Background Color"),
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
            child: Text("Done"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _toggleScribbling() {
    setState(() {
      isScribbling = !isScribbling;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageName,
            style: TextStyle(fontFamily: 'DancingScript', color: Colors.white)),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _saveContent),
          IconButton(
              icon: Icon(Icons.format_paint),
              onPressed: _changeBackgroundColor),
          IconButton(icon: Icon(Icons.brush), onPressed: _toggleScribbling),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: backgroundColor,
            padding: EdgeInsets.all(16),
            child: Stack(
              children: content.asMap().entries.map((entry) {
                int index = entry.key;
                final item = entry.value;

                if (item['type'] == 'text') {
                  return Positioned(
                    left: item['dx'],
                    top: item['dy'],
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          content[index]['dx'] += details.delta.dx;
                          content[index]['dy'] += details.delta.dy;
                        });
                      },
                      child: Container(
                        width: 250,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: controllers[index],
                          onChanged: (value) => _updateText(index, value),
                          style: TextStyle(
                              fontFamily: 'DancingScript', fontSize: 20),
                          decoration: InputDecoration(border: InputBorder.none),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                    ),
                  );
                } else if (item['type'] == 'photo') {
                  return Positioned(
                    left: item['dx'],
                    top: item['dy'],
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          content[index]['dx'] += details.delta.dx;
                          content[index]['dy'] += details.delta.dy;
                        });
                      },
                      child: Image.file(File(item['value']),
                          width: 150, height: 150, fit: BoxFit.contain),
                    ),
                  );
                } else if (item['type'] == 'video') {
                  return VideoWidget(videoPath: item['value']);
                }
                return Container();
              }).toList(),
            ),
          ),
          if (isScribbling) ScribbleCanvas(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                      leading: Icon(Icons.text_fields, color: Colors.redAccent),
                      title: Text('Add Text'),
                      onTap: () {
                        _addText();
                        Navigator.pop(context);
                      }),
                  ListTile(
                      leading: Icon(Icons.photo, color: Colors.redAccent),
                      title: Text('Add Photo'),
                      onTap: () {
                        _addPhoto();
                        Navigator.pop(context);
                      }),
                  ListTile(
                      leading:
                          Icon(Icons.video_library, color: Colors.redAccent),
                      title: Text('Add Video'),
                      onTap: () {
                        _addVideo();
                        Navigator.pop(context);
                      }),
                ],
              );
            },
          );
        },
        backgroundColor: Colors.redAccent,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class VideoWidget extends StatefulWidget {
  final String videoPath;
  const VideoWidget({Key? key, required this.videoPath}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? VideoPlayer(_controller)
        : CircularProgressIndicator();
  }
}

class ScribbleCanvas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(); // Implement scribble
  }
}
