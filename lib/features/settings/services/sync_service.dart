import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> syncFavorites() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final metadataBox = Hive.box('metadata_box');
    final favorites = metadataBox.values.where((item) => item['isFavorite'] == true).toList();

    // Push local favorites to Cloud
    final batch = _db.batch();
    for (var fav in favorites) {
      final docRef = _db.collection('users').doc(user.uid).collection('favorites').doc(fav['hash']);
      batch.set(docRef, {
        'id': fav['id'],
        'title': fav['title'],
        'artist': fav['artist'],
        'hash': fav['hash'],
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> syncSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settingsBox = Hive.box('settings_box');
    final settingsMap = {
      'theme_mode': settingsBox.get('theme_mode', defaultValue: 'dark'),
      'player_style': settingsBox.get('playerStyle', defaultValue: 'Circle'),
      'accent_color': settingsBox.get('accent_color', defaultValue: 0xFF39FF14),
    };

    await _db.collection('users').doc(user.uid).set({
      'settings': settingsMap,
      'lastSync': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> pullSyncData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        final box = Hive.box('settings_box');
        settings.forEach((key, value) => box.put(key, value));
      }
    }
  }
}
