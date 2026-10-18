import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notification_navigation_service.dart';

/// خدمة معالجة Deep Links القادمة من مسح QR أو فتح رابط عقار
///
/// عند فتح رابط:
/// https://aysar93.github.io/aqar-pages/property/?id=<propertyDocId>
///
/// يُفتح التطبيق مباشرة على صفحة تفاصيل ذلك العقار.
class DeepLinkService {
  DeepLinkService._();

  static const _channel = MethodChannel('app/deeplink');
  static String? _pendingPropertyId;

  /// تُستدعى مرة واحدة عند بدء التطبيق
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethod);
    // محاولة قراءة أي رابط كان منتظراً عند الإطلاق
    _channel.invokeMethod<String?>('getInitialLink').then((link) {
      if (link != null) _processLink(link);
    }).catchError((_) {
      // المنصة لا تدعم القناة — لا يؤثر على بقية التطبيق
    });
  }

  /// يُستدعى عند وصول رابط والتطبيق نشط
  static Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == 'onLink') {
      final link = call.arguments as String?;
      if (link != null) _processLink(link);
    }
  }

  /// تحليل الرابط واستخراج معرّف العقار
  static void _processLink(String link) {
    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return;

      // نتوقع: /aqar-pages/property/?id=<docId>
      if (uri.host == 'aysar93.github.io' &&
          uri.path.contains('/aqar-pages/property/')) {
        final id = uri.queryParameters['id'];
        if (id != null && id.trim().isNotEmpty) {
          _pendingPropertyId = id.trim();
          _tryNavigate();
        }
      }
    } catch (e) {
      debugPrint('DeepLinkService._processLink error: $e');
    }
  }

  /// يُستدعى من SplashScreen أو الشاشة الرئيسية لتنفيذ الانتقال المعلّق
  static void tryHandlePendingLink() {
    if (_pendingPropertyId != null) {
      _tryNavigate();
    }
  }

  static void _tryNavigate() {
    final context = NotificationNavigationService.navigatorKey.currentContext;
    if (context == null) return;

    final id = _pendingPropertyId;
    if (id == null) return;
    _pendingPropertyId = null;

    _openPropertyById(context, id);
  }

  /// فتح صفحة تفاصيل العقار عبر معرّفه في Firestore
  static Future<void> _openPropertyById(BuildContext context, String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(id)
          .get();

      if (!doc.exists) {
        debugPrint('DeepLinkService: property $id not found');
        return;
      }

      // نستخدم _openProperty الموجودة في NotificationNavigationService
      // عبر استدعاء handleNotification بنوع 'property'
      if (context.mounted) {
        await NotificationNavigationService.handleNotification(context, {
          'type': 'property',
          'propertyId': id,
        });
      }
    } catch (e) {
      debugPrint('DeepLinkService._openPropertyById error: $e');
    }
  }
}
