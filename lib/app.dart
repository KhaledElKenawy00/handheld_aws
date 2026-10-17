import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/ref_style.dart';
import 'features/license/boot_gate.dart';

class SanadApp extends StatelessWidget {
  final List<NavigatorObserver> navigatorObservers;
  const SanadApp({super.key, this.navigatorObservers = const []});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SANAD — سند',
      debugShowCheckedModeBanner: false,
      navigatorObservers: navigatorObservers,
      theme: RefTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // تصغير عام لحجم الخط (0.85) — مريح للشاشات الصغيرة
        // ويقلل احتمالات الـ overflow في كل الشاشات.
        final mq = MediaQuery.of(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: mq.copyWith(
                textScaler: const TextScaler.linear(0.85)),
            child: child!,
          ),
        );
      },
      home: const BootGate(),
    );
  }
}
