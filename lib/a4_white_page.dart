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
  String? selectedLocation;
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

  // Save all changes to Appwrite database
  Future<void> _saveContent() async {
    try {
      // Prepare data to save
      final mediaData = media.map((m) {
        final position = m['position']; // Get the position data

        double dx = 0.0; // Default values to prevent null errors
        double dy = 0.0;

        if (position is Offset) {
          dx = position.dx;
          dy = position.dy;
        } else if (position is Map<String, dynamic>) {
          dx = position['dx']?.toDouble() ?? 0.0;
          dy = position['dy']?.toDouble() ?? 0.0;
        }

        return {
          'type': m['type'],
          'fileId': m['fileId'],
          'position': {'dx': dx, 'dy': dy},
        };
      }).toList();

      // Serialize textData into a JSON string
      final textDataJson = jsonEncode(textDataList
          .map((textData) => {
                'text': textData.text,
                'font': textData.font,
                'color': textData.color.value,
                'position': {
                  'dx': textData.position.dx,
                  'dy': textData.position.dy,
                },
              })
          .toList());

      // Update the document in Appwrite database
      await databases.updateDocument(
        databaseId: '67c32fc700070ceeadac', // Your database ID
        collectionId: '67cbeccb00382aae9f27', // Your collection ID
        documentId: widget.pageId,
        data: {
          'backgroundColor': backgroundColor.value,
          'media': mediaData,
          'textData': textDataJson,
          'folderId': widget.folderId,
          'userId': widget.userId,
          'locations': selectedLocation, // Save the location
        },
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content saved successfully!')),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving content: ${e.toString()}')),
        );
      }
      print('Error saving content: $e');
    }
  }

  // Load saved content from Appwrite database
  Future<void> _loadSavedContent() async {
    try {
      final doc = await databases.getDocument(
        databaseId: '67c32fc700070ceeadac', // Your database ID
        collectionId: '67cbeccb00382aae9f27', // Your collection ID
        documentId: widget.pageId,
      );

      setState(() {
        backgroundColor =
            Color(doc.data['backgroundColor'] ?? Colors.white.value);
        media = List<Map<String, dynamic>>.from(doc.data['media'] ?? [])
            .map((mediaItem) {
          return {
            'type': mediaItem['type'],
            'fileId': mediaItem['fileId'],
            'value': mediaItem['value'], // Use 'value' for web or mobile
            'position': mediaItem['position'] != null
                ? Offset(mediaItem['position']['dx'] ?? 50,
                    mediaItem['position']['dy'] ?? 50)
                : const Offset(
                    50, 50), // Initialize position with a default value if null
          };
        }).toList();
        textDataList =
            (jsonDecode(doc.data['textData'] ?? '[]') as List).map((textJson) {
          return TextData(
            text: textJson['text'],
            font: textJson['font'],
            color: Color(textJson['color']),
            position:
                Offset(textJson['position']['dx'], textJson['position']['dy']),
          );
        }).toList();
        selectedLocation = doc.data['locations']; // Load the location
      });

      // Fetch image URLs from storage for non-web platforms
      if (!kIsWeb) {
        for (var mediaItem in media) {
          if (mediaItem['type'] == 'image') {
            final fileId = mediaItem['fileId'];
            final fileUrl = await storage.getFileView(
              bucketId: '67cd36510039f3d96c62', // Replace with your bucket ID
              fileId: fileId,
            );
            mediaItem['url'] = fileUrl; // Store the URL for display
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No saved content found: $e')),
        );
      }
      print('No saved content found: $e');
    }
  }

  Future<void> _showLocationPicker() async {
    final selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationPage()),
    );

    if (selectedLocation != null && mounted) {
      setState(() {
        this.selectedLocation = selectedLocation['address']; // Update location
      });
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
      print('Failed to load media: $e');
    }
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
                setState(() {
                  isAddingText = true;
                });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.pageName ??
                'Untitled'), // Display page name or 'Untitled' if null
            const Spacer(),
            if (selectedLocation !=
                null) // Display the selected location if it exists
              Text(
                'Location: $selectedLocation',
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveContent, // Save content when the button is pressed
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _showLocationPicker, // Open the location picker
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (isAddingText) {
            _addText(textPosition ?? Offset.zero);
          }
        },
        child: Stack(
          children: [
            Container(
                color: backgroundColor ??
                    Colors.white), // Fallback to white if null
            ...textDataList.map((textData) {
              return Positioned(
                left: textData.position.dx,
                top: textData.position.dy,
                child: Text(
                  textData.text ?? '', // Fallback to empty string if null
                  style: TextStyle(
                    fontFamily:
                        textData.font ?? 'JosefinSans', // Fallback font if null
                    color: textData.color ??
                        Colors.black, // Fallback color if null
                    fontSize: 24,
                  ),
                ),
              );
            }).toList(),
            ...media.map((mediaItem) {
              if (mediaItem['type'] == 'image') {
                return Positioned(
                  left:
                      mediaItem['position']?.dx ?? 50, // Safely access position
                  top:
                      mediaItem['position']?.dy ?? 50, // Safely access position
                  child: Image.network(
                    mediaItem['value'] ??
                        '', // Fallback to empty string if null
                    width: 300, // Fixed width
                    height: 400, // Fixed height
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return const Icon(Icons
                          .error); // Show error icon if image fails to load
                    },
                  ),
                );
              }
              return const SizedBox
                  .shrink(); // Return an empty widget for non-image media
            }).toList(),
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

class LocationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Implement location selection logic here
    // Return a map with the selected location's address
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Example: Return a mock location
            Navigator.pop(context, {'address': '123 Main St, City, Country'});
          },
          child: const Text('Select Location'),
        ),
      ),
    );
  }
}

// TextData class to store text-related data
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

// AudioPlayerWidget class for audio playback
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
