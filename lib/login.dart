import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'appwrite_service.dart';
import 'home_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AppwriteService appwriteService = AppwriteService();

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final session = await appwriteService.login(email, password);
    if (session != null) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => HomePage(
                    fullName: '',
                  )));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Invalid email or password")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset('assets/loginpage.jpg', fit: BoxFit.cover),
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              width: 320,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Login",
                      style: GoogleFonts.alegreya(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  TextField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: "Email")),
                  TextField(
                      controller: passwordController,
                      decoration: InputDecoration(labelText: "Password"),
                      obscureText: true),
                  ElevatedButton(onPressed: _login, child: Text("Login")),
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SignUpPage())),
                      child: Text("Don't have an account? Sign up")),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
