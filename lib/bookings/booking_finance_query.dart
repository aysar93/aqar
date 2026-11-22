import 'package:cloud_firestore/cloud_firestore.dart';

Query<Map<String, dynamic>> bookingFinanceQueue(
        Query<Map<String, dynamic>> bookings) =>
    bookings.where('status', whereIn: [
      'payment_review',
      'cancel_requested',
      'cancelled',
      'completed'
    ]);
