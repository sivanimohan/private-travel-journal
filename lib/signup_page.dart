import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appwrite/enums.dart';

import 'home_page.dart';

class SignUpPage extends StatefulWidget {
  final Client client;

  const SignUpPage({super.key, required this.client});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  late final Account account;
  late final Databases database;

  @override
  void initState() {
    super.initState();
    account = Account(widget.client);
    database = Databases(widget.client);
  }

  /// 🔹 Sign Up with Email and Password
  Future<void> _signUp() async {
    final String fullName = fullNameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      // Create user in Appwrite Authentication
      models.User user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: fullName,
      );

      // Save user data in the database
      await database.createDocument(
        databaseId: '67c32fc700070ceeadac',
        collectionId: '67eab73a002efac8d01e',
        documentId: user.$id,
        data: {
          'userId': user.$id,
          'email': email,
          'name': fullName,
        },
      );

      // Save user details in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.$id);
      await prefs.setString('fullName', fullName);
      await prefs.setString('email', email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Account Created Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            client: widget.client,
            userId: user.$id,
            fullName: fullName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Sign-Up Failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/loginpage.jpg', fit: BoxFit.cover),
          Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                width: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFFA9D6E5).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Title
                    Text(
                      "Sign Up",
                      style: GoogleFonts.alegreya(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C7DA0),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// Full Name Input
                    TextField(
                      controller: fullNameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        labelStyle: GoogleFonts.josefinSans(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    /// Email Input
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: GoogleFonts.josefinSans(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    /// Password Input
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: GoogleFonts.josefinSans(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signUp,
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.josefinSans(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
