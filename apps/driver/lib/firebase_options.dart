// Generated from Firebase client configs (google-services.json + GoogleService-Info.plist).
// Re-run `flutterfire configure` after adding/removing Firebase apps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfm1nkk1H_LygQ70J2N3S8fnxudqfeDR4',
    appId: '1:486543076754:android:8c958cd60d92ab14f8654b',
    messagingSenderId: '486543076754',
    projectId: 'heycaby-2457a',
    storageBucket: 'heycaby-2457a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAsG4VNXULsaeIt_3_lFAJmHluwb_HcVHM',
    appId: '1:486543076754:ios:3ace36dd14fe75cff8654b',
    messagingSenderId: '486543076754',
    projectId: 'heycaby-2457a',
    storageBucket: 'heycaby-2457a.firebasestorage.app',
    iosBundleId: 'nl.heycaby.driver',
  );
}
