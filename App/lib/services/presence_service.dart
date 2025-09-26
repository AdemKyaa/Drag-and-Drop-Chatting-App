import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final _fs = FirebaseFirestore.instance;
  String? _uid;
  bool _onlineEnabled = true; // Ayarlardan gelen açık/kapalı

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  Future<void> start(String uid) async {
    if (_uid == uid) return;
    _uid = uid;

    WidgetsBinding.instance.addObserver(this);

    // Kullanıcı dokümanı yoksa oluştur / varsa merge et
    await _fs.collection('users').doc(uid).set({
      'isOnline': true,
      'onlineEnabled': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Ayarlardaki "onlineEnabled" değişirse dinle
    _userSub?.cancel();
    _userSub = _fs.collection('users').doc(uid).snapshots().listen((snap) {
      final data = snap.data();
      _onlineEnabled = (data?['onlineEnabled'] ?? true) as bool;
    });

    await _setStatus(true);
  }

  Future<void> stop() async {
    if (_uid == null) return;
    await _setStatus(false, updateLastSeen: true);
    _userSub?.cancel();
    _userSub = null;
    WidgetsBinding.instance.removeObserver(this);
    _uid = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_uid == null) return;
    if (state == AppLifecycleState.resumed) {
      _setStatus(true);
    } else {
      _setStatus(false, updateLastSeen: true);
    }
  }

  Future<void> _setStatus(bool online, {bool updateLastSeen = false}) async {
    if (_uid == null) return;
    await _fs.collection('users').doc(_uid!).set({
      'isOnline': _onlineEnabled ? online : false,
      if (updateLastSeen) 'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
