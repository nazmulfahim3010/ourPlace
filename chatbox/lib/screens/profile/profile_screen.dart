import 'package:flutter/material.dart';
import 'package:chatbox/core/theme/app_theme.dart';
import 'package:chatbox/models/user.dart';
import 'package:chatbox/repositories/auth_repository.dart';

/// Profile screen displaying anonymous account identity, Love Connection status, and privacy settings
class ProfileScreen extends StatefulWidget {
  final User? currentUser;
  final AuthRepository? authRepository;

  const ProfileScreen({
    super.key,
    this.currentUser,
    this.authRepository,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _hideLoveConnection = false;

  @override
  Widget build(BuildContext context) {
    final username = widget.currentUser?.username ?? '@alex';
    final initial = username.length > 1 ? username[1].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Profile & Privacy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              /// User Identity Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF383838),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Public Identity • Anonymous',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              /// Love Connection Card (Phase 15 Teaser)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2428),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFF6B81).withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.favorite, color: Color(0xFFFF6B81), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Love Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Connected with @twilight',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '0 or 1 active couple connection. Does not automatically grant access to other chats.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hide from visible profile',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Switch(
                          value: _hideLoveConnection,
                          activeThumbColor: const Color(0xFFFF6B81),
                          onChanged: (val) {
                            setState(() {
                              _hideLoveConnection = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              /// Privacy Architecture Info Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                padding: const EdgeInsets.all(16.0),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Privacy Guarantee',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• No Gmail or personal email required\n'
                      '• No phone number or contacts collected\n'
                      '• Chat history is stored locally on device\n'
                      '• Local App Passcode (Phase 8)',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              /// Sign Out Button
              if (widget.authRepository != null)
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await widget.authRepository!.signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF444444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
