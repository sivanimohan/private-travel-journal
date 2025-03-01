import 'package:auth0_flutter/auth0_flutter.dart';

class AuthService {
  final Auth0 auth0 = Auth0('YOUR_AUTH0_DOMAIN', 'YOUR_AUTH0_CLIENT_ID');

  Future<String?> login() async {
    try {
      final credentials = await auth0.webAuthentication().login();
      return credentials.accessToken;
    } catch (e) {
      print('Login failed: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await auth0.webAuthentication().logout();
    } catch (e) {
      print('Logout failed: $e');
    }
  }
}
