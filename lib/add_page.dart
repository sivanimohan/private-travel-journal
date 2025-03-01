import 'package:flutter/material.dart';

class AddPagePage extends StatelessWidget {
  final pageNameController = TextEditingController();

  AddPagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Page',
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter Page Name:',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Merriweather',
                fontWeight: FontWeight.w300,
                color: Color(0xFF2C7DA0), // Dark blue
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: pageNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2C7DA0)), // Dark blue
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Color(0xFF2C7DA0), width: 2), // Dark blue
                ),
                hintText: 'Page Name',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF2C7DA0)
                      .withOpacity(0.6), // Dark blue with opacity
                ),
              ),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                color: Color(0xFF2C7DA0), // Dark blue
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                String pageName = pageNameController.text;
                if (pageName.isNotEmpty) {
                  Navigator.pop(context, pageName);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter a page name!',
                        style: TextStyle(fontFamily: 'Inter'),
                      ),
                      backgroundColor: Color(0xFF2C7DA0), // Dark blue
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2C7DA0), // Dark blue
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add Page',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  color: Colors.white, // White for contrast
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
