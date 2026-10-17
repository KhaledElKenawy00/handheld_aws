import 'package:flutter/material.dart';

import 'scanner_service.dart';

/// يوقف استقبال المسح (ويوقف الماسح والصوت) تلقائيًا طالما فيه حوار أو
/// شيت مفتوح، ويستأنفه أول ما يتقفل.
///
/// السبب: لو ظهرت رسالة (زي "الصنف غير موجود") والمستخدم لسه ما ضغطش
/// "حسنًا" وكمّل مسح، المفروض الماسح يقف والصوت يقطع بدل ما تتزاحم
/// الرسائل وتتفوّت مسحات. مع قفل الرسالة يرجع الماسح شغال عادي.
class ScannerRouteObserver extends NavigatorObserver {
  final ScannerService scanner;
  ScannerRouteObserver(this.scanner);

  int _openModals = 0;
  bool _paused = false;

  void _sync() {
    final paused = _openModals > 0;
    if (paused == _paused) return;
    _paused = paused;
    scanner.setPaused(paused);
  }

  void _opened(Route<dynamic> route) {
    if (route is PopupRoute) {
      _openModals++;
      _sync();
    }
  }

  void _closed(Route<dynamic> route) {
    if (route is PopupRoute && _openModals > 0) {
      _openModals--;
      _sync();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _opened(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _closed(route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _closed(route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _closed(oldRoute);
    if (newRoute != null) _opened(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
