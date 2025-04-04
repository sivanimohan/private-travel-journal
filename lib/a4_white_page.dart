import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:math';
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
  List<Map<String, dynamic>> contentItems = [];
  String? selectedLocation;
  Color backgroundColor = Colors.white;
  late Databases databases;
  late Storage storage;
  final ImagePicker _picker = ImagePicker();
  bool isSaving = false;
  bool isSavingLocation = false;

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
    storage = Storage(widget.client);
    _loadSavedContent();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveContent() async {
    try {
      setState(() => isSavingLocation = true);
      final contentDataToSave = jsonEncode(contentItems.map((item) {
        return {
          'fileId': item['fileId'],
          'text': item['text'],
          'textColor': item['textColor'].value,
          'position': {'dx': item['position'].dx, 'dy': item['position'].dy},
          'width': item['width'],
          'height': item['height'],
        };
      }).toList());

      final documentData = {
        'pageId': widget.pageId,
        'userId': widget.userId,
        'folderId': widget.folderId,
        'pageName': widget.pageName,
        'backgroundColor': backgroundColor.value,
        'textData': contentDataToSave,
        'location': selectedLocation ?? '',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'datetime': null,
      };

      await databases.updateDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab72f0030b02f1623',
        documentId: widget.pageId,
        data: documentData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content saved successfully!',
                style: TextStyle(fontFamily: 'JosefinSans')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e',
                style: TextStyle(fontFamily: 'JosefinSans')),
          ),
        );
      }
      debugPrint('Error saving content: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => isSavingLocation = false);
    }
  }

  Future<void> _loadSavedContent() async {
    try {
      final doc = await databases.getDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab72f0030b02f1623',
        documentId: widget.pageId,
      );

      final data = doc.data;
      debugPrint('Loaded document data: $data');

      setState(() {
        backgroundColor = _parseBackgroundColor(data['backgroundColor']);
        selectedLocation = _parseLocation(data);
        contentItems = [];

        if (data['textData'] != null && data['textData'] is String) {
          try {
            final decoded = jsonDecode(data['textData']) as List<dynamic>;
            debugPrint('Decoded textData: $decoded');
            contentItems = decoded.map((item) {
              final positionData = item['position'] is Map
                  ? Map<String, dynamic>.from(item['position'])
                  : {'dx': 20, 'dy': 20};
              return {
                'fileId': item['fileId']?.toString() ?? '',
                'text': item['text']?.toString() ?? '',
                'textColor': Color(item['textColor'] is int
                    ? item['textColor']
                    : Colors.black.value),
                'position': Offset(
                  (positionData['dx'] ?? 20).toDouble(),
                  (positionData['dy'] ?? 20).toDouble(),
                ),
                'width': (item['width'] ??
                        (MediaQuery.of(context).size.width < 600
                            ? 200.0
                            : 300.0))
                    .toDouble(),
                'height': (item['height'] ??
                        (MediaQuery.of(context).size.width < 600
                            ? 266.0
                            : 400.0))
                    .toDouble(),
                'value': null, // Will be populated by _loadMediaData
              };
            }).toList();
          } catch (e) {
            debugPrint('Error decoding contentData: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to parse content data: $e',
                    style: TextStyle(fontFamily: 'JosefinSans')),
              ),
            );
          }
        } else {
          debugPrint('No contentData found or not a string');
        }
      });

      await _loadMediaData();
    } catch (e) {
      debugPrint('Error loading content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading content: $e',
                style: TextStyle(fontFamily: 'JosefinSans')),
          ),
        );
      }
    }
  }

  Future<void> _loadMediaData() async {
    try {
      for (int i = 0; i < contentItems.length; i++) {
        final item = contentItems[i];
        if (item['fileId'] != null &&
            item['fileId'].isNotEmpty &&
            item['value'] == null) {
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
              setState(() {
                contentItems[i]['value'] =
                    "data:$mimeType;base64,${base64Encode(response)}";
              });
              debugPrint('Loaded media for fileId ${item['fileId']} (web)');
            } else {
              final url = await storage.getFileDownload(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              setState(() {
                contentItems[i]['value'] = url.toString();
              });
              debugPrint('Loaded media for fileId ${item['fileId']} (non-web)');
            }
          } catch (e) {
            debugPrint('Error loading file ${item['fileId']}: $e');
            setState(() {
              contentItems[i]['hasError'] = true;
            });
          }
        } else {
          debugPrint('Skipping media load for item $i: ${item['fileId']}');
        }
      }
    } catch (e) {
      debugPrint('Error in _loadMediaData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading media: ${e.toString()}',
                style: TextStyle(fontFamily: 'Josefin Sans')),
          ),
        );
      }
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

  double _getNextVerticalPosition() {
    double lastY = 20.0;

    if (contentItems.isNotEmpty) {
      final lastItem = contentItems.last;
      final imageHeight = lastItem['height'] as double;
      final textPainter = TextPainter(
        text: TextSpan(
          text: lastItem['text'],
          style: TextStyle(
            fontFamily: 'DeliciousHandrawn',
            fontSize: 28,
            color: lastItem['textColor'],
          ),
        ),
        maxLines: null,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: MediaQuery.of(context).size.width - 40);

      lastY = lastItem['position'].dy + imageHeight + textPainter.height + 10;
    }

    debugPrint('Next Y position: $lastY');
    return lastY;
  }

  Future<void> _addMedia(String type) async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      final fileName = file.name;
      final fileId = ID.unique();

      final uploadedFile = await storage.createFile(
        bucketId: bucketId,
        fileId: fileId,
        file: InputFile.fromBytes(bytes: bytes, filename: fileName),
      );

      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;
      final width = isMobile ? screenWidth * 0.8 : 300.0;
      final height = isMobile ? width * 4 / 3 : 400.0;

      final nextY = _getNextVerticalPosition();

      final TextEditingController _textController = TextEditingController();
      Color textColor = Colors.black;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Add Text for Image",
              style: TextStyle(fontFamily: 'JosefinSans')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: null,
                style: TextStyle(fontFamily: 'DeliciousHandrawn', fontSize: 28),
                decoration: const InputDecoration(
                  hintText: "Type something...",
                  hintStyle: TextStyle(fontFamily: 'JosefinSans'),
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Choose Text Color",
                          style: TextStyle(fontFamily: 'JosefinSans')),
                      content: BlockPicker(
                        pickerColor: textColor,
                        onColorChanged: (color) => textColor = color,
                      ),
                      actions: [
                        TextButton(
                          child: const Text("Done",
                              style: TextStyle(fontFamily: 'JosefinSans')),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                  if (mounted) setState(() {});
                },
                child: const Text("Pick Text Color",
                    style: TextStyle(fontFamily: 'JosefinSans')),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel",
                  style: TextStyle(fontFamily: 'JosefinSans')),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child:
                  const Text("OK", style: TextStyle(fontFamily: 'JosefinSans')),
              onPressed: () {
                final text = _textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      );

      final text = _textController.text.trim();
      if (text.isEmpty || !mounted) return;

      setState(() {
        contentItems.add({
          'type': 'image',
          'fileId': uploadedFile.$id,
          'value': type == 'image' && kIsWeb
              ? "data:${_getMimeType(fileName)};base64,${base64Encode(bytes)}"
              : null,
          'text': text,
          'textColor': textColor,
          'position': Offset(20, nextY),
          'width': width,
          'height': height,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add image: ${e.toString()}',
              style: TextStyle(fontFamily: 'Josefin Sans'),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      debugPrint('Failed to add media: $e');
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.image, color: Colors.green),
                title: Text('Add Image',
                    style: TextStyle(fontFamily: 'Josefin Sans', fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _addMedia('image');
                },
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.format_paint, color: Colors.teal),
                title: Text('Background Color',
                    style: TextStyle(fontFamily: 'Josefin Sans', fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _changeBackgroundColor();
                },
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  void _changeBackgroundColor() {
    final List<Color> colors = [
      Colors.white,
      Color(0xFFE8C8B8),
      Color(0xFF6EE7F2),
      Color(0xFFFF8FAB),
      Color(0xFFE6E6FA),
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Color(0xFFB5EAD7),
      Color(0xFFEFCFE3),
      Color(0xFFF7A399),
      Color(0xFFFFDAC1),
      Color(0xFFD4B8A8),
      Color(0xFFB38B6D),
      Colors.brown,
      Colors.grey,
      Colors.black,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Background Color",
            style: TextStyle(fontFamily: 'JosefinSans')),
        content: BlockPicker(
          pickerColor: backgroundColor,
          availableColors: colors,
          onColorChanged: (color) => setState(() => backgroundColor = color),
        ),
        actions: [
          TextButton(
            child:
                const Text("Done", style: TextStyle(fontFamily: 'JosefinSans')),
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
        backgroundColor: Color(0xFFE5D5C3),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.pageName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'JosefinSans'),
              ),
            ),
            if (selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'Location: $selectedLocation',
                  style:
                      const TextStyle(fontSize: 14, fontFamily: 'JosefinSans'),
                  overflow: TextOverflow.ellipsis,
                ),
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
                          content: Text('Location saved successfully!',
                              style: TextStyle(fontFamily: 'JosefinSans'))),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to save location: $e',
                              style: TextStyle(fontFamily: 'JosefinSans'))),
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
            100.0 + (contentItems.length * 450.0),
          ].reduce(max);

          return SingleChildScrollView(
            child: Container(
              height: contentHeight,
              child: Stack(
                children: [
                  Container(
                    color: backgroundColor,
                    height: contentHeight,
                  ),
                  ..._buildDraggableElements(isMobile),
                ],
              ),
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
    final contentHeight = [
      MediaQuery.of(context).size.height,
      100.0 + (contentItems.length * 450.0),
    ].reduce(max);

    for (int i = 0; i < contentItems.length; i++) {
      final item = contentItems[i];
      final totalHeight = (item['height'] as double) + 28;

      elements.add(
        Positioned(
          left: item['position'].dx,
          top: min<double>(item['position'].dy, contentHeight - totalHeight),
          child: ImageTextPair(
            key: ValueKey('pair_${item['fileId']}_$i'),
            item: item,
            onPositionChanged: (updatedItem) =>
                setState(() => contentItems[i] = updatedItem),
            onDelete: () => setState(() => contentItems.removeAt(i)),
            isMobile: isMobile,
            maxHeight: contentHeight,
          ),
        ),
      );
    }

    return elements;
  }
}

