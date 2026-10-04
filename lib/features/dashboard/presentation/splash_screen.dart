import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _Sp();
}

class _Sp extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MainShell()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white,
            child: Text('س',
                style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy)),
          ),
          SizedBox(height: 16),
          Text('SANAD',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4)),
          Text('سند — نظام إدارة المخازن',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          SizedBox(height: 24),
          CircularProgressIndicator(color: Colors.white),
        ]),
      ),
    );
  }
}
