import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

class AppwriteService {
  late Client _client;
  late Account _account;
  late Databases _databases;
  late Storage _storage;

  static const String PROJECT_ID = "67c329590010d80b983c";
  static const String DATABASE_ID = "67c32fc700070ceeadac";
  static const String USERS_COLLECTION_ID = "67cbe1ce00196895cd13";
  static const String FOLDERS_COLLECTION_ID = "67cbebb60023c51812a1";
  static const String PAGES_COLLECTION_ID = "67cbeccb00382aae9f27";
  static const String MEDIA_COLLECTION_ID = "67cd34960000649f059d";
  static const String DRAWINGS_COLLECTION_ID = "67cd351c000d48c4f69f";
  static const String STORAGE_BUCKET_ID = "67cd36510039f3d96c62";

  AppwriteService() {
    _client = Client()
        .setEndpoint("https://cloud.appwrite.io/v1")
        .setProject(PROJECT_ID);

    _account = Account(_client);
    _databases = Databases(_client);
    _storage = Storage(_client);
  }

  /// **User Authentication**
  Future<User?> signUp(String email, String password, String fullName) async {
    try {
      final user = await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: fullName,
      );
      return user;
    } catch (e) {
      print("Signup Error: $e");
      return null;
    }
  }

  Future<Session?> login(String email, String password) async {
    try {
      return await _account.createEmailPasswordSession(
          email: email, password: password);
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  Future<void> logout() async {
    await _account.deleteSessions();
  }

  /// **Folder Management**
  Future<void> createFolder(
      String folderName, String userId, String location) async {
    try {
      await _databases.createDocument(
        databaseId: DATABASE_ID,
        collectionId: FOLDERS_COLLECTION_ID,
        documentId: ID.unique(),
        data: {
          'folderName': folderName,
          'userId': userId,
          'location': location,
          'createdAt': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read('user:$userId'),
          Permission.write('user:$userId'),
        ],
      );
    } catch (e) {
      print("Folder Creation Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchFolders(String userId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: DATABASE_ID,
        collectionId: FOLDERS_COLLECTION_ID,
        queries: [Query.equal('userId', userId)],
      );
      return response.documents.map((doc) => doc.data).toList();
    } catch (e) {
      print("Fetch Folders Error: $e");
      return [];
    }
  }

  /// **Page Management**
  Future<void> createPage(String folderId, String pageName, String userId,
      int backgroundColor, String location) async {
    try {
      await _databases.createDocument(
        databaseId: DATABASE_ID,
        collectionId: PAGES_COLLECTION_ID,
        documentId: ID.unique(),
        data: {
          'folderId': folderId,
          'pageName': pageName,
          'userId': userId,
          'backgroundColor': backgroundColor,
          'location': location,
          'createdAt': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read('user:$userId'),
          Permission.write('user:$userId'),
        ],
      );
    } catch (e) {
      print("Page Creation Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchPages(String folderId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: DATABASE_ID,
        collectionId: PAGES_COLLECTION_ID,
        queries: [Query.equal('folderId', folderId)],
      );
      return response.documents.map((doc) => doc.data).toList();
    } catch (e) {
      print("Fetch Pages Error: $e");
      return [];
    }
  }

  /// **Media Management**
  Future<void> addMedia(String pageId, String type, String value, String userId,
      Map<String, int> position) async {
    try {
      await _databases.createDocument(
        databaseId: DATABASE_ID,
        collectionId: MEDIA_COLLECTION_ID,
        documentId: ID.unique(),
        data: {
          'pageId': pageId,
          'type': type,
          'value': value,
          'position': position,
        },
        permissions: [
          Permission.read('user:$userId'),
          Permission.write('user:$userId'),
        ],
      );
    } catch (e) {
      print("Add Media Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchMedia(String pageId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: DATABASE_ID,
        collectionId: MEDIA_COLLECTION_ID,
        queries: [Query.equal('pageId', pageId)],
      );
      return response.documents.map((doc) => doc.data).toList();
    } catch (e) {
      print("Fetch Media Error: $e");
      return [];
    }
  }

  /// **File Upload (Images, Videos, Audio, Drawings)**
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final file = await _storage.createFile(
        bucketId: STORAGE_BUCKET_ID,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: filePath, filename: fileName),
      );
      return file.$id;
    } catch (e) {
      print("File Upload Error: $e");
      return null;
    }
  }

  Future<Future<Uint8List>?> getFileUrl(String fileId) async {
    try {
      return _storage.getFilePreview(
          bucketId: STORAGE_BUCKET_ID, fileId: fileId);
    } catch (e) {
      print("Get File URL Error: $e");
      return null;
    }
  }
}
