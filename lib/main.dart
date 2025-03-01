import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? fullName = prefs.getString('fullName');
  String? email = prefs.getString('email');

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: (fullName != null && email != null)
        ? HomePage(fullName: fullName)
        : LoginPage(), // Start with LoginPage if no saved user
  ));
}
