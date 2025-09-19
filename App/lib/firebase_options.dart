import 'package:firebase_core/firebase_core.dart';
import 'config/firebase_config.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => AppFirebaseConfig.android;
}
