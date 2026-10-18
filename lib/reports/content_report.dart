import 'package:cloud_firestore/cloud_firestore.dart';

const reportReasons = [
  'معلومات مضللة أو غير صحيحة',
  'احتيال أو طلبات مشبوهة',
  'محتوى غير مناسب',
  'انتهاك حقوق أو انتحال هوية',
  'إعلان مكرر أو غير متاح',
  'سبب آخر'
];
const reportStatuses = {
  'pending': 'جديد',
  'in_review': 'قيد المراجعة',
  'resolved': 'تمت المعالجة',
  'dismissed': 'مغلق دون إجراء'
};

class ContentReport {
  ContentReport(this.id, this.isOffice, this.data);
  final String id;
  final bool isOffice;
  final Map<String, dynamic> data;
  String get collection => isOffice ? 'office_reports' : 'property_reports';
  String get targetId =>
      (data[isOffice ? 'officeId' : 'propertyId'] ?? '').toString();
  String get kind => isOffice ? 'مكتب' : 'عقار';
  String get title => data['targetTitle']?.toString().trim().isNotEmpty == true
      ? data['targetTitle'].toString()
      : '$kind • $targetId';
  String get reason =>
      (data['reason'] ?? 'بلاغ سابق دون تحديد السبب').toString();
  String get status => (data['status'] ?? 'pending').toString();
  bool get isOpen => status == 'pending' || status == 'in_review';
  DateTime? get createdAt => data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate()
      : null;
}
