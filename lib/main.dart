import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appwrite/appwrite.dart';
import 'home_page.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('userId');
  String? fullName = prefs.getString('fullName');
  String? email = prefs.getString('email');

  // Initialize Appwrite client
  Client client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1') // Your Appwrite endpoint
      .setProject('67c329590010d80b983c') // Your project ID
      .setSelfSigned(status: true); // For development only

  runApp(MyApp(
    client: client,
    userId: userId,
    fullName: fullName,
    email: email,
  ));
}

class MyApp extends StatelessWidget {
  final Client client;
  final String? userId;
  final String? fullName;
  final String? email;

  const MyApp({
    super.key,
    required this.client,
    this.userId,
    this.fullName,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: (userId != null && fullName != null && email != null)
          ? HomePage(client: client, userId: userId!, fullName: fullName!)
          : LoginPage(client: client),
    );
  }
}
