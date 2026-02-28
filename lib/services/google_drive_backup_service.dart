import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDriveBackupService {
  static const String backupFileName = 'stock_checker_backup_v1.json';
  static const String _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static GoogleSignIn _buildGoogleSignIn() {
    if (kIsWeb && _webClientId.isNotEmpty) {
      return GoogleSignIn(
        clientId: _webClientId,
        scopes: <String>[drive.DriveApi.driveAppdataScope],
      );
    }
    return GoogleSignIn(
      scopes: <String>[drive.DriveApi.driveAppdataScope],
    );
  }

  final GoogleSignIn _googleSignIn = _buildGoogleSignIn();
  String? _lastAuthError;

  String? consumeLastAuthError() {
    final error = _lastAuthError;
    _lastAuthError = null;
    return error;
  }

  bool isSupportedPlatform() {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  }

  bool isWebClientIdReady() {
    return !kIsWeb || _webClientId.isNotEmpty;
  }

  Future<String?> getSignedInEmail() async {
    if (!isSupportedPlatform() || !isWebClientIdReady()) {
      return null;
    }
    try {
      final account = await _googleSignIn.signInSilently();
      _lastAuthError = null;
      return account?.email;
    } catch (error) {
      _lastAuthError = error.toString();
      return null;
    }
  }

  Future<String?> signInAndGetEmail() async {
    if (!isSupportedPlatform() || !isWebClientIdReady()) {
      return null;
    }
    try {
      final account =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      _lastAuthError = null;
      return account?.email;
    } catch (error) {
      _lastAuthError = error.toString();
      return null;
    }
  }

  Future<void> signOut() async {
    if (!isSupportedPlatform()) {
      return;
    }
    await _googleSignIn.signOut();
  }

  Future<bool> backupJson(Map<String, dynamic> payload) async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      return false;
    }

    final api = drive.DriveApi(client);
    final bodyText = jsonEncode(payload);
    final media = drive.Media(
      Stream<List<int>>.value(utf8.encode(bodyText)),
      bodyText.length,
      contentType: 'application/json',
    );

    final existing = await _findBackupFile(api);
    if (existing == null) {
      final file = drive.File()
        ..name = backupFileName
        ..parents = <String>['appDataFolder']
        ..mimeType = 'application/json';
      await api.files.create(file, uploadMedia: media);
      return true;
    }

    await api.files.update(drive.File(), existing.id!, uploadMedia: media);
    return true;
  }

  Future<Map<String, dynamic>?> restoreJson() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      return null;
    }

    final api = drive.DriveApi(client);
    final existing = await _findBackupFile(api);
    if (existing == null || existing.id == null) {
      return null;
    }

    final media = await api.files.get(
      existing.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (media is! drive.Media) {
      return null;
    }

    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
    }
    final text = utf8.decode(chunks);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Future<drive.File?> _findBackupFile(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='${backupFileName.replaceAll("'", "\\'")}' and 'appDataFolder' in parents and trashed=false",
      pageSize: 1,
      $fields: 'files(id,name,modifiedTime)',
      orderBy: 'modifiedTime desc',
    );
    final files = list.files;
    if (files == null || files.isEmpty) {
      return null;
    }
    return files.first;
  }
}
