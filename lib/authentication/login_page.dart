import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../TabPages/home_page.dart';
import '../bottom_nav_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const BottomNavScreen(),
        ),
      );
    } catch (e) {
      // Handle error
      print(e);
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
