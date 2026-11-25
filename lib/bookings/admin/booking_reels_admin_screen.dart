import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tabs/booking_admin_reels_tab.dart';
import 'booking_admin_theme.dart';

class BookingReelsAdminScreen extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reelsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reportsStream;

  const BookingReelsAdminScreen({
    super.key,
    this.reelsStream,
    this.reportsStream,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookingAdminTheme.bg(context),
      appBar: AppBar(
        title: Text(
          'إدارة ريلزات الحجوزات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 18,
            color: BookingAdminTheme.text(context),
          ),
        ),
        centerTitle: true,
        backgroundColor: BookingAdminTheme.header(context),
        foregroundColor: BookingAdminTheme.text(context),
        elevation: 0,
      ),
      body: BookingAdminReelsTab(
        reelsStream: reelsStream,
        reportsStream: reportsStream,
      ),
    );
  }
}
