import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:intl/intl.dart';

class AddPagePage extends StatelessWidget {
  final TextEditingController pageNameController = TextEditingController();
  final String folderId;
  final String userId;
  final Databases database;

  static const String COLLECTION_ID = '67cbeccb00382aae9f27'; // Pages Collection ID
  static const String DATABASE_ID = '67c32fc700070ceeadac'; // Database ID

  AddPagePage({
    super.key,
    required Client client,
    required this.folderId,
    required this.userId,
  }) : database = Databases(client);

  Future<void> _savePage(BuildContext context) async {
    String pageName = pageNameController.text.trim();
    if (pageName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a page name!',
            style: TextStyle(fontFamily: 'JosefinSans'),
          ),
          backgroundColor: Color(0xFF2C7DA0),
        ),
      );
      return;
    }

    String pageId = ID.unique(); // Generate unique page ID

    try {
      await database.createDocument(
        databaseId: DATABASE_ID,
        collectionId: COLLECTION_ID,
        documentId: pageId,
        data: {
          'pageId': pageId,
          'folderId': folderId,
          'userId': userId,
          'pageName': pageName,
          'backgroundColor': 0xFFFFFFFF,
          'location': '0.0.0.0',
          'mediaIds': [],
          'createdAt': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(DateTime.now()),
        },
      );

      Navigator.pop(context, pageName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save page: $e',
            style: TextStyle(fontFamily: 'JosefinSans'),
          ),
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
          'Add Page',
          style: TextStyle(

            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'JosefinSans',

          ),
        ),
        backgroundColor: const Color(0xFF2C7DA0),
      ),
      body: Container(
        color: const Color(0xFFA9D6E5),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: pageNameController,
              style: const TextStyle(fontFamily: 'JosefinSans'),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Page Name',
                hintStyle: const TextStyle(fontFamily: 'JosefinSans'),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _savePage(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C7DA0),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add Page',
                style: TextStyle(

                  fontSize: 18,
                  color: Colors.white,
                  fontFamily: 'JosefinSans',

                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
