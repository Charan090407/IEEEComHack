import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../authentication/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String name = "";
  String email = "";
  String photoURL = "";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  /// Fetch user data from Realtime Database
  Future<void> _fetchUserData() async {
    if (currentUser == null) return;

    DatabaseReference userRef = FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(currentUser!.uid);

    DataSnapshot snapshot = await userRef.get();

    if (snapshot.exists) {
      Map data = snapshot.value as Map;

      setState(() {
        name = data["name"] ?? "No Name";
        email = data["email"] ?? "No Email";
        photoURL = data["photoURL"] ?? "";
      });
    }
  }

  /// Logout Function
  Future<void> _logout(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      CupertinoPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          "Profile",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.black,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// Profile Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [

                    /// Avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFDCE3F5),
                      backgroundImage: photoURL.isNotEmpty
                          ? NetworkImage(photoURL)
                          : null,
                      child: photoURL.isEmpty
                          ? Text(
                        name.isNotEmpty
                            ? name[0].toUpperCase()
                            : "U",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      )
                          : null,
                    ),

                    const SizedBox(width: 15),

                    /// Name & Email from Database
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            /// Logout Button
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: GestureDetector(
                onTap: () => _logout(context),
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color:
                        CupertinoColors.systemGrey.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "Log Out",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD9534F),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
