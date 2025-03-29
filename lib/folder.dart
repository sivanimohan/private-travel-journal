import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'add_page.dart';
import 'a4_white_page.dart';

class FolderPage extends StatefulWidget {
  final Client client;
  final String folderId;
  final String folderName;
  final String userId;

  const FolderPage({
    super.key,
    required this.client,
    required this.folderId,
    required this.folderName,
    required this.userId,
  });

  @override
  _FolderPageState createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late Databases _database;
  List<Map<String, String>> pages = [];
  final String databaseId = '67c32fc700070ceeadac';
  final String collectionId = '67cbeccb00382aae9f27';

  @override
  void initState() {
    super.initState();
    _database = Databases(widget.client);
    _loadPages();
  }

  /// 🔹 Load Pages
  Future<void> _loadPages() async {
    try {
      final response = await _database.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: [Query.equal('folderId', widget.folderId)],
      );

      setState(() {
        pages = response.documents
            .map((doc) => {
                  'pageId': doc.$id,
                  'pageName': doc.data['pageName'] as String,
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Failed to load pages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load pages. Please try again.')),
        );
      }
    }
  }

  /// 🔹 Add Page (Prevents Duplicate Names)
  Future<void> _addPage(String pageName) async {
    if (pages.any((page) => page['pageName'] == pageName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A page with this name already exists!')),
      );
      return;
    }

    try {
      final newPage = await _database.createDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: ID.unique(),
        data: {
          'pageName': pageName,
          'folderId': widget.folderId,
          'userId': widget.userId,
          'backgroundColor': 0xFFFFFFFF,
          'mediaIds': [],
          'location': '{}',
        },
      );

      setState(() {
        pages.add({'pageId': newPage.$id, 'pageName': pageName});
      });
    } catch (e) {
      debugPrint('Error adding page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add page. Please try again.')),
      );
    }
  }

  /// 🔹 Remove Page
  Future<void> _removePage(int index) async {
    try {
      await _database.deleteDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: pages[index]['pageId']!,
      );

      setState(() {
        pages.removeAt(index);
      });
    } catch (e) {
      debugPrint('Error deleting page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(
            fontFamily: 'Josefin Sans',
          ),
        ),
        backgroundColor: const Color(0xFF2C7DA0),
      ),
      body: Container(
        color: const Color(0xFFA9D6E5),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Pages in ${widget.folderName}:',
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF2C7DA0),
                fontFamily: 'Josefin Sans',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: pages.isEmpty
                  ? const Center(
                      child: Text(
                        'No pages yet. Tap + to add one!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              pages[index]['pageName']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Josefin Sans',
                                color: Color(0xFF2C7DA0),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removePage(index),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => A4WhitePage(
                                    client: widget.client,
                                    pageId: pages[index]['pageId']!,
                                    pageName: pages[index]['pageName']!,
                                    folderId: widget.folderId,
                                    userId: widget.userId,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2C7DA0),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPagePage(
                client: widget.client,
                folderId: widget.folderId,
                userId: widget.userId,
              ),
            ),
          ).then((newPageName) {
            if (newPageName != null) {
              _addPage(newPageName);
            }
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
