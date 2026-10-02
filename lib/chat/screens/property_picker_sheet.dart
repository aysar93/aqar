import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/property_model.dart';
import '../widgets/property_chat_card.dart';
import '../../utils/currency.dart';

class PropertyPickerSheet extends StatefulWidget {
  const PropertyPickerSheet({super.key});
  @override
  State<PropertyPickerSheet> createState() => _PropertyPickerSheetState();
}

class _PropertyPickerSheetState extends State<PropertyPickerSheet> {
  final _controller = ScrollController();
  final _query = FirebaseFirestore.instance
      .collection('properties')
      .where('status', isEqualTo: 'approved')
      .orderBy(FieldPath.documentId);
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _properties = [];
  bool _loading = false;
  bool _more = true;
  String _search = '';
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _properties.isEmpty
          ? _query
          : _query.startAfterDocument(_properties.last);
      final snapshot = await query.limit(30).get();
      if (mounted) {
        setState(() {
          _properties.addAll(snapshot.docs);
          _more = snapshot.docs.length == 30;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل العقارات');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _properties.where((doc) {
      final d = doc.data();
      return '${d['title']} ${d['city']} ${d['areaName']} ${d['propertyNumber']}'
          .toLowerCase()
          .contains(_search.toLowerCase());
    }).toList();
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Column(children: [
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('اختر عقاراً لإرساله',
                      style: TextStyle(color: Colors.white, fontSize: 18))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText:
                              'بحث في العقارات المحمّلة بالعنوان أو الرقم',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (v) => setState(() => _search = v))),
              Expanded(
                  child: ListView(controller: _controller, children: [
                for (final doc in matches)
                  ListTile(
                      textColor: Colors.white,
                      title: Text(doc.data()['title'] ?? 'عقار'),
                      subtitle: Text(
                          '${doc.data()['city'] ?? ''} • ${iqd(doc.data()['price'])}'),
                      leading: const Icon(Icons.home_outlined,
                          color: Color(0xFFD4AF37)),
                      onTap: () => Navigator.pop(
                          context,
                          PropertyChatCard.snapshot(
                              PropertyModel.fromMap(doc.data(), doc.id)))),
                if (matches.isEmpty && !_loading)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا توجد نتائج ضمن العقارات المحمّلة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54))),
                if (_error != null)
                  TextButton(
                      onPressed: _load,
                      child: Text('$_error • إعادة المحاولة')),
                if (_loading)
                  const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFD4AF37)))
                else if (_more)
                  TextButton(
                      onPressed: _load,
                      child: const Text('تحميل المزيد من العقارات')),
              ])),
            ])));
  }
}
