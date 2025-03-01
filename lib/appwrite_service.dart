import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

class AppwriteService {
  final Client client = Client();
  final Account account;
  final Databases databases;

  AppwriteService()
      : account = Account(Client()
          ..setEndpoint(
              'standard_eb999fa12ee377e2ad2435463a9691936f4558c571a15ca9251b2fd10ec22227acd9d167b5f88adf0f5532119e3216cf240b6693f28e96418dae263ef4548aefdc2e1739ba584491284f4c0d873dc5a61945372bad9d64dc2977dd0e42b97142c487760aaf11e48a0ed8023fb03ff149304d1d0a87cd6bac5e1a161f3d72d247')
          ..setProject('YOUR_PROJECT_ID')),
        databases = Databases(Client()
          ..setEndpoint(
              'standard_eb999fa12ee377e2ad2435463a9691936f4558c571a15ca9251b2fd10ec22227acd9d167b5f88adf0f5532119e3216cf240b6693f28e96418dae263ef4548aefdc2e1739ba584491284f4c0d873dc5a61945372bad9d64dc2977dd0e42b97142c487760aaf11e48a0ed8023fb03ff149304d1d0a87cd6bac5e1a161f3d72d247')
          ..setProject('YOUR_PROJECT_ID'));

  Future<User?> signUp(String email, String password, String fullName) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
      );

      await databases.createDocument(
        databaseId: 'YOUR_DATABASE_ID',
        collectionId: 'USER_COLLECTION_ID',
        documentId: user.$id,
        data: {'fullName': fullName, 'email': email},
      );

      return user;
    } catch (e) {
      print('Sign-up failed: $e');
      return null;
    }
  }

  Future<Session?> login(String email, String password) async {
    try {
      return await account.createEmailSession(email: email, password: password);
    } catch (e) {
      print('Login failed: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await account.deleteSession(sessionId: 'current');
  }
}

extension on Account {
  createEmailSession({required String email, required String password}) {}
}
