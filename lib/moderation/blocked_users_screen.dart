import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
        appBar: AppBar(title: const Text('المستخدمون المحظورون')),
        body: uid == null
            ? const Center(child: Text('سجّل الدخول لإدارة الحظر'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('blockedUsers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(child: Text('تعذر تحميل قائمة الحظر'));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty)
                    return const Center(
                        child: Text('لا يوجد مستخدمون محظورون'));
                  return ListView(
                      children: snapshot.data!.docs
                          .map((doc) => ListTile(
                                title: Text('المستخدم ${doc.id}'),
                                trailing: TextButton(
                                    child: const Text('إلغاء الحظر'),
                                    onPressed: () async {
                                      try {
                                        await doc.reference.delete();
                                      } catch (_) {
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'تعذر إلغاء الحظر، حاول مجدداً')));
                                      }
                                    }),
                              ))
                          .toList());
                },
              ));
  }
}
