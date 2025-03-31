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
  List<Map<String, dynamic>> media = [];
  String? selectedLocation;
  Color backgroundColor = Colors.white;
  late Databases databases;
  late Storage storage;
  final ImagePicker _picker = ImagePicker();
  bool isSaving = false;
  bool isSavingLocation = false;
  List<String> locations = [];

  // Text input
  List<TextData> textDataList = [];
  bool isAddingText = false;
  String selectedFont = 'DeliciousHandrawn';
  Color selectedTextColor = Colors.black;
  List<String> fonts = [
    'DeliciousHandrawn',
    'JosefinSans',
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
    super.dispose();
  }

  Future<void> _saveContent() async {
    try {
      setState(() => isSavingLocation = true);
      final textDataToSave = jsonEncode(textDataList.map((text) {
        return {
          'text': text.text,
          'font': text.font,
          'color': text.color.value,
          'position': {'dx': text.position.dx, 'dy': text.position.dy},
          'size': text.size,
        };
      }).toList());

      final mediaDataToSave = media.map((m) => m['fileId'] as String).toList();

      final documentData = {
        'pageId': widget.pageId,
        'userId': widget.userId,
        'folderId': widget.folderId,
        'pageName': widget.pageName,
        'backgroundColor': backgroundColor.value,
        'media': mediaDataToSave,
        'textData': textDataToSave,
        'location': selectedLocation ?? '',
        'updatedAt':
            DateTime.now().toUtc().toIso8601String(), // Use 'updatedAt'
        'datetime': null, // Clear 'datetime' to avoid schema conflict
      };

      debugPrint('Saving document: ${jsonEncode(documentData)}');

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
      setState(() {
        backgroundColor = _parseBackgroundColor(data['backgroundColor']);
        selectedLocation = _parseLocation(data);
        textDataList = [];

        if (data['textData'] != null) {
          try {
            final decoded = jsonDecode(data['textData'] as String) as List;
            textDataList = decoded.map((item) {
              return TextData(
                text: item['text'] ?? '',
                font: item['font'] ?? 'DeliciousHandrawn',
                color: Color(item['color'] ?? Colors.black.value),
                position: Offset(
                  (item['position']['dx'] ?? 50).toDouble(),
                  (item['position']['dy'] ?? 50).toDouble(),
                ),
                size: (item['size'] ?? 28).toDouble(),
              );
            }).toList();
          } catch (e) {
            debugPrint('Error parsing text data: $e');
          }
        }

        media = (data['media'] as List<dynamic>? ?? []).map((fileId) {
          return {
            'type': 'image',
            'fileId': fileId,
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
          SnackBar(
              content: Text('Error loading content: $e',
                  style: TextStyle(fontFamily: 'JosefinSans'))),
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
              // Load file for web
              final response = await storage.getFileView(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              final file = await storage.getFile(
                bucketId: bucketId,
                fileId: item['fileId'],
              );
              final mimeType = _getMimeType(file.name);

              // Set media value for web
              media[i]['value'] =
                  "data:$mimeType;base64,${base64Encode(response)}";
            } else {
              // Load file for mobile
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

  Future<void> _addMedia(String type) async {
    try {
      final XFile? file;
      if (type == 'image') {
        file = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        return;
      }

      if (file == null || !mounted) return;

      // Show caption dialog
      final caption = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text('Add Image Caption',
                style: TextStyle(fontFamily: 'Josefin Sans')),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(fontFamily: 'Josefin Sans'),
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel',
                    style: TextStyle(fontFamily: 'Josefin Sans')),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text('OK', style: TextStyle(fontFamily: 'Josefin Sans')),
                onPressed: () => Navigator.pop(context, controller.text),
              ),
            ],
          );
        },
      );

      if (caption == null) return; // User cancelled

      final bytes = await file.readAsBytes();
      final fileName = file.name;
      final fileId = ID.unique();

      // Upload to storage
      final uploadedFile = await storage.createFile(
        bucketId: bucketId,
        fileId: fileId,
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: fileName,
        ),
      );

      // Add to media list
      setState(() {
        media.add({
          'type': type,
          'fileId': uploadedFile.$id,
          'value': type == 'image' && kIsWeb
              ? "data:${_getMimeType(fileName)};base64,${base64Encode(bytes)}"
              : null,
          'position': Offset(50, 50),
          'width': MediaQuery.of(context).size.width < 600 ? 200.0 : 300.0,
          'height': MediaQuery.of(context).size.width < 600 ? 266.0 : 400.0,
          'caption': caption,
          'font': selectedFont,
          'textColor': selectedTextColor.value,
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

  Future<Map<String, dynamic>> _collectInsightsData() async {
    final doc = await databases.getDocument(
      databaseId: '67c32fc700070ceeadac',
      collectionId: '67eab72f0030b02f1623',
      documentId: widget.pageId,
    );

    final data = doc.data;
    final allPages = await databases.listDocuments(
      databaseId: '67c32fc700070ceeadac',
      collectionId: '67eab72f0030b02f1623',
      queries: [
        Query.equal('userId', widget.userId),
      ],
    );

    return {
      'currentPage': {
        'textData': data['textData'],
        'media': data['media'],
        'location': data['location'],
        'updatedAt': data['updatedAt'],
      },
      'allPages': allPages.documents.map((d) => d.data).toList(),
      'bucketId': bucketId,
      'userId': widget.userId,
    };
  }

  void _addText(Offset position) {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Text",
            style: TextStyle(fontFamily: 'JosefinSans')),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
          style: TextStyle(fontFamily: 'DeliciousHandrawn', fontSize: 28),
          decoration: const InputDecoration(
            hintText: "Type something...",
            hintStyle: TextStyle(fontFamily: 'JosefinSans'),
          ),
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
                setState(() {
                  textDataList.add(TextData(
                    text: text,
                    font: selectedFont,
                    color: selectedTextColor,
                    position: position,
                    size: 28,
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
                leading: Icon(Icons.text_fields, color: Colors.blue),
                title: Text('Add Text',
                    style: TextStyle(fontFamily: 'Josefin Sans', fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => isAddingText = true);
                },
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.color_lens, color: Colors.purple),
                title: Text('Text Color',
                    style: TextStyle(fontFamily: 'Josefin Sans', fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _showTextColorPicker();
                },
              ),
              Divider(height: 1),
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

  void _showTextColorPicker() {
    final List<Color> colors = [
      Colors.red, // 1
      Colors.pink, // 2
      Colors.purple, // 3
      Colors.deepPurple, // 4
      Colors.indigo, // 5
      Colors.blue, // 6
      Colors.cyan, // 7
      Colors.teal, // 8
      Colors.green, // 9
      Colors.amber, // 10
      Colors.orange, // 11
      Colors.deepOrange, // 12
      Color(0xFF7D6E99), // 15
      Color(0xFFC97C5D), // 16
      Color(0xFF4C9A9A), // 17
      Color(0xFF7A6F80), // 18
      Color(0xFFC2A661), // 19
      Colors.brown, // 13
      Colors.blueGrey, // 14
      Colors.black, // 20
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Text Color",
            style: TextStyle(fontFamily: 'JosefinSans')),
        content: BlockPicker(
          pickerColor: selectedTextColor,
          availableColors: colors,
          onColorChanged: (color) => setState(() => selectedTextColor = color),
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

  void _changeBackgroundColor() {
    final List<Color> colors = [
      Colors.white, // 4
      Color(0xFFE8C8B8), // 1 - Blush Pink Nude
      Color(0xFF6EE7F2), // 13
      Color(0xFFFF8FAB), // 14
      Color(0xFFE6E6FA), // 17 - Lavender Pastel
      Colors.purple, // 7
      Colors.indigo, // 9
      Colors.blue, // 10
      Colors.lightBlue, // 11
      Colors.cyan, // 8
      Colors.teal, // 12
      Color(0xFFB5EAD7), // 18 - Mint Green
      Color(0xFFEFCFE3), // 15
      Color(0xFFF7A399), // 16
      Color(0xFFFFDAC1), // 19 - Peach Pastel
      Color(0xFFD4B8A8), // 20 - Warm Beige
      Color(0xFFB38B6D), // 2 - Light Coffee
      Colors.brown, // 5
      Colors.grey, // 6
      Colors.black, // 3
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
            Text(widget.pageName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'JosefinSans')),
            if (selectedLocation != null && !isMobile)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('Location: $selectedLocation',
                    style: const TextStyle(
                        fontSize: 14, fontFamily: 'JosefinSans')),
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
                  ],
                ),
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
            fontSize: textData.size,
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
            fontSize: textData.size,
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
            title: const Text('Edit Text',
                style: TextStyle(fontFamily: 'JosefinSans')),
            onTap: () {
              Navigator.pop(context);
              _editText(textData);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete',
                style: TextStyle(fontFamily: 'JosefinSans')),
            onTap: () {
              setState(() => textDataList.remove(textData));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Change Color',
                style: TextStyle(fontFamily: 'JosefinSans')),
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
        title: const Text("Edit Text",
            style: TextStyle(fontFamily: 'JosefinSans')),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: null,
          style: TextStyle(fontFamily: 'DeliciousHandrawn'),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(fontFamily: 'JosefinSans')),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child:
                const Text("Save", style: TextStyle(fontFamily: 'JosefinSans')),
            onPressed: () {
              final newText = _textController.text.trim();
              if (newText.isNotEmpty) {
                setState(() => textData.text = newText);
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
        title: const Text("Choose Text Color",
            style: TextStyle(fontFamily: 'JosefinSans')),
        content: BlockPicker(
          pickerColor: textData.color,
          onColorChanged: (color) => setState(() => textData.color = color),
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

class TextData {
  String text;
  String font;
  Color color;
  Offset position;
  double size;

  TextData({
    required this.text,
    required this.font,
    required this.color,
    required this.position,
    this.size = 28,
  });

  factory TextData.fromJson(Map<String, dynamic> json) {
    final positionData = json['position'] is Map
        ? Map<String, dynamic>.from(json['position'])
        : {'dx': 50, 'dy': 50};

    return TextData(
      text: json['text']?.toString() ?? '',
      font: json['font']?.toString() ?? 'DeliciousHandrawn',
      color: Color(json['color'] is int ? json['color'] : Colors.black.value),
      position: Offset(
        (positionData['dx'] ?? 50).toDouble(),
        (positionData['dy'] ?? 50).toDouble(),
      ),
      size: (json['size'] ?? 28).toDouble(),
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

  @override
  void initState() {
    super.initState();
    _validateMediaUrl();
  }

  void _validateMediaUrl() {
    final mediaUrl = widget.mediaItem['value'] ?? '';
    if (mediaUrl.isEmpty) {
      _hasError = true;
      _isLoading = false;
    } else if (!mediaUrl.startsWith('http') &&
        !mediaUrl.startsWith('data:image')) {
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

    final mediaUrl = widget.mediaItem['value'] ?? '';

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
    } else if (widget.mediaItem['fileId'] != null) {
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

  Widget _buildDeleteButton() {
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
    setState(() {
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
      _panOffset = Offset.zero; // Reset pan offset after updating position
    });
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
