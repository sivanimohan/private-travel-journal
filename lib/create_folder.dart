import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

class CreateFolderPage extends StatefulWidget {
  final Client client;
  final String userId;
  final String? clientName;

  const CreateFolderPage({
    super.key,
    required this.client,
    required this.userId,
    this.clientName,
  });

  @override
  _CreateFolderPageState createState() => _CreateFolderPageState();
}

class _CreateFolderPageState extends State<CreateFolderPage> {
  final TextEditingController folderNameController = TextEditingController();
  late Databases databases;

  @override
  void initState() {
    super.initState();
    databases = Databases(widget.client);
  }

  /// 🔹 Create Folder in Appwrite Database
  Future<void> _createFolder() async {
    String folderName = folderNameController.text.trim();
    if (folderName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❗ Please enter a folder name!"),
          backgroundColor: Color(0xFF2C7DA0),
        ),
      );
      return;
    }

    try {
      await databases.createDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbebb60023c51812a1',
        documentId: ID.unique(),
        data: {
          'folderId': ID.unique(),
          'userId': widget.userId,
          'name': folderName, // ✅ Use 'name' instead of 'folderName'
          'location': {'latitude': 0.0, 'longitude': 0.0}, // Default location
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      Navigator.pop(context, folderName); // Return folder name on success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to create folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Folder',
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF2C7DA0),
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Folder Name:',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                color: Color(0xFF2C7DA0),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: folderNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2C7DA0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2C7DA0), width: 2),
                ),
                hintText: 'Enter folder name',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF2C7DA0),
                  fontSize: 16,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                color: Color(0xFF2C7DA0),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createFolder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C7DA0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Folder',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Color(0xFF2C7DA0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
