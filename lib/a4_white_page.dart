import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:appwrite/appwrite.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:convert';
import 'audio_page.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:math';

final String bucketId =
    '67cd36510039f3d96c62'; // Add this near the top of your file

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

  late YoutubePlayerController _ytController;
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(50);
  bool isAudioPlaying = false;

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
    _loadSavedContent();
    textDataList = [];
  }

  @override
  void dispose() {
    _ytController.dispose();
    _volumeNotifier.dispose();
    super.dispose();
  }

  Future<void> _addAudio() async {
    final videoId = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AudioPage()),
    );

    if (videoId != null && mounted) {
      _playAudio(videoId);
    }
  }

  Future<void> _playAudio(String videoId) async {
    try {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          hideControls: true,
        ),
      );

      if (mounted) {
        setState(() {
          isAudioPlaying = true;
        });
        _ytController.setVolume(_volumeNotifier.value.round());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing player: $e')),
        );
      }
    }
  }

  String _generateShortHash(String input) {
    // Create a quick hash from the input string
    final hash = input.hashCode;

    // Convert to a base36 string (0-9a-z) for compact representation
    final base36 = hash.toRadixString(36);

    // Take the last 6 characters (or full string if shorter)
    return base36.length <= 6 ? base36 : base36.substring(base36.length - 6);
  }

  Future<void> _saveContent() async {
    try {
      // Prepare text data for saving in compact format
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
        'media': media.map((m) => m['fileId'] ?? '').toList(),
        'textData': jsonEncode(textDataToSave), // Save as JSON string
        'location': selectedLocation ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await databases.updateDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
        data: documentData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

// Safe string truncation helper
  String _safeTruncate(String input, int maxLength) {
    if (input.length <= maxLength) return input;
    return input.substring(0, maxLength);
  }

// Modified text compression to prevent errors
  String _compressTextData(List<TextData> texts) {
    final compressed = texts
        .map((t) => [
              _safeTruncate(t.text, 20),
              t.font.isNotEmpty ? t.font.substring(0, 1) : '',
              t.color.value,
              t.position.dx.toInt(),
              t.position.dy.toInt(),
            ])
        .toList();
    return jsonEncode(compressed);
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

        // Initialize textDataList as empty list first
        textDataList = [];

        // Load text data - handle both string and direct list formats
        if (data['textData'] != null) {
          try {
            if (data['textData'] is String) {
              // Parse from JSON string
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
              // Parse from direct list
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

        // Load media
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
          SnackBar(content: Text('Error loading content: $e')),
        );
      }
    }
  }

  Widget _buildAudioPlayer() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 1,
                  child: YoutubePlayer(
                    controller: _ytController,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(_ytController.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow),
                    onPressed: _ytController.value.isPlaying
                        ? _ytController.pause
                        : _ytController.play,
                  ),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _volumeNotifier,
                      builder: (context, volume, _) {
                        return Slider(
                          value: volume,
                          min: 0,
                          max: 100,
                          onChanged: (value) {
                            _volumeNotifier.value = value;
                            _ytController.setVolume(value.round());
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _volumeNotifier,
                    builder: (context, volume, _) {
                      return Text('${volume.round()}%');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMediaData() async {
    try {
      for (int i = 0; i < media.length; i++) {
        final item = media[i];
        if (item['fileId'] != null && item['value'] == null) {
          try {
            if (kIsWeb) {
              // For web, we get Uint8List directly
              final response = await storage.getFileView(
                bucketId: bucketId,
                fileId: item['fileId'],
              );

              // Get file extension from metadata
              final file = await storage.getFile(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              final mimeType = _getMimeType(file.name);
              media[i]['value'] =
                  "data:$mimeType;base64,${base64Encode(response)}";
            } else {
              // For mobile, we can get the download URL
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

      // Upload to Appwrite Storage
      final uploadedFile = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: fileName,
        ), // Removed mimeType parameter
      );

      // For web, create data URL immediately
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
        // For mobile, we'll load the URL when needed
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
            content: Text('Failed to add media: ${e.toString()}'),
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
            onPressed: () => Navigator.pop(context),
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
              title: const Text('Text'),
              onTap: () {
                Navigator.pop(context);
                setState(() => isAddingText = true);
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
              leading: const Icon(Icons.audiotrack),
              title: const Text('Audio'),
              onTap: () {
                Navigator.pop(context);
                _addAudio();
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
          onColorChanged: (color) => setState(() => selectedTextColor = color),
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

  void _changeBackgroundColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Background Color"),
        content: BlockPicker(
          pickerColor: backgroundColor,
          onColorChanged: (color) => setState(() => backgroundColor = color),
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

  @override
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.pageName, overflow: TextOverflow.ellipsis),
            if (selectedLocation != null && !isMobile)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('Location: $selectedLocation',
                    style: const TextStyle(fontSize: 14)),
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
                MaterialPageRoute(builder: (context) => LocationPage()),
              );
              if (location != null && mounted) {
                setState(() => selectedLocation = location['address']);
              }
            },
            tooltip: 'Location',
          ),
        ],
      ),
      body: GestureDetector(
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
            Container(color: backgroundColor),

            // Stack all draggable elements
            ..._buildDraggableElements(isMobile),

            if (isAudioPlaying) _buildAudioPlayer(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: isMobile,
        onPressed: _showOptionsMenu,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  // New method to build all draggable elements
  List<Widget> _buildDraggableElements(bool isMobile) {
    final elements = <Widget>[];
    double verticalOffset = 20.0; // Initial vertical position

    // Add text elements
    for (var textData in textDataList) {
      elements.add(
        Positioned(
          left: textData.position.dx,
          top: textData.position.dy,
          child: Draggable(
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
            onDragEnd: (details) {
              setState(() {
                textData.position = details.offset;
              });
            },
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
          ),
        ),
      );
      verticalOffset += 30; // Space between elements
    }

    // Add image elements
    for (int i = 0; i < media.length; i++) {
      final mediaItem = media[i];
      elements.add(
        Positioned(
          left: mediaItem['position'].dx,
          top: mediaItem['position'].dy,
          child: DraggableImage(
            key: ValueKey('image_${mediaItem['fileId']}_$i'),
            mediaItem: mediaItem,
            onPositionChanged: (updatedItem) {
              setState(() {
                media[i] = updatedItem;
              });
            },
            onDelete: () {
              setState(() {
                media.removeAt(i);
              });
            },
            isMobile: isMobile,
          ),
        ),
      );
      verticalOffset += mediaItem['height'] + 20; // Space after image
    }

    return elements;
  }

  // New method to show text editing options
  void _showTextOptions(TextData textData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Text'),
            onTap: () {
              Navigator.pop(context);
              _editText(textData);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              setState(() {
                textDataList.remove(textData);
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Change Color'),
            onTap: () {
              Navigator.pop(context);
              _changeTextColor(textData);
            },
          ),
        ],
      ),
    );
  }

  // New method to edit existing text
  void _editText(TextData textData) {
    final TextEditingController _textController =
        TextEditingController(text: textData.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Text"),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Save"),
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

  // New method to change text color
  void _changeTextColor(TextData textData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Text Color"),
        content: BlockPicker(
          pickerColor: textData.color,
          onColorChanged: (color) => setState(() => textData.color = color),
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
}

class LocationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, {'address': '123 Main St, City, Country'}),
          child: const Text('Select Location'),
        ),
      ),
    );
  }
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
// Add these methods to your _A4WhitePageState class

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

class DraggableImage extends StatefulWidget {
  final Map<String, dynamic> mediaItem;
  final Function(Map<String, dynamic>) onPositionChanged;
  final Function() onDelete;
  final bool isMobile;

  const DraggableImage({
    super.key,
    required this.mediaItem,
    required this.onPositionChanged,
    required this.onDelete,
    required this.isMobile,
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

    return Positioned(
      left: position.dx + _panOffset.dx,
      top: position.dy + _panOffset.dy,
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
      // If we have a fileId but no URL yet, show loading
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
          Text('Failed to load image', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Uint8List _decodeBase64(String base64String) {
    try {
      final String data = base64String.split(',').last;
      return base64.decode(data);
    } catch (e) {
      debugPrint('Base64 decode error: $e');
      return Uint8List(0); // Return empty bytes to trigger error builder
    }
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
