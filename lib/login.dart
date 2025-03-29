import 'package:appwrite/enums.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final Client client;

  const LoginPage({super.key, required this.client});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late Account account;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    account = Account(widget.client);
  }

  /// 🔹 Google Sign-In Function
  Future<void> _googleSignIn() async {
    try {
      await account.createOAuth2Session(
        provider: OAuthProvider.google,
        success: 'appwrite://auth',
        failure: 'appwrite://auth-failed',
      );

      // Retrieve user details after login
      final models.User user = await account.get();
      String userId = user.$id;
      String fullName = user.name;
      String email = user.email;

      print("✅ Logged in as: $fullName ($email)");

      // 🔹 Save user details to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('fullName', fullName);
      await prefs.setString('email', email);

      // 🔹 Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            client: widget.client,
            userId: userId,
            fullName: fullName,
          ),
        ),
      );
    } catch (e) {
      print("❌ Google sign-in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Google sign-in failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🔹 Email & Password Sign-In Function
  Future<void> _emailSignIn() async {
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw "Please enter both email and password.";
      }

      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );

      // Retrieve user details after login
      final models.User user = await account.get();
      String userId = user.$id;
      String fullName = user.name;

      print("✅ Logged in as: $fullName ($email)");

      // 🔹 Save user details to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('fullName', fullName);
      await prefs.setString('email', email);

      // 🔹 Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            client: widget.client,
            userId: userId,
            fullName: fullName,
          ),
        ),
      );
    } catch (e) {
      print("❌ Email sign-in failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Email sign-in failed: ${e.toString()}"),
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
                    Text(
                      "Login",
                      style: GoogleFonts.alegreya(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C7DA0),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// 🔹 Email TextField
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: GoogleFonts.josefinSans(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),

                    /// 🔹 Password TextField
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: GoogleFonts.josefinSans(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),

                    /// 🔹 Sign In with Email & Password Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _emailSignIn,
                        child: Text(
                          "Sign in with Email",
                          style: GoogleFonts.josefinSans(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C7DA0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    /// 🔹 Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _googleSignIn,
                        icon: Image.asset(
                          'assets/google.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                        label: Text(
                          "Sign in with Google",
                          style: GoogleFonts.josefinSans(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    /// 🔹 Sign-Up Redirect
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignUpPage(
                              client: widget.client,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        "Don't have an account? Sign up",
                        style: GoogleFonts.josefinSans(
                          fontSize: 16,
                          color: Colors.black87,
                          decoration: TextDecoration.underline,
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
