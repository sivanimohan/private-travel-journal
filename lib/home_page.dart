import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'create_folder.dart';
import 'folder.dart';
import 'dart:io';
import 'world_map_page.dart';
import 'insight.dart';
import 'package:traveljournal/login.dart';

class HomePage extends StatefulWidget {
  final Client client;
  final String userId;
  final String fullName;

  const HomePage({
    super.key,
    required this.client,
    required this.userId,
    required this.fullName,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Account account;
  late final Databases databases;

  // Define the _folders variable to store folder data
  List<Map<String, dynamic>> _folders = [];

  @override
  void initState() {
    super.initState();
    account = Account(widget.client);
    databases = Databases(widget.client);
    _loadFolders();
  }

  // Method to load folders from the database
  Future<void> _loadFolders() async {
    try {
      final result = await databases.listDocuments(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab63d001054f7631a',
        queries: [
          Query.equal('userId', widget.userId),
        ],
      );

      setState(() {
        _folders = result.documents.map((doc) => doc.data).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to load folders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _isUserAuthenticated() async {
    try {
      await account
          .get(); // This will throw an exception if the user is not authenticated
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _signOut() async {
    try {
      // Check if the user is authenticated
      bool isAuthenticated = await _isUserAuthenticated();

      if (!isAuthenticated) {
        // If not authenticated, redirect to login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(client: widget.client),
          ),
        );
        return;
      }

      // Delete the current session
      await account.deleteSession(sessionId: 'current');

      // Redirect to login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(client: widget.client),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sign out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUserInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👤 ${widget.fullName}',
                  style: const TextStyle(fontFamily: 'JosefinSans'),
                ),
                Text(
                  '📧 ${widget.userId}',
                  style:
                      const TextStyle(fontSize: 12, fontFamily: 'JosefinSans'),
                ),
              ],
            ),
            TextButton(
              onPressed: _signOut,
              child: const Text(
                'Sign Out',
                style:
                    TextStyle(color: Colors.white, fontFamily: 'JosefinSans'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/homepage.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF2C7DA0),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '👋 Welcome, ${widget.fullName}!',
                      style: const TextStyle(
                        fontFamily: 'JosefinSans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _showUserInfo,
                      icon: const Icon(
                        Icons.account_circle,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _folders.isEmpty
                    ? const Center(
                        child: Text(
                          'No folders available.',
                          style: TextStyle(
                            fontFamily: 'JosefinSans',
                            fontSize: 18,
                            color: Color(0xFF2C7DA0),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _folders.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FolderPage(
                                      client: widget.client,
                                      folderId: folder['folderId'],
                                      folderName: folder['name'],
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      folder['name'],
                                      style: const TextStyle(
                                        fontFamily: 'JosefinSans',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2C7DA0),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Color(0xFF2C7DA0),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 80,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InsightPage(
                      userId: widget.userId,
                      userData: {
                        'allPages': [], // Pass actual user data here as needed
                      },
                    ),
                  ),
                );
              },
              backgroundColor: const Color(0xFF2C7DA0),
              child: const Icon(Icons.insights),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorldMapPage(
                        databases: databases, userId: widget.userId),
                  ),
                );
              },
              backgroundColor: const Color(0xFF2C7DA0),
              child: const Icon(Icons.map),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateFolderPage(
                client: widget.client,
                userId: widget.userId,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF2C7DA0),
        child: const Icon(Icons.add),
      ),
    );
  }
}
