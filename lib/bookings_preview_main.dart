import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'bookings/booking_widgets.dart';

// Local only: no Firebase initialization, credentials or real payment calls.
void main() => runApp(const BookingDesignPreview());

const previewVenue = <String, dynamic>{
  'name': 'شاليه ضفاف الفرات',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'ownerName': 'مالك تجريبي',
  'capacity': 12,
  'bedrooms': 3,
  'price': 250000,
  'deposit': 50000,
  'terms': 'احترام وقت الدخول والخروج والمحافظة على مرافق المكان.',
};
const previewTitles = [
  'الرئيسية',
  'تفاصيل المكان',
  'التقويم',
  'طلب الحجز',
  'الدفع',
  'لوحة المالك',
  'الإدارة والمالية'
];

class BookingDesignPreview extends StatelessWidget {
  const BookingDesignPreview({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale('ar'),
      supportedLocales: [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: BookingPreviewPage());
}

class BookingPreviewPage extends StatefulWidget {
  const BookingPreviewPage({super.key, this.initialPage = 0});
  final int initialPage;
  @override
  State<BookingPreviewPage> createState() => _BookingPreviewPageState();
}

class _BookingPreviewPageState extends State<BookingPreviewPage> {
  late int page = widget.initialPage;
  DateTime? selected;
  Widget panel(String title, String value, IconData icon) =>
      BookingMetricCard(title: title, value: value, icon: icon);
  Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(height: 1.7, color: Color(0xFF64748B)))
      ]));
  Widget calendar() => BookingCalendar(
      month: DateTime(2026, 11),
      slots: [
        for (final day in [5, 6, 13, 20])
          {
            'start': DateTime.utc(2026, 11, day).millisecondsSinceEpoch,
            'end': DateTime.utc(2026, 11, day + 1).millisecondsSinceEpoch,
            'state': 'confirmed'
          },
        {
          'start': DateTime.utc(2026, 11, 9).millisecondsSinceEpoch,
          'end': DateTime.utc(2026, 11, 10).millisecondsSinceEpoch,
          'state': 'pending'
        },
      ],
      intervalForDay: (d) => [
            DateTime.utc(d.year, d.month, d.day),
            DateTime.utc(d.year, d.month, d.day + 1)
          ],
      onSelect: (day) => setState(() => selected = day));
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: Text(previewTitles[page]), actions: [
        PopupMenuButton<int>(
            tooltip: 'شاشات المعاينة',
            onSelected: (v) => setState(() => page = v),
            itemBuilder: (_) => [
                  for (var i = 0; i < previewTitles.length; i++)
                    PopupMenuItem(value: i, child: Text(previewTitles[i]))
                ])
      ]),
      body: Column(children: [
        Container(
            width: double.infinity,
            color: const Color(0xFFF4EEDC),
            padding: const EdgeInsets.all(10),
            child: const Text(
                'معاينة تصميم محلية · بيانات اصطناعية · بانتظار الموافقة',
                textAlign: TextAlign.center)),
        Expanded(
            child: SingleChildScrollView(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (page == 0) ...[
                                    heading('لحظات تستحق الحجز',
                                        'اكتشف الشاليهات والمزارع والقاعات في الأنبار'),
                                    TextField(
                                        decoration: const InputDecoration(
                                            hintText: 'أين تريد قضاء يومك؟',
                                            prefixIcon: Icon(Icons.search))),
                                    const SizedBox(height: 12),
                                    Wrap(spacing: 8, children: [
                                      for (final type in [
                                        'الكل',
                                        'شاليهات',
                                        'مزارع',
                                        'قاعات'
                                      ])
                                        ChoiceChip(
                                            label: Text(type),
                                            selected: type == 'الكل',
                                            onSelected: (_) {})
                                    ]),
                                    const SizedBox(height: 12),
                                    BookingVenueCard(
                                        venue: previewVenue,
                                        onTap: () => setState(() => page = 1)),
                                  ],
                                  if (page == 1) ...[
                                    heading('مساحة ليوم مختلف',
                                        'صور المكان في هذه المعاينة غير متاحة؛ لا تُعرض صور مولّدة.'),
                                    const BookingVenueOverview(
                                        venue: previewVenue, total: 250000),
                                    const Wrap(spacing: 8, children: [
                                      Chip(label: Text('مسبح')),
                                      Chip(label: Text('٣ غرف')),
                                      Chip(label: Text('١٢ ضيفًا')),
                                      Chip(label: Text('موقف سيارات'))
                                    ]),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                        onPressed: () =>
                                            setState(() => page = 2),
                                        child: const Text('اختيار الموعد')),
                                  ],
                                  if (page == 2) ...[
                                    heading('اختر موعدك',
                                        'نوفمبر ٢٠٢٦ · جميع الأوقات بتوقيت بغداد'),
                                    Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: calendar())),
                                    const SizedBox(height: 16),
                                    Text(selected == null
                                        ? 'اختر يومًا متاحًا لعرضه هنا'
                                        : 'الموعد المختار: ${selected!.day} / 11 / 2026'),
                                    FilledButton(
                                        onPressed: selected == null
                                            ? null
                                            : () => setState(() => page = 3),
                                        child: const Text('متابعة الطلب')),
                                  ],
                                  if (page == 3) ...[
                                    heading('راجع طلبك',
                                        'الطلب ← موافقة المالك ← العربون ← التأكيد'),
                                    const BookingVenueOverview(
                                        venue: previewVenue, total: 250000),
                                    panel(
                                        'موعد الزيارة',
                                        '٢٢ نوفمبر · ٩ صباحًا',
                                        Icons.calendar_month),
                                    const SizedBox(height: 12),
                                    TextField(
                                        decoration: const InputDecoration(
                                            labelText: 'ملاحظات للمالك',
                                            hintText:
                                                'أضف ما يلزم قبل الزيارة'),
                                        maxLines: 2),
                                    const SizedBox(height: 16),
                                    const Text(
                                        'تأكيد السعر والشروط وسياسة الإلغاء مطلوب في التطبيق قبل إرسال الطلب.',
                                        style: TextStyle(height: 1.7)),
                                    FilledButton(
                                        onPressed: () =>
                                            setState(() => page = 4),
                                        child: const Text('معاينة خطوة الدفع')),
                                  ],
                                  if (page == 4) ...[
                                    heading('عربون الحجز',
                                        'تحويل يدوي تراجعه الإدارة قبل تأكيد الحجز'),
                                    panel('المبلغ المطلوب', '50,000 د.ع',
                                        Icons.account_balance_wallet_outlined),
                                    const SizedBox(height: 16),
                                    const Card(
                                        child: Padding(
                                            padding: EdgeInsets.all(20),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text('Ki / Qi  ·  Zain Cash',
                                                      style: TextStyle(
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  SizedBox(height: 12),
                                                  Text(
                                                      'تُعرض بيانات المستلم المعتمدة في جلسة التطبيق فقط. لا توجد حسابات دفع حقيقية في المعاينة.',
                                                      style: TextStyle(
                                                          height: 1.8)),
                                                ]))),
                                    const SizedBox(height: 16),
                                    const TextField(
                                        decoration: InputDecoration(
                                            labelText: 'مرجع التحويل التجريبي',
                                            prefixIcon:
                                                Icon(Icons.receipt_long))),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text(
                                            'إرفاق الإيصال · عرض فقط')),
                                    const BookingProgress(status: 'held'),
                                  ],
                                  if (page == 5) ...[
                                    heading('أهلًا، مالك المكان',
                                        'نظرة واضحة على حجوزاتك ومواعيدك القادمة'),
                                    panel('طلبات بانتظارك', '٣ طلبات تجريبية',
                                        Icons.inbox_outlined),
                                    panel('حجوزات مؤكدة', '٨ حجوزات تجريبية',
                                        Icons.event_available),
                                    const SizedBox(height: 16),
                                    const Text('أماكنك',
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700)),
                                    BookingVenueCard(
                                        venue: previewVenue,
                                        onTap: () => setState(() => page = 1)),
                                    OutlinedButton(
                                        onPressed: () =>
                                            setState(() => page = 2),
                                        child: const Text('عرض التقويم')),
                                  ],
                                  if (page == 6) ...[
                                    heading('مركز الإدارة والمالية',
                                        'قائمة المراجعة · أرقام اصطناعية للعرض فقط'),
                                    panel('إيصالات قيد المراجعة', '٤ إيصالات',
                                        Icons.receipt_long),
                                    panel('تسويات المالكين', '١٢٠٬٠٠٠ د.ع',
                                        Icons.account_balance_outlined),
                                    panel('استردادات قيد المراجعة',
                                        '٥٠٬٠٠٠ د.ع', Icons.undo),
                                    const SizedBox(height: 16),
                                    const Card(
                                        child: Column(children: [
                                      ListTile(
                                          leading: Icon(
                                              Icons.verified_user_outlined),
                                          title: Text('توثيق ملكية الأماكن'),
                                          subtitle: Text(
                                              'طلبان تجريبيان بانتظار المراجعة')),
                                      Divider(),
                                      ListTile(
                                          leading: Icon(
                                              Icons.photo_library_outlined),
                                          title: Text('مراجعة الصور والفيديو'),
                                          subtitle: Text('٣ ملفات تجريبية'))
                                    ])),
                                    const SizedBox(height: 16),
                                    const Text(
                                        'يتطلب دفتر المالية اتصالًا وتحققًا من صلاحية الحساب. لا تنفّذ المعاينة أي تسوية أو استرداد.',
                                        style: TextStyle(height: 1.8)),
                                  ],
                                ])))))),
        Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(spacing: 4, children: [
              for (var i = 0; i < previewTitles.length; i++)
                TextButton(
                    onPressed: () => setState(() => page = i),
                    child: Text(previewTitles[i]))
            ])),
      ]));
}
