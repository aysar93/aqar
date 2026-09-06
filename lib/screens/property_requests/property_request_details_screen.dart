import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PropertyRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const PropertyRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.data,
  });

  @override
  State<PropertyRequestDetailsScreen> createState() =>
      _PropertyRequestDetailsScreenState();
}

class _PropertyRequestDetailsScreenState
    extends State<PropertyRequestDetailsScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  bool _isAdmin = false;

  Map<String, dynamic> get data => widget.data;

  String get requestId => widget.requestId;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _isAdmin = document.data()?['isAdmin'] == true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isAdmin = false;
      });
    }
  }

  Future<void> _confirmDeleteRequest() async {
    final propertyType = _text(
      data['propertyType'],
      fallback: 'العقار',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _card,
            title: const Text(
              'حذف الطلب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف طلب $propertyType نهائيًا؟\n\n'
              'سيختفي الطلب من قسم مطلوب على عقارات الانبار، '
              'ولا يمكن التراجع عن الحذف',
              style: const TextStyle(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('property_requests')
          .doc(requestId)
          .delete();

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      Navigator.pop(context);

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف الطلب بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حذف الطلب: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestType = _text(data['requestType']);
    final propertyType = _text(
      data['propertyType'],
      fallback: 'عقار',
    );
    final requestNumber = _toInt(data['requestNumber']);

    final city = _text(data['city']);
    final district = _text(data['district']);
    final landmark = _text(data['landmark']);

    final phone = _text(data['phone']);
    final whatsapp = _text(data['whatsapp']);

    final description = _text(data['description']);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            "تفاصيل الطلب",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (_isAdmin)
              PopupMenuButton<String>(
                tooltip: 'إدارة الطلب',
                color: _card,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDeleteRequest();
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'حذف الطلب',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              30,
            ),
            children: [
              _headerCard(
                requestType: requestType,
                propertyType: propertyType,
                city: city,
                district: district,
              ),
              const SizedBox(height: 16),
              _section(
                title: "الموقع المطلوب",
                icon: Icons.location_on_rounded,
                children: [
                  _detailRow(
                    title: "المدينة",
                    value: _display(city),
                  ),
                  _detailRow(
                    title: "المنطقة",
                    value: _display(district),
                  ),
                  _detailRow(
                    title: "أقرب نقطة دالة",
                    value: _display(landmark),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(
                title: "المساحة والميزانية",
                icon: Icons.account_balance_wallet_rounded,
                children: [
                  _detailRow(
                    title: "المساحة المطلوبة",
                    value: _range(
                      data['minArea'],
                      data['maxArea'],
                      suffix: "م²",
                    ),
                  ),
                  _detailRow(
                    title: "الميزانية",
                    value: _range(
                      data['minPrice'],
                      data['maxPrice'],
                      suffix: "د.ع",
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRequirementsSection(),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                _section(
                  title: "تفاصيل إضافية",
                  icon: Icons.notes_rounded,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: 4,
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _section(
                title: "التواصل",
                icon: Icons.contact_phone_rounded,
                children: [
                  if (phone.isNotEmpty)
                    _contactRow(
                      icon: Icons.phone_rounded,
                      title: "رقم الهاتف",
                      value: phone,
                      onTap: () => _callPhone(
                        context,
                        phone,
                      ),
                    ),
                  if (phone.isNotEmpty && whatsapp.isNotEmpty)
                    const Divider(
                      color: Colors.white10,
                      height: 1,
                    ),
                  if (whatsapp.isNotEmpty)
                    _contactRow(
                      icon: Icons.chat_rounded,
                      title: "واتساب",
                      value: whatsapp,
                      onTap: () => _openWhatsApp(
                        context,
                        whatsapp,
                      ),
                    ),
                  if (phone.isEmpty && whatsapp.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      child: Text(
                        "لا توجد معلومات تواصل متاحة",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (requestNumber != null)
                Center(
                  child: Text(
                    "رقم الطلب: #${_toArabicDigits(requestNumber)}",
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard({
    required String requestType,
    required String propertyType,
    required String city,
    required String district,
  }) {
    final location = [
      city,
      district,
    ].where((value) => value.isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            _gold.withValues(alpha: .16),
            _card,
          ],
        ),
        border: Border.all(
          color: _gold.withValues(alpha: .25),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _gold.withValues(alpha: .22),
                  ),
                ),
                child: Icon(
                  _propertyIcon(propertyType),
                  color: _gold,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "مطلوب على عقارات الانبار",
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _title(
                        requestType,
                        propertyType,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _typeBadge(requestType),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: .12,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: _gold,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementsSection() {
    final items = <MapEntry<String, String>>[];

    _addRequirement(
      items,
      "الغرف",
      data['rooms'],
    );

    _addRequirement(
      items,
      "الحمامات",
      data['bathrooms'],
    );

    _addRequirement(
      items,
      "المجالس",
      data['livingRooms'],
    );

    _addRequirement(
      items,
      "مواقف السيارات",
      data['parking'],
    );

    _addRequirement(
      items,
      "أقل عدد طوابق",
      data['minFloors'],
    );

    _addRequirement(
      items,
      "أعلى عدد طوابق",
      data['maxFloors'],
    );

    _addRequirement(
      items,
      "الطابق المطلوب",
      data['apartmentFloor'],
    );

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _section(
      title: "المواصفات المطلوبة",
      icon: Icons.tune_rounded,
      children: [
        for (int i = 0; i < items.length; i++)
          _detailRow(
            title: items[i].key,
            value: items[i].value,
            showDivider: i != items.length - 1,
          ),
      ],
    );
  }

  void _addRequirement(
    List<MapEntry<String, String>> items,
    String title,
    dynamic value,
  ) {
    if (!_hasValue(value)) return;

    items.add(
      MapEntry(
        title,
        value.toString(),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: _gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow({
    required String title,
    required String value,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            color: Colors.white10,
            height: 1,
          ),
      ],
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: _gold,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    textDirection: ui.TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _gold,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String requestType) {
    final label = requestType.isEmpty ? "طلب" : requestType;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _gold.withValues(alpha: .25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _callPhone(
    BuildContext context,
    String phone,
  ) async {
    final cleaned = _cleanPhone(phone);

    final uri = Uri(
      scheme: 'tel',
      path: cleaned,
    );

    if (!await launchUrl(uri)) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تعذر فتح تطبيق الاتصال",
          ),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(
    BuildContext context,
    String phone,
  ) async {
    final cleaned = _whatsappPhone(phone);

    if (cleaned.isEmpty) return;

    final uri = Uri.parse(
      'https://wa.me/$cleaned',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تعذر فتح واتساب",
          ),
        ),
      );
    }
  }

  String _cleanPhone(String value) {
    return value.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
  }

  String _whatsappPhone(String value) {
    var number = value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // أرقام العراق المحلية:
    // 07XXXXXXXXX -> 9647XXXXXXXXX
    if (number.startsWith('0') && number.length >= 10) {
      number = '964${number.substring(1)}';
    }

    return number;
  }

  String _title(
    String requestType,
    String propertyType,
  ) {
    if (requestType == 'شراء') {
      return "مطلوب $propertyType للشراء";
    }

    if (requestType == 'إيجار') {
      return "مطلوب $propertyType للإيجار";
    }

    return "مطلوب $propertyType";
  }

  String _range(
    dynamic minValue,
    dynamic maxValue, {
    required String suffix,
  }) {
    final min = _toDouble(minValue);
    final max = _toDouble(maxValue);

    if (min == null && max == null) {
      return "غير محدد";
    }

    if (min != null && max != null) {
      if (min == max) {
        return "${_formatNumber(min)} $suffix";
      }

      return "${_formatNumber(min)} - "
          "${_formatNumber(max)} $suffix";
    }

    if (min != null) {
      return "من ${_formatNumber(min)} $suffix";
    }

    return "حتى ${_formatNumber(max!)} $suffix";
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString().trim(),
    );
  }

  String _toArabicDigits(dynamic value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';

    final text = value.toString();

    return text.split('').map((char) {
      final index = western.indexOf(char);

      if (index == -1) {
        return char;
      }

      return arabic[index];
    }).join();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().replaceAll(',', ''),
    );
  }

  String _formatNumber(double value) {
    return NumberFormat('#,##0').format(
      value.round(),
    );
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;

    final text = value.toString().trim();

    if (text.isEmpty) return false;
    if (text == '0') return false;
    if (text.toLowerCase() == 'null') return false;

    return true;
  }

  String _display(String value) {
    return value.trim().isEmpty ? "غير محدد" : value;
  }

  String _text(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  IconData _propertyIcon(
    String propertyType,
  ) {
    switch (propertyType) {
      case 'بيت':
        return Icons.home_rounded;

      case 'شقة':
        return Icons.apartment_rounded;

      case 'أرض':
        return Icons.landscape_rounded;

      case 'محل':
        return Icons.storefront_rounded;

      case 'عمارة':
        return Icons.location_city_rounded;

      case 'مزرعة':
        return Icons.agriculture_rounded;

      default:
        return Icons.real_estate_agent_rounded;
    }
  }
}