Color _parseBackgroundColor(dynamic bgColor) {
  if (bgColor == null) return Colors.white;
  if (bgColor is int) return Color(bgColor);
  if (bgColor is String)
    return Color(int.tryParse(bgColor) ?? Colors.white.value);
  return Colors.white;
}

String? _parseLocation(Map<String, dynamic> data) {
  if (data['location'] is String) return data['location'];
  if (data['locations'] is String) return data['locations'];
  return null;
}

class ImageTextPair extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(Map<String, dynamic>) onPositionChanged;
  final Function() onDelete;
  final bool isMobile;
  final double maxHeight;

  const ImageTextPair({
    super.key,
    required this.item,
    required this.onPositionChanged,
    required this.onDelete,
    required this.isMobile,
    required this.maxHeight,
  });

  @override
  State<ImageTextPair> createState() => _ImageTextPairState();
}

class _ImageTextPairState extends State<ImageTextPair> {
  bool _isHovering = false;
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _validateMediaUrl();
  }

  void _validateMediaUrl() {
    final mediaUrl = widget.item['value'] ?? '';
    if (mediaUrl.isEmpty) {
      _hasError = true;
      _isLoading = false;
    } else if (!mediaUrl.startsWith('http') &&
        !mediaUrl.startsWith('data:image')) {
      _hasError = true;
      _isLoading = false;
    } else {
      _isLoading = false; // Assume loaded if value exists
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.item['position'] ?? const Offset(20, 20);
    final baseWidth =
        widget.item['width']?.toDouble() ?? (widget.isMobile ? 200.0 : 300.0);
    final baseHeight =
        widget.item['height']?.toDouble() ?? (widget.isMobile ? 266.0 : 400.0);
    final text = widget.item['text'] ?? '';
    final textColor = widget.item['textColor'] ?? Colors.black;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'DeliciousHandrawn',
          fontSize: 28,
          color: textColor,
        ),
      ),
      maxLines: null,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: baseWidth);

    final totalHeight = baseHeight + textPainter.height;

    final topPosition = min<double>(
      (position.dy + _panOffset.dy).toDouble(),
      (widget.maxHeight - totalHeight * _scale).toDouble(),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  SizedBox(height: 5),
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'DeliciousHandrawn',
                      fontSize: 28,
                      color: textColor,
                    ),
                    maxLines: null,
                  ),
                ],
              ),
              if (_isHovering) _buildDeleteButton(baseWidth),
              if (_isLoading && !_hasError)
                Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(double width, double height) {
    if (widget.item['hasError'] == true) {
      return _buildErrorPlaceholder(width, height);
    }

    final mediaUrl = widget.item['value'] ?? '';

    if (mediaUrl.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(mediaUrl.split(',').last),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildErrorPlaceholder(width, height),
        );
      } catch (e) {
        return _buildErrorPlaceholder(width, height);
      }
    } else if (mediaUrl.startsWith('http')) {
      return Image.network(
        mediaUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) {
            _isLoading = false;
            return child;
          }
          return Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(width, height),
      );
    } else if (widget.item['fileId'] != null && mediaUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Loading media...',
                style: TextStyle(fontFamily: 'Josefin Sans', fontSize: 12)),
          ],
        ),
      );
    }

    return _buildErrorPlaceholder(width, height);
  }

  Widget _buildDeleteButton(double width) {
    return Positioned(
      right: 8,
      top: 8,
      child: GestureDetector(
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
          Text('Failed to load media',
              style: TextStyle(fontSize: 12, fontFamily: 'Josefin Sans')),
        ],
      ),
    );
  }

  void _handleDoubleTap() {
    setState(() {
      _scale = _scale == 1.0 ? 2.0 : 1.0;
      _updateItem();
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    setState(() => _isHovering = false);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (details.scale * _scale).clamp(0.5, 3.0);
      _panOffset += details.focalPointDelta;
      _updateItem();
    });
  }

  void _handleScaleEnd(ScaleEndDetails _) {
    setState(() {
      widget.onPositionChanged({
        ...widget.item,
        'position': Offset(
          (widget.item['position']?.dx ?? 20) + _panOffset.dx,
          (widget.item['position']?.dy ?? 20) + _panOffset.dy,
        ),
        'width': (widget.item['width'] ?? (widget.isMobile ? 200.0 : 300.0)) *
            _scale,
        'height': (widget.item['height'] ?? (widget.isMobile ? 266.0 : 400.0)) *
            _scale,
      });
      _panOffset = Offset.zero;
    });
  }

  void _updateItem() {
    widget.onPositionChanged({
      ...widget.item,
      'width':
          (widget.item['width'] ?? (widget.isMobile ? 200.0 : 300.0)) * _scale,
      'height':
          (widget.item['height'] ?? (widget.isMobile ? 266.0 : 400.0)) * _scale,
    });
  }
}
