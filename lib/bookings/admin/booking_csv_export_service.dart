import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BookingCsvExportService {
  static const String utf8Bom = '\uFEFF';

  static String _escape(dynamic val) {
    if (val == null) return '""';
    final s = val.toString().replaceAll('"', '""');
    return '"$s"';
  }

  static String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      DateTime dt;
      if (dateVal is DateTime) {
        dt = dateVal;
      } else if (dateVal is num) {
        dt = DateTime.fromMillisecondsSinceEpoch(dateVal.toInt());
      } else if (dateVal is String) {
        dt = DateTime.tryParse(dateVal) ?? DateTime.now();
      } else {
        final dynamic ts = dateVal;
        if (ts.toDate != null && ts.toDate is Function) {
          dt = ts.toDate() as DateTime;
        } else {
          return dateVal.toString();
        }
      }
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } catch (_) {
      return dateVal.toString();
    }
  }

  static String _translateCategory(dynamic cat) {
    switch (cat?.toString().toLowerCase()) {
      case 'chalet':
        return 'شاليه';
      case 'farm':
        return 'مزرعة';
      case 'hall':
        return 'قاعة';
      default:
        return cat?.toString() ?? 'غير محدد';
    }
  }

  static String _translateStatus(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'requested':
        return 'طلب جديد';
      case 'held':
        return 'بانتظار التحويل';
      case 'payment_review':
        return 'قيد المراجعة المالية';
      case 'payment_rejected':
        return 'إيصال مرفوض';
      case 'confirmed':
        return 'مؤكد';
      case 'arrived':
        return 'قيد الإشغال (تم الدخول)';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'rejected':
        return 'مرفوض';
      case 'expired':
        return 'منتهي الصلاحية';
      case 'cancel_requested':
        return 'طلب إلغاء';
      default:
        return status?.toString() ?? 'غير معروف';
    }
  }

  static String _translateLedgerType(dynamic action) {
    switch (action?.toString().toLowerCase()) {
      case 'confirm_payment':
      case 'confirmPayment':
      case 'deposit_confirmed':
        return 'تأكيد عربون';
      case 'reject_payment':
      case 'rejectPayment':
      case 'deposit_rejected':
        return 'رفض إيصال';
      case 'settle_refund':
      case 'settleRefund':
      case 'refund':
        return 'استرداد زبون';
      case 'settle_owner':
      case 'settleOwner':
      case 'owner_payout':
        return 'تسوية مالك';
      case 'commission':
        return 'عمولة المنصة';
      default:
        return action?.toString() ?? 'قيد مالي';
    }
  }

  /// Exports bookings list to CSV format with UTF-8 BOM
  static String generateBookingsCsv(List<Map<String, dynamic>> bookings) {
    final headers = [
      'رقم الحجز',
      'تاريخ الإنشاء',
      'المكان',
      'النوع',
      'اسم الزبون',
      'هاتف الزبون',
      'اسم المالك',
      'تاريخ الوصول',
      'تاريخ المغادرة',
      'الإجمالي (د.ع)',
      'العربون (د.ع)',
      'المتبقي (د.ع)',
      'الحالة',
    ];
    final buffer = StringBuffer(utf8Bom);
    buffer.writeln(headers.map(_escape).join(','));

    for (final b in bookings) {
      final total = (b['total'] ?? b['price'] ?? 0) as num;
      final deposit = (b['deposit'] ?? 0) as num;
      final paid = (b['paid'] ?? deposit) as num;
      final remaining = total - paid;
      final row = [
        b['id'] ?? b['bookingId'] ?? '',
        _formatDate(b['createdAt']),
        b['venueName'] ?? b['venueId'] ?? '',
        _translateCategory(b['category']),
        b['customerName'] ?? b['guestName'] ?? '',
        b['customerPhone'] ?? b['phone'] ?? '',
        b['ownerName'] ?? b['ownerId'] ?? '',
        _formatDate(b['start'] ?? b['startDate']),
        _formatDate(b['end'] ?? b['endDate']),
        total,
        deposit,
        remaining > 0 ? remaining : 0,
        _translateStatus(b['status']),
      ];
      buffer.writeln(row.map(_escape).join(','));
    }
    return buffer.toString();
  }

  /// Exports financial ledger list to CSV format with UTF-8 BOM
  static String generateLedgerCsv(List<Map<String, dynamic>> entries) {
    final headers = [
      'معرف القيد',
      'التاريخ',
      'رقم الحجز',
      'نوع العملية',
      'المبلغ (د.ع)',
      'المرجع المحاسبي',
      'المراجع المالي',
    ];
    final buffer = StringBuffer(utf8Bom);
    buffer.writeln(headers.map(_escape).join(','));

    for (final e in entries) {
      final row = [
        e['id'] ?? '',
        _formatDate(e['timestamp'] ?? e['createdAt']),
        e['bookingId'] ?? '',
        _translateLedgerType(e['action'] ?? e['type']),
        e['amount'] ?? 0,
        e['reference'] ?? e['auditRef'] ?? '',
        e['actorUid'] ?? e['reviewerUid'] ?? e['settledBy'] ?? '',
      ];
      buffer.writeln(row.map(_escape).join(','));
    }
    return buffer.toString();
  }

  static Future<File> saveCsvFile({
    required String fileName,
    required String csvContent,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent, encoding: utf8);
    return file;
  }

  static Future<void> exportAndShareCsv(
    BuildContext context, {
    required String fileName,
    required String csvContent,
    required String title,
  }) async {
    try {
      final file = await saveCsvFile(fileName: fileName, csvContent: csvContent);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: title,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ملف CSV بنجاح:\n${file.path}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر تصدير الملف: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
