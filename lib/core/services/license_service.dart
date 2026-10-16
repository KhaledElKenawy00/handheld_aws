import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../utils/app_utils.dart';
import 'settings_service.dart';

/// نتيجة تقييم الترخيص عند الإقلاع/الفحص.
enum LicenseState {
  noLicense, // لا يوجد كود — شاشة التفعيل
  ok, // ساري — دخول عادي
  expired, // انتهت المدة — قفل برسالة التجديد
  disabled, // موقوف من الإدارة — قفل
}

/// خدمة تراخيص النظام عبر Supabase — أوفلاين أولًا:
/// التفعيل أول مرة يحتاج نت، وبعده التطبيق يعمل بدون نت.
/// القفل يحدث عند انتهاء المدة (بتايمر محلي حتى لو أوفلاين)
/// أو عند الإيقاف من الإدارة (يُكتشف مع أول اتصال).
class LicenseService {
  final SettingsService _settings = SettingsService();

  SupabaseClient get _sb => Supabase.instance.client;

  /// سيريال الجهاز (للربط والعرض في لوحة الإدارة).
  /// Android ID ثابت لكل جهاز (سيريال الهاردوير محجوب في أندرويد 10+).
  Future<String> deviceSerial() async {
    try {
      if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        if (a.id.trim().isNotEmpty) return a.id.trim();
      }
    } catch (_) {}
    return 'unknown';
  }

  /// وصف الجهاز للعرض (الموديل + الشركة).
  Future<String> deviceLabel() async {
    try {
      if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        return '${a.manufacturer} ${a.model}'.trim();
      }
    } catch (_) {}
    return '';
  }

  /// هل يوجد اتصال فعلي بالشبكة؟ (فحص سريع قبل أي RPC).
  Future<bool> get hasNet async {
    try {
      final c = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      return !c.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// استدعاء دالة RPC — يُرجع null لو مفيش نت/مهلة (يُعامل أوفلاين).
  Future<Map<String, dynamic>?> _rpc(
      String fn, Map<String, dynamic> params) async {
    try {
      final res = await _sb
          .rpc(fn, params: params)
          .timeout(const Duration(seconds: 8));
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// تفعيل كود جديد (يحتاج نت) وربطه بسيريال الجهاز.
  Future<void> activate(String code) async {
    final c = code.trim();
    if (c.isEmpty) throw const AppFailure('ادخل كود التفعيل');
    if (!await hasNet) {
      throw const AppFailure('مفيش نت — التفعيل أول مرة محتاج إنترنت');
    }
    final serial = await deviceSerial();
    final r = await _rpc(
        'activate_license', {'p_code': c, 'p_serial': serial});
    if (r == null) {
      throw const AppFailure('تعذر الوصول لسيرفر التفعيل — حاول تاني');
    }
    if (r['ok'] != true) {
      switch (r['reason']) {
        case 'disabled':
          throw const AppFailure('الكود ده موقوف — كلم الإدارة');
        case 'bound_other':
          throw const AppFailure('الكود متفعل على جهاز تاني');
        default:
          throw const AppFailure('كود غلط — اتأكد وحاول تاني');
      }
    }
    await _settings.set(AppConstants.kLicCode, c);
    await _settings.set(AppConstants.kLicSerial, serial);
    await _settings.set(AppConstants.kLicStatus, 'active');
    await _settings.set(AppConstants.kLicExpires,
        (r['expires_at'] ?? '').toString());
    await _settings.set(
        AppConstants.kLicLastSeen, DateTime.now().toIso8601String());
  }

  /// مسح بيانات الترخيص المحلية (الكود اتمسح من السيرفر).
  Future<void> clearLicense() async {
    await _settings.delete(AppConstants.kLicCode);
    await _settings.delete(AppConstants.kLicExpires);
    await _settings.delete(AppConstants.kLicStatus);
    await _settings.delete(AppConstants.kLicSerial);
    await _settings.delete(AppConstants.kLicLastSeen);
  }

  /// تقييم حالة الترخيص: أونلاين يحدّث من السيرفر (بساعة السيرفر
  /// نفسها ضد فرق ساعة الجهاز)، أوفلاين يعتمد على التايمر المحلي
  /// (يكشف انتهاء المدة والتلاعب بالساعة).
  /// لو الكود اتمسح من السيرفر: امسح المحلي وارجع للتفعيل.
  Future<LicenseState> evaluate() async {
    final code =
        (await _settings.get(AppConstants.kLicCode))?.trim() ?? '';
    if (code.isEmpty) return LicenseState.noLicense;
    final now = DateTime.now();

    if (await hasNet) {
      final r = await _rpc('license_status', {'p_code': code});
      if (r != null) {
        if (r['ok'] != true) {
          // الكود غير موجود على السيرفر (اتمسح من الإدارة) —
          // امسح المحلي والجهاز يرجع لصفحة التفعيل.
          await clearLicense();
          return LicenseState.noLicense;
        }
        // ساعة السيرفر هي المرجع (ساعة الجهاز قد تكون متأخرة).
        var effectiveNow = now;
        final srvNow =
            DateTime.tryParse((r['srv_now'] ?? '').toString());
        if (srvNow != null && srvNow.isAfter(effectiveNow)) {
          effectiveNow = srvNow;
        }
        if ((r['status'] ?? '') == 'disabled') {
          await _settings.set(AppConstants.kLicStatus, 'disabled');
          return LicenseState.disabled;
        }
        final srvExp = (r['expires_at'] ?? '').toString();
        await _settings.set(AppConstants.kLicExpires, srvExp);
        await _settings.set(AppConstants.kLicStatus, 'active');
        await _settings.set(AppConstants.kLicLastSeen,
            effectiveNow.toIso8601String());
        final exp = DateTime.tryParse(srvExp);
        if (exp != null && effectiveNow.isAfter(exp)) {
          return LicenseState.expired;
        }
        return LicenseState.ok;
      }
      // فشل التحديث رغم وجود شبكة — كمّل على المحلي أدناه.
    }

    // المسار الأوفلاين: التايمر المحلي + كشف الرجوع بالساعة.
    final lastSeen = DateTime.tryParse(
        (await _settings.get(AppConstants.kLicLastSeen)) ?? '');
    if (lastSeen != null &&
        now.isBefore(lastSeen.subtract(const Duration(days: 1)))) {
      return LicenseState.expired; // تلاعب واضح بالساعة
    }
    if ((await _settings.get(AppConstants.kLicStatus)) == 'disabled') {
      return LicenseState.disabled;
    }
    final exp = DateTime.tryParse(
        (await _settings.get(AppConstants.kLicExpires)) ?? '');
    if (exp != null && now.isAfter(exp)) return LicenseState.expired;
    await _settings.set(
        AppConstants.kLicLastSeen, now.toIso8601String());
    return LicenseState.ok;
  }

  Future<String> localCode() async =>
      (await _settings.get(AppConstants.kLicCode))?.trim() ?? '';

  /// فحص محلي سريع (بدون نت) للتايمر الدوري: منتهي/موقوف/سليم.
  /// يُستخدم كل دقيقة أثناء تشغيل التطبيق لالتقاط انتهاء المدة فورًا.
  Future<LicenseState> checkLocal() async {
    final code =
        (await _settings.get(AppConstants.kLicCode))?.trim() ?? '';
    if (code.isEmpty) return LicenseState.ok;
    if ((await _settings.get(AppConstants.kLicStatus)) == 'disabled') {
      return LicenseState.disabled;
    }
    final now = DateTime.now();
    final lastSeen = DateTime.tryParse(
        (await _settings.get(AppConstants.kLicLastSeen)) ?? '');
    final tampered = lastSeen != null &&
        now.isBefore(
            lastSeen.subtract(const Duration(days: 1)));
    if (tampered) {
      return LicenseState.expired;
    }
    final exp = DateTime.tryParse(
        (await _settings.get(AppConstants.kLicExpires)) ?? '');
    if (exp != null && now.isAfter(exp)) return LicenseState.expired;
    if (lastSeen == null || now.isAfter(lastSeen)) {
      await _settings.set(
          AppConstants.kLicLastSeen, now.toIso8601String());
    }
    return LicenseState.ok;
  }
}
