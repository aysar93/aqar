import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/chat_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/property_details.dart';
import '../office/screens/office_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/admin/admin_chat_screen.dart';

class NotificationNavigationService {
  NotificationNavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // يمنع تراكم الصفحات عند الضغط المتكرر على نفس الإشعار.
  static bool _navigationInProgress = false;
  static String _lastHandledKey = '';
  static DateTime? _lastHandledAt;
  static bool _storageReady = false;
  static Set<String> _handledNotificationIds = <String>{};

  static Future<void> _loadHandledNotifications() async {
    if (_storageReady) return;
    final prefs = await SharedPreferences.getInstance();
    _handledNotificationIds =
        (prefs.getStringList('handled_notification_ids') ?? <String>[]).toSet();
    _storageReady = true;
  }

  static Future<void> _markHandled(String key) async {
    if (key.isEmpty) return;
    await _loadHandledNotifications();
    _handledNotificationIds.add(key);
    final values = _handledNotificationIds.toList();
    if (values.length > 100) {
      values.removeRange(0, values.length - 100);
      _handledNotificationIds = values.toSet();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'handled_notification_ids',
      _handledNotificationIds.toList(),
    );
  }

  static Map<String, dynamic> _normalizePayload(
    Map<String, dynamic> raw,
  ) {
    final normalized = <String, dynamic>{...raw};
    final nested = raw['data'];

    if (nested is Map) {
      for (final entry in nested.entries) {
        normalized.putIfAbsent(
          entry.key.toString(),
          () => entry.value,
        );
      }
    }

    return normalized;
  }

  static String _notificationKey(
    Map<String, dynamic> data,
  ) {
    final notificationId = (data['notificationId'] ?? '').toString().trim();

    if (notificationId.isNotEmpty) {
      return 'notification:$notificationId';
    }

    return [
      (data['type'] ?? 'general').toString(),
      (data['propertyId'] ?? '').toString(),
      (data['officeId'] ?? '').toString(),
      (data['chatId'] ?? '').toString(),
      (data['title'] ?? '').toString(),
    ].join('|');
  }

