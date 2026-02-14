import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../bottom_nav_screen.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Step 1: Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return; // User cancelled
      }

      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Step 3: Create credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = userCredential.user;

      if (user != null) {
        // Step 5: Store user details in Realtime Database
        DatabaseReference userRef = FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(user.uid);

        await userRef.set({
          "uid": user.uid,
          "name": user.displayName,
          "email": user.email,
          "photoURL": user.photoURL,
          "phoneNumber": user.phoneNumber,
          "isEmailVerified": user.emailVerified,
          "providerId": user.providerData.isNotEmpty
              ? user.providerData[0].providerId
              : null,
          "creationTime": user.metadata.creationTime?.toString(),
          "lastSignInTime": user.metadata.lastSignInTime?.toString(),
          "accessToken": googleAuth.accessToken,
          "idToken": googleAuth.idToken,
          "timestamp": DateTime.now().toString(),
        });
      }

      // Step 6: Navigate to Bottom Nav Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const BottomNavScreen(),
        ),
      );
    } catch (e) {
      print("Error during Google Sign-In: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Sign-In Failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/images/splash.jpeg'),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () => _signInWithGoogle(context),
              icon: Image.asset('assets/images/google_logo.png', height: 24.0),
              label: const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
