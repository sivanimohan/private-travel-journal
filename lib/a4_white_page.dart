import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:appwrite/appwrite.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'audio_page.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'youtube_audio_extractor.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'location_page.dart';

final String bucketId = '67cd36510039f3d96c62';

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
  String? selectedLocation;
  Color backgroundColor = Colors.white;
  late Databases databases;
  late Storage storage;
  final ImagePicker _picker = ImagePicker();
  bool isSaving = false;
  bool isSavingLocation = false;
  List<String> locations = [];

  // Audio player implementation
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> audioIds = [];
  bool _isAudioPlaying = false;
  double _audioVolume = 0.5; // Range 0-1

  // Text input
  List<TextData> textDataList = [];
  bool isAddingText = false;
  String selectedFont = 'Delius Swash Caps';
  Color selectedTextColor = Colors.black;
  List<String> fonts = [
    'Delius Swash Caps',
    'Delicious Handrawn',
    'Sacramento',
    'Schoolbell',
    'Indie Flower',
  ];

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
    storage = Storage(widget.client);

    // Initialize audio player
    _audioPlayer.playbackEventStream.listen((event) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = _audioPlayer.playing;
        });
      }
    }, onError: (e) {
      debugPrint('Audio player error: $e');
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _isLoadingAudio = false;
        });
      }
    });

    _loadSavedContent();
    textDataList = [];
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  List<Widget> _buildAudioPlayers() {
    return [
      if (audioIds.isNotEmpty)
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_isAudioPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _toggleAudioPlayback,
                ),
                SizedBox(width: 8),
                Text('Audio Player', style: TextStyle(fontSize: 14, fontFamily: 'Josefin Sans')),
                SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _audioVolume * 100,
                    min: 0,
                    max: 100,
                    onChanged: _setAudioVolume,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _addAudio() async {
    final videoId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AudioPage()),
    );

    if (videoId != null && mounted) {
      setState(() => audioIds.add(videoId));
    }
  }

  bool _isLoadingAudio = false;
  Future<void> _playAllAudio() async {
    if (audioIds.isEmpty || !mounted) return;

    try {
      setState(() {
        _isLoadingAudio = true;
        _isAudioPlaying = true;
      });

      // Clear any previous audio sources
      await _audioPlayer.stop();
      await _audioPlayer
          .setAudioSource(AudioSource.uri(Uri.parse('about:blank')));

      final audioUrl =
          await YouTubeAudioExtractor.getAudioStreamUrl(audioIds.last);

      // Set the audio source
      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(audioUrl)),
      );

      // Set volume before playing
      await _audioPlayer.setVolume(_audioVolume);

      // Play the audio
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _isLoadingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}', style: TextStyle(fontFamily: 'Josefin Sans'))),
        );
      }
      if (kDebugMode) {
        print('Error playing audio: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _stopAllAudio() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() => _isAudioPlaying = false);
    }
  }

  void _toggleAudioPlayback() async {
    if (_isAudioPlaying) {
      await _stopAllAudio();
    } else {
      await _playAllAudio();
    }
  }

  void _setAudioVolume(double volume) {
    final newVolume = volume / 100; // Convert 0-100 to 0-1
    setState(() => _audioVolume = newVolume);
    _audioPlayer.setVolume(newVolume);
  }

  String _generateShortHash(String input) {
    final hash = input.hashCode;
    final base36 = hash.toRadixString(36);
    return base36.length <= 6 ? base36 : base36.substring(base36.length - 6);
  }

  Future<void> _saveContent() async {
    try {
      setState(() => isSavingLocation = true);

      final textDataToSave = textDataList
          .map((text) => [
                text.text,
                text.font,
                text.color.value,
                text.position.dx.toInt(),
                text.position.dy.toInt(),
              ])
          .toList();

      final documentData = {
        'pageId': widget.pageId,
        'userId': widget.userId,
        'folderId': widget.folderId,
        'pageName': widget.pageName,
        'backgroundColor': backgroundColor.value,
        'audioIds': audioIds,
        'media': media.map((m) => m['fileId'] ?? '').toList(),
        'textData': jsonEncode(textDataToSave),
        'location': selectedLocation ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await databases.updateDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
        data: documentData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e', style: TextStyle(fontFamily: 'Josefin Sans'))),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => isSavingLocation = false);
    }
  }

  Future<void> _loadSavedContent() async {
    try {
      final doc = await databases.getDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
      );

      final data = doc.data;

      setState(() {
        backgroundColor = _parseBackgroundColor(data['backgroundColor']);
        selectedLocation = _parseLocation(data);
        _isAudioPlaying = data['audioId'] != null;
        audioIds = List<String>.from(data['audioIds'] ?? []);
        textDataList = [];

        if (data['textData'] != null) {
          try {
            if (data['textData'] is String) {
              final decoded = jsonDecode(data['textData'] as String) as List;
              textDataList = decoded.map((item) {
                return TextData(
                  text: item[0]?.toString() ?? '',
                  font: item[1]?.toString() ?? fonts.first,
                  color: Color(item[2] is int ? item[2] : Colors.black.value),
                  position: Offset(
                    (item[3] ?? 50).toDouble(),
                    (item[4] ?? 50).toDouble(),
                  ),
                );
              }).toList();
            } else if (data['textData'] is List) {
              textDataList = (data['textData'] as List).map((item) {
                if (item is Map) {
                  return TextData.fromJson(Map<String, dynamic>.from(item));
                }
                return TextData(
                  text: '',
                  font: fonts.first,
                  color: Colors.black,
                  position: Offset.zero,
                );
              }).toList();
            }
          } catch (e) {
            debugPrint('Error parsing text data: $e');
          }
        }

        media =
            (data['media'] as List? ?? []).map<Map<String, dynamic>>((item) {
          return {
            'type': 'image',
            'fileId': item is String ? item : '',
            'position': const Offset(50, 50),
            'width': MediaQuery.of(context).size.width < 600 ? 200.0 : 300.0,
            'height': MediaQuery.of(context).size.width < 600 ? 266.0 : 400.0,
          };
        }).toList();
      });

      await _loadMediaData();
    } catch (e) {
      debugPrint('Error loading content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: $e', style: TextStyle(fontFamily: 'Josefin Sans'))),
        );
      }
    }
  }

  Future<void> _loadMediaData() async {
    try {
      for (int i = 0; i < media.length; i++) {
        final item = media[i];
        if (item['fileId'] != null && item['value'] == null) {
          try {
            if (kIsWeb) {
              final response = await storage.getFileView(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              final file = await storage.getFile(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              final mimeType = _getMimeType(file.name);
              media[i]['value'] =
                  "data:$mimeType;base64,${base64Encode(response)}";
            } else {
              final url = await storage.getFileDownload(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              media[i]['value'] = url.toString();
            }
          } catch (e) {
            debugPrint('Error loading file ${item['fileId']}: $e');
            media[i]['hasError'] = true;
          }
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error in _loadMediaData: $e');
    }
  }

  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _addMedia(String type) async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      final fileName = file.name;

      final uploadedFile = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: fileName,
        ),
      );

      if (kIsWeb) {
        final mimeType = _getMimeType(fileName);
        setState(() {
          media.add({
            'type': type,
            'fileId': uploadedFile.$id,
            'value': "data:$mimeType;base64,${base64Encode(bytes)}",
            'position': const Offset(50, 50),
            'width': MediaQuery.of(context).size.width < 600 ? 200.0 : 300.0,
            'height': MediaQuery.of(context).size.width < 600 ? 266.0 : 400.0,
          });
        });
      } else {
        setState(() {
          media.add({
            'type': type,
            'fileId': uploadedFile.$id,
            'position': const Offset(50, 50),
            'width': MediaQuery.of(context).size.width < 600 ? 200.0 : 300.0,
            'height': MediaQuery.of(context).size.width < 600 ? 266.0 : 400.0,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add media: ${e.toString()}', style: TextStyle(fontFamily: 'Josefin Sans')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      debugPrint('Failed to add media: $e');
    }
  }

  void _addText(Offset position) {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Text", style: TextStyle(fontFamily: 'Josefin Sans')),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
          style: TextStyle(fontFamily: 'Josefin Sans'),
          decoration: const InputDecoration(
            hintText: "Type something...",
            hintStyle: TextStyle(fontFamily: 'Josefin Sans'),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(fontFamily: 'Josefin Sans')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("OK", style: TextStyle(fontFamily: 'Josefin Sans')),
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
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Text', style: TextStyle(fontFamily: 'Josefin Sans')),
              onTap: () {
                Navigator.pop(context);
                setState(() => isAddingText = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Text Color', style: TextStyle(fontFamily: 'Josefin Sans')),
              onTap: () {
                Navigator.pop(context);
                _showTextColorPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image', style: TextStyle(fontFamily: 'Josefin Sans')),
              onTap: () {
                Navigator.pop(context);
                _addMedia('image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: const Text('Audio', style: TextStyle(fontFamily: 'Josefin Sans')),
              onTap: () {
                Navigator.pop(context);
                _addAudio();
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_paint),
              title: const Text('Background Color', style: TextStyle(fontFamily: 'Josefin Sans')),
              onTap: () {
                Navigator.pop(context);
                _changeBackgroundColor();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTextColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Text Color", style: TextStyle(fontFamily: 'Josefin Sans')),
        content: BlockPicker(
          pickerColor: selectedTextColor,
          onColorChanged: (color) => setState(() => selectedTextColor = color),
        ),
        actions: [
          TextButton(
            child: const Text("Done", style: TextStyle(fontFamily: 'Josefin Sans')),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _changeBackgroundColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Background Color", style: TextStyle(fontFamily: 'Josefin Sans')),
        content: BlockPicker(
          pickerColor: backgroundColor,
          onColorChanged: (color) => setState(() => backgroundColor = color),
        ),
        actions: [
          TextButton(
            child: const Text("Done", style: TextStyle(fontFamily: 'Josefin Sans')),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.pageName, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Josefin Sans')),
            if (selectedLocation != null && !isMobile)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('Location: $selectedLocation',
                    style: const TextStyle(fontSize: 14, fontFamily: 'Josefin Sans')),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveContent,
            tooltip: 'Save',
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () async {
              final location = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationPage(
                    userId: widget.userId,
                    databases: databases,
                    existingLocations:
                        selectedLocation != null ? [selectedLocation!] : [],
                  ),
                ),
              );

              if (location != null && mounted) {
                setState(() {
                  selectedLocation = location;
                  isSavingLocation = true;
                });

                try {
                  await _saveContent();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Location saved successfully!', style: TextStyle(fontFamily: 'Josefin Sans'))),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save location: $e', style: TextStyle(fontFamily: 'Josefin Sans'))),
                    );
                  }
                } finally {
                  if (mounted) setState(() => isSavingLocation = false);
                }
              }
            },
            tooltip: 'Location',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double contentHeight = [
            constraints.maxHeight,
            100.0 + (textDataList.length * 30.0),
            media.fold(0.0,
                (sum, item) => sum + (item['height'] as double? ?? 0.0) + 20.0),
          ].reduce(max);

          return SingleChildScrollView(
            child: Container(
              height: contentHeight,
              child: GestureDetector(
                  onTap: () {
                    if (isAddingText) {
                      final renderBox = context.findRenderObject() as RenderBox;
                      final tapPosition = renderBox.globalToLocal(
                        (context.findRenderObject() as RenderBox)
                            .localToGlobal(Offset.zero),
                      );
                      _addText(tapPosition);
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        color: backgroundColor,
                        height: contentHeight,
                      ),
                      ..._buildDraggableElements(isMobile),
                      ..._buildAudioPlayers(),
                    ],
                  )),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        mini: isMobile,
        onPressed: _showOptionsMenu,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  List<Widget> _buildDraggableElements(bool isMobile) {
    final elements = <Widget>[];

    final screenHeight = MediaQuery.of(context).size.height;
    final textHeight = 100.0 + (textDataList.length * 30.0);
    final mediaHeight = media.fold(
        0.0, (sum, item) => sum + (item['height'] as double? ?? 0.0) + 20.0);
    final contentHeight = [screenHeight, textHeight, mediaHeight].reduce(max);

    for (var textData in textDataList) {
      elements.add(
        Positioned(
          left: textData.position.dx,
          top: min<double>(textData.position.dy, contentHeight - 30),
          child: _buildDraggableText(textData, isMobile, contentHeight),
        ),
      );
    }

    for (int i = 0; i < media.length; i++) {
      final mediaItem = media[i];
      final itemHeight =
          (mediaItem['height'] as double? ?? (isMobile ? 266.0 : 400.0));

      elements.add(
        Positioned(
          left: mediaItem['position'].dx,
          top:
              min<double>(mediaItem['position'].dy, contentHeight - itemHeight),
          child: DraggableImage(
            key: ValueKey('image_${mediaItem['fileId']}_$i'),
            mediaItem: mediaItem,
            onPositionChanged: (updatedItem) =>
                setState(() => media[i] = updatedItem),
            onDelete: () => setState(() => media.removeAt(i)),
            isMobile: isMobile,
            maxHeight: contentHeight,
          ),
        ),
      );
    }

    return elements;
  }

  Widget _buildDraggableText(
      TextData textData, bool isMobile, double contentHeight) {
    return Draggable(
      feedback: Material(
        child: Text(
          textData.text,
          style: TextStyle(
            fontFamily: textData.font,
            color: textData.color,
            fontSize: isMobile ? 18 : 24,
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragEnd: (details) => setState(() {
        textData.position = Offset(
          details.offset.dx,
          min<double>(details.offset.dy, contentHeight - 30),
        );
      }),
      child: GestureDetector(
        onLongPress: () => _showTextOptions(textData),
        child: Text(
          textData.text,
          style: TextStyle(
            fontFamily: textData.font,
            color: textData.color,
            fontSize: isMobile ? 18 : 24,
          ),
        ),
      ),
    );
  }

  void _showTextOptions(TextData textData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Text', style: TextStyle(fontFamily: 'Josefin Sans')),
            onTap: () {
              Navigator.pop(context);
              _editText(textData);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete', style: TextStyle(fontFamily: 'Josefin Sans')),
            onTap: () {
              setState(() {
                textDataList.remove(textData);
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Change Color', style: TextStyle(fontFamily: 'Josefin Sans')),
            onTap: () {
              Navigator.pop(context);
              _changeTextColor(textData);
            },
          ),
        ],
      ),
    );
  }

  void _editText(TextData textData) {
    final TextEditingController _textController =
        TextEditingController(text: textData.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Text", style: TextStyle(fontFamily: 'Josefin Sans')),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
          style: TextStyle(fontFamily: 'Josefin Sans'),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(fontFamily: 'Josefin Sans')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Save", style: TextStyle(fontFamily: 'Josefin Sans')),
            onPressed: () {
              final newText = _textController.text.trim();
              if (newText.isNotEmpty) {
                setState(() {
                  textData.text = newText;
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _changeTextColor(TextData textData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Text Color", style: TextStyle(fontFamily: 'Josefin Sans')),
        content: BlockPicker(
          pickerColor: textData.color,
          onColorChanged: (color) => setState(() => textData.color = color),
        ),
        actions: [
          TextButton(
            child: const Text("Done", style: TextStyle(fontFamily: 'Josefin Sans')),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

Color _parseBackgroundColor(dynamic bgColor) {
  if (bgColor == null) return Colors.white;
  if (bgColor is int) return Color(bgColor);
  if (bgColor is String) {
    return Color(int.tryParse(bgColor) ?? Colors.white.value);
  }
  return Colors.white;
}

String? _parseLocation(Map<String, dynamic> data) {
  if (data['location'] is String) return data['location'];
  if (data['locations'] is String) return data['locations'];
  return null;
}

class TextData {
  String text;
  String font;
  Color color;
  Offset position;

  TextData({
    required this.text,
    required this.font,
    required this.color,
    required this.position,
  });

  factory TextData.fromJson(Map<String, dynamic> json) {
    final positionData = json['position'] is Map
        ? Map<String, dynamic>.from(json['position'])
        : {'dx': 50, 'dy': 50};

    return TextData(
      text: json['text']?.toString() ?? '',
      font: json['font']?.toString() ?? 'Delius Swash Caps',
      color: Color(json['color'] is int ? json['color'] : Colors.black.value),
      position: Offset(
        (positionData['dx'] ?? 50).toDouble(),
        (positionData['dy'] ?? 50).toDouble(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'font': font,
        'color': color.value,
        'position': {'dx': position.dx, 'dy': position.dy},
      };
}

class DraggableImage extends StatefulWidget {
  final Map<String, dynamic> mediaItem;
  final Function(Map<String, dynamic>) onPositionChanged;
  final Function() onDelete;
  final bool isMobile;
  final double maxHeight;

  const DraggableImage({
    super.key,
    required this.mediaItem,
    required this.onPositionChanged,
    required this.onDelete,
    required this.isMobile,
    required this.maxHeight,
  });

  @override
  State<DraggableImage> createState() => _DraggableImageState();
}

class _DraggableImageState extends State<DraggableImage> {
  bool _isHovering = false;
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;
  bool _isLoading = true;
  bool _hasError = false;
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.mediaItem['value'] ?? '';
    _validateImageUrl();
  }

  void _validateImageUrl() {
    if (_imageUrl.isEmpty) {
      _hasError = true;
      _isLoading = false;
    } else if (!_imageUrl.startsWith('http') &&
        !_imageUrl.startsWith('data:image')) {
      _hasError = true;
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.mediaItem['position'] ?? const Offset(50, 50);
    final baseWidth = widget.mediaItem['width']?.toDouble() ??
        (widget.isMobile ? 200.0 : 300.0);
    final baseHeight = widget.mediaItem['height']?.toDouble() ??
        (widget.isMobile ? 266.0 : 400.0);

    final topPosition = min<double>(
      (position.dy + _panOffset.dy).toDouble(),
      (widget.maxHeight - baseHeight * _scale).toDouble(),
    );

    return Positioned(
      left: position.dx + _panOffset.dx,
      top: topPosition,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isHovering = !_isHovering),
        onDoubleTap: _handleDoubleTap,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        child: Transform.scale(
          scale: _scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: baseWidth,
                height: baseHeight,
                decoration: BoxDecoration(
                  border: _isHovering
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: _buildImageContent(baseWidth, baseHeight),
              ),
              if (_isHovering) _buildDeleteButton(),
              if (_isLoading && !_hasError)
                Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(double width, double height) {
    if (widget.mediaItem['hasError'] == true) {
      return _buildErrorPlaceholder(width, height);
    }

    final imageUrl = widget.mediaItem['value'] ?? '';

    if (imageUrl.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(imageUrl.split(',').last),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildErrorPlaceholder(width, height),
        );
      } catch (e) {
        return _buildErrorPlaceholder(width, height);
      }
    } else if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(width, height),
      );
    } else if (widget.mediaItem['fileId'] != null) {
      return Center(child: CircularProgressIndicator());
    }

    return _buildErrorPlaceholder(width, height);
  }

  Widget _buildDeleteButton() {
    return Positioned(
      right: 8,
      top: 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, size: 40),
          SizedBox(height: 8),
          Text('Failed to load image', style: TextStyle(fontSize: 12, fontFamily: 'Josefin Sans')),
        ],
      ),
    );
  }

  void _handleDoubleTap() {
    setState(() {
      _scale = _scale == 1.0 ? 2.0 : 1.0;
      _updateMediaItem();
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    setState(() => _isHovering = false);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (details.scale * _scale).clamp(0.5, 3.0);
      _panOffset += details.focalPointDelta;
      _updateMediaItem();
    });
  }

  void _handleScaleEnd(ScaleEndDetails _) {
    widget.onPositionChanged({
      ...widget.mediaItem,
      'position': Offset(
        (widget.mediaItem['position']?.dx ?? 50) + _panOffset.dx,
        (widget.mediaItem['position']?.dy ?? 50) + _panOffset.dy,
      ),
      'width':
          (widget.mediaItem['width'] ?? (widget.isMobile ? 200.0 : 300.0)) *
              _scale,
      'height':
          (widget.mediaItem['height'] ?? (widget.isMobile ? 266.0 : 400.0)) *
              _scale,
    });
    _panOffset = Offset.zero;
  }

  void _updateMediaItem() {
    widget.onPositionChanged({
      ...widget.mediaItem,
      'width':
          (widget.mediaItem['width'] ?? (widget.isMobile ? 200.0 : 300.0)) *
              _scale,
      'height':
          (widget.mediaItem['height'] ?? (widget.isMobile ? 266.0 : 400.0)) *
              _scale,
    });
  }
}