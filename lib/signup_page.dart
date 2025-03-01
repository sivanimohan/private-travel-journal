import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _signUp() async {
    final String fullName = fullNameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fullName', fullName);
    await prefs.setString('email', email);
    await prefs.setString('password', password);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Account Created Successfully!")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Background Image
          Image.asset(
            'assets/loginpage.jpg', // Ensure this image exists
            fit: BoxFit.cover,
          ),

          /// Welcome Text
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Welcome to Odyssey",
                style: GoogleFonts.alexBrush(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          /// Signup Box
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              width: 320,
              decoration: BoxDecoration(
                color: Color(0xFFA9D6E5).withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Sign Up",
                      style: GoogleFonts.alegreya(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C7DA0))),
                  SizedBox(height: 20),
                  TextField(
                      controller: fullNameController,
                      decoration: InputDecoration(labelText: "Full Name")),
                  TextField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: "Email")),
                  TextField(
                      controller: passwordController,
                      decoration: InputDecoration(labelText: "Password"),
                      obscureText: true),
                  SizedBox(height: 20),
                  ElevatedButton(onPressed: _signUp, child: Text("Sign Up")),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
