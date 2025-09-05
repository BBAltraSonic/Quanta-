import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String? avatarId;
  final String? userId;

  const ProfileScreen({super.key, this.avatarId, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile Screen - Coming Soon')),
    );
  }
}