  /// تستخدم عندما نملك BuildContext، مثل الضغط على إشعار
  /// من داخل NotificationsScreen.
  static Future<void> handleNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    await _navigate(
      context: context,
      data: _normalizePayload(data),
    );
  }

  /// تستخدم عند الضغط على Push Notification.
  /// لا تحتاج BuildContext لأننا نستخدم navigatorKey.
  static Future<void> handlePushNotification(
    Map<String, dynamic> data,
  ) async {
    final context = navigatorKey.currentContext;

    if (context == null) {
      debugPrint(
        'NotificationNavigationService: Navigator is not ready.',
      );
      return;
    }

    await _navigate(
      context: context,
      data: _normalizePayload(data),
    );
  }

  static Future<void> _navigate({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) async {
    if (_navigationInProgress) {
      return;
    }

    await _loadHandledNotifications();

    final notificationKey = _notificationKey(data);
    final now = DateTime.now();

    if (_handledNotificationIds.contains(notificationKey)) {
      debugPrint('Notification already handled: $notificationKey');
      return;
    }

    if (_lastHandledKey == notificationKey &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(milliseconds: 1500)) {
      return;
    }

    _navigationInProgress = true;
    _lastHandledKey = notificationKey;
    _lastHandledAt = now;
    await _markHandled(notificationKey);

    try {
      final type = (data['type'] ?? 'general').toString().trim();

      final propertyId = (data['propertyId'] ?? '').toString().trim();

      final officeId = (data['officeId'] ?? '').toString().trim();

      final chatId = (data['chatId'] ?? '').toString().trim();

      debugPrint(
        'Notification clicked: '
        'type=$type, '
        'propertyId=$propertyId, '
        'officeId=$officeId, '
        'chatId=$chatId',
      );

      switch (type) {
        // ============================
        // عقار تمت الموافقة عليه
        // ============================
        case 'property_approved':
          if (propertyId.isNotEmpty) {
            await _openProperty(
              context,
              propertyId,
            );
          } else {
            _showMessage(
              context,
              'تعذر تحديد العقار',
            );
          }
          break;

        // ============================
        // عقار تم رفضه
        // ============================
        case 'property_rejected':
          if (propertyId.isNotEmpty) {
            await _openProperty(
              context,
              propertyId,
            );
          } else {
            _showMessage(
              context,
              'تعذر تحديد العقار',
            );
          }
          break;

        // ============================
        // النوع القديم
        // ============================
        case 'property':
          if (propertyId.isNotEmpty) {
            await _openProperty(
              context,
              propertyId,
            );
          } else {
            _showMessage(
              context,
              'هذا إشعار قديم ولا يحتوي على معرف العقار',
            );
          }
          break;

        // ============================
        // تعليق جديد
        // ============================
        case 'comment':
          if (propertyId.isNotEmpty) {
            await _openProperty(
              context,
              propertyId,
            );
          } else {
            _showMessage(
              context,
              'تعذر تحديد العقار المرتبط بالتعليق',
            );
          }
          break;

        // ============================
        // رد على تعليق
        // ============================
        case 'reply':
          if (propertyId.isNotEmpty) {
            await _openProperty(
              context,
              propertyId,
            );
          } else {
            _showMessage(
              context,
              'تعذر تحديد العقار المرتبط بالرد',
            );
          }
          break;

        // ============================
        // مكتب محدد
        // ============================
        case 'office':
        case 'office_notification':
        case 'office_approved':
          if (officeId.isNotEmpty) {
            await _openOffice(context, officeId);
          } else {
            _showMessage(
              context,
              'تعذر تحديد المكتب',
            );
          }
          break;

        // ============================
        // رسالة محادثة
        // ============================
        case 'chat_message':
        case 'chat':
          if (chatId.isNotEmpty) {
            await _openChat(
              context,
              chatId: chatId,
            );
          } else {
            _showMessage(
              context,
              'تعذر تحديد المحادثة',
            );
          }
          break;

        // ============================
        // إشعار عام
        // ============================
        case 'general':
        default:
          await _openNotifications(context);
          break;
      }
    } finally {
      _navigationInProgress = false;
    }
  }

  // =========================================================
  // فتح العقار
  // =========================================================

  static Future<void> _openProperty(
    BuildContext context,
    String propertyId,
  ) async {
    try {
      final snapshot =
          await _firestore.collection('properties').doc(propertyId).get();

      if (!snapshot.exists) {
        if (context.mounted) {
          _showMessage(
            context,
            'العقار غير موجود أو تم حذفه',
          );
        }
        return;
      }

      final data = snapshot.data();

      if (data == null) {
        if (context.mounted) {
          _showMessage(
            context,
            'تعذر تحميل بيانات العقار',
          );
        }
        return;
      }

      if (!context.mounted) {
        return;
      }

      final images = _asList(data['images']);

      final imageUrl = (data['imageUrl'] ?? '').toString();

      final mainImage = imageUrl.isNotEmpty
          ? imageUrl
          : images.isNotEmpty
              ? images.first.toString()
              : '';

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PropertyDetails(
            docId: snapshot.id,
            imageUrl: mainImage,
            title: (data['title'] ?? '').toString(),
            location: (data['location'] ?? '').toString(),
            price: (data['price'] ?? 0).toString(),
            negotiable: data['negotiable'] == true,
            rooms: _asInt(data['rooms']),
            bathrooms: _asInt(data['bathrooms']),
            area: _asInt(data['area']),
            frontage: (data['frontage'] as num?)?.toDouble(),
            depth: (data['depth'] as num?)?.toDouble(),
            floors: (data['floors'] as num?)?.toInt(),
            apartmentFloor: (data['apartmentFloor'] as num?)?.toInt(),
            unitsCount: (data['unitsCount'] as num?)?.toInt(),
            livingRooms: _asInt(data['livingRooms']),
            parking: _asInt(data['parking']),
            description: (data['description'] ?? '').toString(),
            ownerPhone: (data['ownerPhone'] ?? '').toString(),
            ownerWhatsapp: (data['ownerWhatsapp'] ?? '').toString(),
            publisherUid:
                (data['publisherUid'] ?? data['userId'] ?? '').toString(),
            publisherName: (data['publisherName'] ?? '').toString(),
            publisherEmail: (data['publisherEmail'] ?? '').toString(),
            publisherPhone: (data['publisherPhone'] ?? '').toString(),
            publisherWhatsapp: (data['publisherWhatsapp'] ?? '').toString(),
            images: images,
            features: _asList(data['features']),
            documentType: (data['documentType'] ?? '').toString(),
            furnitureStatus: (data['furnitureStatus'] ?? '').toString(),
            propertyType: (data['propertyType'] ?? '').toString(),
            adType: (data['adType'] ?? '').toString(),
            city: (data['city'] ?? '').toString(),
            areaName: (data['areaName'] ?? '').toString(),
            landmark: (data['landmark'] ?? '').toString(),
            latitude: _asDouble(
              data['latitude'] ??
                  _nestedValue(
                    data['locationData'],
                    'latitude',
                  ),
            ),
            longitude: _asDouble(
              data['longitude'] ??
                  _nestedValue(
                    data['locationData'],
                    'longitude',
                  ),
            ),
            isVerified: data['isVerified'] == true,
            isFeatured: data['isFeatured'] == true,
            availabilityStatus:
                (data['availabilityStatus'] ?? 'available').toString(),
            views: _asInt(data['views']),
            createdAt: data['createdAt'] is Timestamp
                ? data['createdAt'] as Timestamp
                : null,
            buildYear: _asInt(data['buildYear']),
            propertyNumber: _asInt(data['adNumber'] ?? data['propertyNumber']),
            isFavorite: false,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Open property Firebase error: '
        '${e.code} - ${e.message}',
      );

      if (context.mounted) {
        _showMessage(
          context,
          'حدث خطأ أثناء تحميل العقار',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Open property error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (context.mounted) {
        _showMessage(
          context,
          'تعذر فتح العقار',
        );
      }
    }
  }

  // =========================================================
  // فتح المكتب المرتبط بالإشعار
  // =========================================================

  static Future<void> _openOffice(
    BuildContext context,
    String officeId,
  ) async {
    try {
      final snapshot =
          await _firestore.collection('offices').doc(officeId).get();

      if (!snapshot.exists) {
        if (context.mounted) {
          _showMessage(
            context,
            'المكتب غير موجود أو تم حذفه',
          );
        }
        return;
      }

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OfficeProfileScreen(
            officeId: snapshot.id,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Open office Firebase error: '
        '${e.code} - ${e.message}',
      );

      if (context.mounted) {
        _showMessage(
          context,
          'حدث خطأ أثناء تحميل المكتب',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Open office error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (context.mounted) {
        _showMessage(
          context,
          'تعذر فتح المكتب',
        );
      }
    }
  }

  // =========================================================
  // فتح المحادثة
  // =========================================================

  static Future<void> _openChat(
    BuildContext context, {
    required String chatId,
  }) async {
    if (!context.mounted) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      // معرفة هل الحساب الحالي أدمن
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final isAdmin = userDoc.data()?['isAdmin'] == true;

      if (!context.mounted) {
        return;
      }

      // المستخدم العادي
      if (!isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ChatScreen(),
          ),
        );

        return;
      }

      // الأدمن يحتاج chatId لتحديد المحادثة
      if (chatId.trim().isEmpty) {
        _showMessage(
          context,
          'تعذر تحديد المحادثة',
        );
        return;
      }

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        if (context.mounted) {
          _showMessage(
            context,
            'المحادثة غير موجودة',
          );
        }
        return;
      }

      final chatData = chatDoc.data() ?? <String, dynamic>{};

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminChatScreen(
            userId: chatId,
            chatData: chatData,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Open chat error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (context.mounted) {
        _showMessage(
          context,
          'تعذر فتح المحادثة',
        );
      }
    }
  }

  // =========================================================
  // فتح شاشة الإشعارات
  // =========================================================

  static Future<void> _openNotifications(
    BuildContext context,
  ) async {
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  // =========================================================
  // Helpers
  // =========================================================

  static List<dynamic> _asList(
    dynamic value,
  ) {
    if (value is List) {
      return List<dynamic>.from(value);
    }

    return <dynamic>[];
  }

  static int _asInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  static double _asDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  static dynamic _nestedValue(
    dynamic value,
    String key,
  ) {
    if (value is Map<String, dynamic>) {
      return value[key];
    }

    if (value is Map) {
      return value[key];
    }

    return null;
  }

  static void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
