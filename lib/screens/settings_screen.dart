// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'owner_profile_screen.dart';
import 'archived_students_screen.dart';
import '../widgets/common_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  final FirestoreService firestoreService;
  final UserRole userRole;

  SettingsScreen({
    required this.firestoreService,
    required this.userRole,
    Key? key,
  }) : super(key: key);

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          if (userRole == UserRole.owner)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Owner Profile & Fee Settings'),
              subtitle: const Text('Manage your details and fee rules'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OwnerProfileScreen(firestoreService: firestoreService),
                  ),
                );
              },
            ),
          if (userRole == UserRole.owner)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              subtitle: const Text('Update your login password'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OwnerProfileScreen(firestoreService: firestoreService, showPasswordSection: true),
                  ),
                );
              },
            ),

          if (userRole == UserRole.owner)
            ListTile(
              leading: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text('View Archived Students'),
              subtitle: const Text('Access records of past students'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArchivedStudentsScreen(
                      firestoreService: firestoreService,
                      userRole: userRole,
                    ),
                  ),
                );
              },
            ),
          if (userRole == UserRole.owner) const Divider(),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            subtitle: const Text('Version 7.8.8'),
            onTap: () {},
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Center(
              child: Text(
                'CONECT! TO DEV.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Image.asset(
                  'assets/icons/linkedin.png',
                  width: 24.0,
                  height: 24.0,
                ),
                onPressed: () {
                  _launchURL('https://www.linkedin.com/in/nihar-landge/');
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Image.asset(
                  'assets/icons/x.png',
                  width: 24.0,
                  height: 24.0,
                ),
                onPressed: () {
                  _launchURL('https://x.com/landge_nihar/');
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}