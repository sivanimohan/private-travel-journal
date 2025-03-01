import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'create_folder.dart';
import 'folder.dart';

class HomePage extends StatefulWidget {
  final String fullName;

  HomePage({required this.fullName});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  // Load saved folders from SharedPreferences
  Future<void> _loadFolders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      folders = prefs.getStringList('folders') ?? [];
    });
  }

  // Save folders to SharedPreferences
  Future<void> _saveFolders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('folders', folders);
  }

  // Handle folder creation
  void _createNewFolder() async {
    final folderName = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateFolderPage()),
    );

    if (folderName != null && folderName.isNotEmpty) {
      setState(() {
        folders.add(folderName);
      });
      _saveFolders();
    }
  }

  // Navigate to folder-specific page
  void _openFolder(String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderPage(folderName: folderName, pages: []),
      ),
    );
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Travel Journal"),
        backgroundColor: Color(0xFF2C7DA0), // Dark blue color
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Color(0xFFA9D6E5), // Light blue color
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF2C7DA0)), // Dark blue
              accountName: Text(
                widget.fullName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text("Welcome back!"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Color(0xFF2C7DA0)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.black),
              title: Text("Profile"),
              onTap: () {
                // Add profile navigation if needed
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.black),
              title: Text("Sign Out"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              "assets/homepage.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 50), // Moves "Welcome" higher
                Text(
                  "Welcome, ${widget.fullName}!",
                  style: TextStyle(
                    fontSize: 26,
                    fontFamily: 'Merriweather',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                    color: Colors.white, // White for better visibility
                  ),
                ),
                SizedBox(height: 20),

                Expanded(
                  child: folders.isEmpty
                      ? Center(
                          child: Text(
                            'No folders yet. Tap + to create one!',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w300,
                              color: Colors.white, // White for visibility
                            ),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: folders.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openFolder(folders[index]),
                              child: Card(
                                color: Color(0xFF2C7DA0), // Dark blue
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    folders[index],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white, // White text
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewFolder,
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF2C7DA0), // Dark blue button
      ),
    );
  }
}
