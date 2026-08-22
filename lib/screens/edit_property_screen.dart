import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/currency.dart';

class EditPropertyScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditPropertyScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  late TextEditingController titleController;
  late TextEditingController locationController;
  late TextEditingController priceController;
  late TextEditingController descriptionController;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.data['title'],
    );

    locationController = TextEditingController(
      text: widget.data['location'],
    );

    priceController = TextEditingController(
      text: iqd(widget.data['price']),
    );

    descriptionController = TextEditingController(
      text: widget.data['description'],
    );
  }

  Future<void> save() async {
    setState(() {
      loading = true;
    });

    await FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.docId)
        .update({
      'title': titleController.text,

      'location': locationController.text,

      'price': double.tryParse(priceController.text) ?? 0,

      'description': descriptionController.text,

      // يرجع للمراجعة بعد التعديل
      'status': 'pending',
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل العقار'),
        backgroundColor: const Color(0xff0D47A1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان العقار',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'الموقع',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'السعر',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'الوصف',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : save,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'حفظ التعديلات',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
