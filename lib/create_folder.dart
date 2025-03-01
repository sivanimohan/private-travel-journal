import 'package:flutter/material.dart';

class CreateFolderPage extends StatelessWidget {
  const CreateFolderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final folderNameController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Folder',
          style: TextStyle(
            fontFamily: 'Merriweather',
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: Colors.white, // White text for contrast
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter Folder Name:',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Merriweather',
                  fontWeight: FontWeight.w300,
                  color: Color(0xFF2C7DA0), // Dark blue
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: folderNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Color(0xFF2C7DA0)), // Dark blue
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF2C7DA0), width: 2),
                  ),
                  hintText: 'Folder Name',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color:
                        Color(0xFF2C7DA0).withOpacity(0.6), // Dark blue faded
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  color: Color(0xFF2C7DA0), // Dark blue text
                ),
              ),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2C7DA0), // Dark blue
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        color: Colors.white, // White text for contrast
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      String folderName = folderNameController.text;
                      if (folderName.isNotEmpty) {
                        Navigator.pop(context, folderName);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please enter a folder name!',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                            backgroundColor: Color(0xFF2C7DA0), // Dark blue
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2C7DA0), // Dark blue
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        color: Colors.white, // White text for contrast
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
