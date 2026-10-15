import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
        ),
        child: const SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                child: Text('س',
                    style: TextStyle(
                        fontFamily: AppTextStyles.family,
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark)),
              ),
              SizedBox(height: 16),
              Text('SANAD',
                  style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 5)),
              SizedBox(height: 4),
              Text('سند — نظام إدارة المخازن',
                  style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text('يعمل Offline بالكامل',
                  style: TextStyle(
                      fontFamily: AppTextStyles.family,
                      color: Colors.white70,
                      fontSize: 13)),
              SizedBox(height: 28),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
