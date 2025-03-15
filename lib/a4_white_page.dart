import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:io';
import 'dart:convert';

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
      await databases.updateDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
        data: {
          'backgroundColor': backgroundColor.value,
          'mediaIds': mediaIds,
          'folderId': widget.folderId,
          'userId': widget.userId,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving content: $e')),
      );
    }
  }

  Future<void> _loadSavedContent() async {
    try {
      final doc = await databases.getDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbeccb00382aae9f27',
        documentId: widget.pageId,
      );
      backgroundColor = Color(doc.data['backgroundColor']);
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
      setState(() {
        media = mediaData;
      });
    } catch (e) {
      print('No saved content found: $e');
    }
  }

  Future<String?> _uploadFile(File file, String type) async {
    try {
      final result = await storage.createFile(
        bucketId: '67cd36510039f3d96c62',
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path),
      );
      return result.$id;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
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
      String? fileId = await _uploadFile(File(file.path), type);
      if (fileId != null) {
        final mediaDoc = await databases.createDocument(
          databaseId: '67c32fc700070ceeadac',
          collectionId: '67cd34960000649f059d',
          documentId: ID.unique(),
          data: {
            'pageId': widget.pageId,
            'folderId': widget.folderId,
            'userId': widget.userId,
            'type': type,
            'value': fileId,
            'position': jsonEncode({'x': 50.0, 'y': 50.0}),
          },
        );
        setState(() {
          media.add(mediaDoc.data);
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageName),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveContent),
          IconButton(
            icon: const Icon(Icons.format_paint),
            onPressed: _changeBackgroundColor,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _addMedia('image'),
          ),
          IconButton(
            icon: const Icon(Icons.video_library),
            onPressed: () => _addMedia('video'),
          ),
        ],
      ),
      body: Container(color: backgroundColor),
    );
  }
}
