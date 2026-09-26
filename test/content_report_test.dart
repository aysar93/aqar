import 'package:aqar/reports/content_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy office reports remain actionable without new fields', () {
    final r = ContentReport('old', true, {'officeId': 'office1', 'userId': 'u', 'status': 'pending'});
    expect(r.title, 'مكتب • office1');
    expect(r.reason, 'بلاغ سابق دون تحديد السبب');
    expect(r.isOpen, isTrue);
    expect(r.createdAt, isNull);
    expect(r.collection, 'office_reports');
  });
  test('property report status and timestamp normalization', () {
    final date = DateTime.utc(2026, 9, 26);
    final r = ContentReport('new', false, {'propertyId':'p', 'targetTitle':'بيت', 'status':'resolved', 'createdAt':Timestamp.fromDate(date)});
    expect(r.targetId, 'p');
    expect(r.title, 'بيت');
    expect(r.isOpen, isFalse);
    expect(r.createdAt?.toUtc(), date);
  });
}
