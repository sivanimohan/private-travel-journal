import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_page.dart';
import 'a4_white_page.dart';

class FolderPage extends StatefulWidget {
  final String folderName;
  final List<String> pages;
  const FolderPage({super.key, required this.folderName, required this.pages});

  @override
  _FolderPageState createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  List<String> pages = [];

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  // Load saved pages from SharedPreferences
  Future<void> _loadPages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      pages = prefs.getStringList(widget.folderName) ?? [];
    });
  }

  // Save pages to SharedPreferences
  Future<void> _savePages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.folderName, pages);
  }

  void _addPage(String pageName) {
    setState(() {
      pages.add(pageName);
    });
    _savePages();
  }

  void _removePage(int index) {
    setState(() {
      pages.removeAt(index);
    });
    _savePages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Colors.white, // White for contrast
          ),
        ),
        backgroundColor: Color(0xFF2C7DA0), // Dark blue
        elevation: 4,
      ),
      body: Container(
        color: Color(0xFFA9D6E5), // Light blue background
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pages in ${widget.folderName}:',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Merriweather',
                  fontWeight: FontWeight.w300,
                  color: Color(0xFF2C7DA0), // Dark blue
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: pages.isEmpty
                    ? Center(
                        child: Text(
                          'No pages yet. Tap the + button to add one!',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            color: Color(0xFF2C7DA0), // Dark blue
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => A4WhitePage(
                                    pageName: pages[index],
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              color:
                                  Colors.white, // White background for contrast
                              elevation: 4,
                              margin: EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.all(16),
                                title: Text(
                                  pages[index],
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C7DA0), // Dark blue
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete,
                                      color: Color(0xFF2C7DA0)), // Dark blue
                                  onPressed: () => _removePage(index),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newPageName = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPagePage(),
            ),
          );

          if (newPageName != null && newPageName.isNotEmpty) {
            _addPage(newPageName);
          }
        },
        backgroundColor: Color(0xFF2C7DA0), // Dark blue
        elevation: 8,
        child: Icon(Icons.add, color: Colors.white), // White for contrast
      ),
    );
  }
}
