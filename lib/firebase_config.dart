/// Firebase project configuration for the `fir-paid` project.
///
/// These values are the public web-app credentials from the Firebase console
/// (they are safe to ship in a client). The app talks to Firebase
/// Authentication through its REST API using [apiKey], so no
/// `google-services.json` / FlutterFire setup is needed on Android.
abstract final class FirebaseConfig {
  static const String apiKey = 'AIzaSyCRY8opcE70ALOXe_gidSDZDdQS5Vw6hLk';
  static const String authDomain = 'fir-paid.firebaseapp.com';
  static const String projectId = 'fir-paid';
  static const String storageBucket = 'fir-paid.firebasestorage.app';
  static const String messagingSenderId = '590550754019';
  static const String appId = '1:590550754019:web:707df1fdadece0228edbd6';

  /// Identity Toolkit endpoint for an account method, e.g. `signUp`.
  static Uri accountUri(String method) => Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:$method?key=$apiKey',
      );

  /// Exchanges a refresh token for a fresh ID token.
  static Uri get secureTokenUri => Uri.parse(
        'https://securetoken.googleapis.com/v1/token?key=$apiKey',
      );
}
