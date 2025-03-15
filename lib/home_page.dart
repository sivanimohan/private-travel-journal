import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  final Client client;
  final String userId;
  final String fullName;
  final String? clientName;

  const HomePage({
    Key? key,
    required this.client,
    required this.userId,
    required this.fullName,
    this.clientName,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Account account;
  late final Databases databases;
  List<models.Document> folders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    account = Account(widget.client);
    databases = Databases(widget.client);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      // Load folders using clientName if available
      final List<String> queries = [
        Query.equal('userId', widget.userId),
      ];

      if (widget.clientName != null && widget.clientName!.isNotEmpty) {
        queries.add(Query.equal('clientName', widget.clientName!));
      }

      final response = await databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67cbebb60023c51812a1',
        queries: queries,
      );

      setState(() {
        folders = response.documents;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to load folders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${widget.fullName}')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : folders.isEmpty
              ? const Center(child: Text('No folders available'))
              : ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      title: Text(folder.data['folderName']),
                      subtitle: Text('Created at: ${folder.data['createdAt']}'),
                      onTap: () {
                        // Handle folder tap
                      },
                    );
                  },
                ),
    );
  }
}
