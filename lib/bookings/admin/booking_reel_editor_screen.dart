import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'booking_admin_theme.dart';
import 'booking_reel_media_service.dart';

enum _VideoSourceMode { studio, externalUrl }

/// شاشة إنشاء/تعديل ريل حجوزات — منفصلة تماماً عن ريلز العقارات.
/// تكتب فقط في مجموعة [booking_reels] وترفع الفيديو إلى
/// `booking_reels_media/{venueId}/{authorUid}/{fileName}` ولا تلمس [reels].
class BookingReelEditorScreen extends StatefulWidget {
  /// معرّف الريل لتعديله — null في حالة الإنشاء الجديد.
  final String? reelId;

  /// بيانات الريل الحالية (عند التعديل).
  final Map<String, dynamic>? existing;

  const BookingReelEditorScreen({super.key, this.reelId, this.existing});

  @override
  State<BookingReelEditorScreen> createState() =>
      _BookingReelEditorScreenState();
}

class _BookingReelEditorScreenState extends State<BookingReelEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _thumbnailCtrl;
  late final TextEditingController _venueNameCtrl;

  bool _active = true;
  bool _saving = false;
  String? _errorMsg;

  late _VideoSourceMode _sourceMode;
  String? _initialStoragePath;
  String? _initialVideoUrl;
  String? _initialFileName;
  int? _initialFileSize;

  File? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSize;
  Duration? _videoDuration;
  VideoPlayerController? _previewController;
  bool _previewReady = false;
  bool _previewError = false;

  bool _uploading = false;
  double _uploadProgress = 0;
  String? _uploadError;
  String? _uploadedVideoUrl;
  String? _uploadedStoragePath;
  UploadTask? _activeUploadTask;
  StreamSubscription<TaskSnapshot>? _uploadSub;
  bool _savedSuccessfully = false;

  bool get _isEdit => widget.reelId != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};
    _titleCtrl = TextEditingController(text: e['title']?.toString() ?? '');
    _descCtrl = TextEditingController(text: e['description']?.toString() ?? '');
    _initialVideoUrl = e['videoUrl']?.toString().trim();
    _initialStoragePath = e['videoStoragePath']?.toString().trim();
    _initialFileName = e['videoFileName']?.toString().trim();
    final rawSize = e['videoSizeBytes'];
    _initialFileSize = rawSize is num ? rawSize.toInt() : null;

    _videoUrlCtrl = TextEditingController(
      text: (_initialStoragePath == null || _initialStoragePath!.isEmpty)
          ? (_initialVideoUrl ?? '')
          : '',
    );
    _thumbnailCtrl =
        TextEditingController(text: e['thumbnailUrl']?.toString() ?? '');
    _venueNameCtrl =
        TextEditingController(text: e['venueName']?.toString() ?? '');
    _active = e['active'] != false;

    if (_initialStoragePath != null && _initialStoragePath!.isNotEmpty) {
      _sourceMode = _VideoSourceMode.studio;
      _uploadedVideoUrl = _initialVideoUrl;
      _uploadedStoragePath = _initialStoragePath;
      _selectedFileName = (_initialFileName?.isNotEmpty ?? false)
          ? _initialFileName
          : BookingReelMediaService.fileBaseName(_initialStoragePath!);
      _selectedFileSize = _initialFileSize;
      if (_initialVideoUrl != null && _initialVideoUrl!.isNotEmpty) {
        _initNetworkPreview(_initialVideoUrl!);
      }
    } else if (_isEdit &&
        _initialVideoUrl != null &&
        _initialVideoUrl!.isNotEmpty) {
      _sourceMode = _VideoSourceMode.externalUrl;
    } else {
      _sourceMode = _VideoSourceMode.studio;
    }
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    _activeUploadTask?.cancel();
    _previewController?.dispose();
    if (!_savedSuccessfully &&
        _uploadedStoragePath != null &&
        _uploadedStoragePath != _initialStoragePath) {
      BookingReelMediaService.deleteStorageObjectIfOwned(_uploadedStoragePath);
    }
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _videoUrlCtrl.dispose();
    _thumbnailCtrl.dispose();
    _venueNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initFilePreview(File file) async {
    await _disposePreview();
    final controller = VideoPlayerController.file(file);
    _previewController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _previewReady = true;
        _previewError = false;
        _videoDuration = controller.value.duration;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewReady = false;
        _previewError = true;
      });
    }
  }

  Future<void> _initNetworkPreview(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    await _disposePreview();
    final controller = VideoPlayerController.networkUrl(uri);
    _previewController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _previewReady = true;
        _previewError = false;
        _videoDuration = controller.value.duration;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewReady = false;
        _previewError = true;
      });
    }
  }

  Future<void> _disposePreview() async {
    final old = _previewController;
    _previewController = null;
    _previewReady = false;
    _previewError = false;
    _videoDuration = null;
    await old?.dispose();
  }

  Future<void> _pickVideoFromStudio() async {
    if (_uploading || _saving) return;
    XFile? picked;
    try {
      picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError = 'تعذر فتح استديو الفيديو: $e';
      });
      return;
    }

    // إلغاء المستخدم لاختيار الفيديو لا يُعد خطأً.
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final fileName = picked.name.isNotEmpty
        ? picked.name
        : BookingReelMediaService.fileBaseName(file.path);
    int sizeBytes = 0;
    try {
      sizeBytes = await file.length();
    } catch (_) {
      sizeBytes = 0;
    }

    final validation = BookingReelMediaService.validateVideoFile(
      fileName: fileName,
      sizeBytes: sizeBytes,
    );
    if (!validation.isValid) {
      setState(() {
        _uploadError = validation.errorMessage;
      });
      return;
    }

    // تنظيف أي ملف مرفوع حديثاً لم يُحفظ بعد قبل استبداله بملف جديد.
    final previousUnsavedPath = _uploadedStoragePath;
    await _cancelActiveUpload();
    if (previousUnsavedPath != null &&
        previousUnsavedPath != _initialStoragePath) {
      await BookingReelMediaService.deleteStorageObjectIfOwned(
          previousUnsavedPath);
    }

    setState(() {
      _sourceMode = _VideoSourceMode.studio;
      _selectedFile = file;
      _selectedFileName = fileName;
      _selectedFileSize = sizeBytes;
      _uploadedVideoUrl = null;
      _uploadedStoragePath = null;
      _uploadError = null;
      _errorMsg = null;
      _uploadProgress = 0;
    });

    await _initFilePreview(file);
    await _uploadSelectedFile(file);
  }

  Future<void> _uploadSelectedFile(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _uploading = false;
        _uploadError = 'يجب تسجيل الدخول بحساب إداري لرفع الفيديو إلى التخزين.';
      });
      return;
    }

    final venueId = widget.existing?['venueId']?.toString() ?? '';
    final storagePath = BookingReelMediaService.buildStoragePath(
      venueId: venueId,
      authorUid: user.uid,
    );

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _uploadError = null;
    });

    final task = BookingReelMediaService.startUploadTask(
      file: file,
      storagePath: storagePath,
    );
    _activeUploadTask = task;

    _uploadSub?.cancel();
    _uploadSub = task.snapshotEvents.listen(
      (snap) {
        if (!mounted) return;
        final total = snap.totalBytes;
        final progress =
            total > 0 ? (snap.bytesTransferred / total).clamp(0.0, 1.0) : 0.0;
        setState(() => _uploadProgress = progress);
      },
      onError: (_) {},
    );

    try {
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 1.0;
        _uploadedVideoUrl = url;
        _uploadedStoragePath = storagePath;
        _uploadError = null;
        _activeUploadTask = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'canceled') {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
          _activeUploadTask = null;
        });
        return;
      }
      setState(() {
        _uploading = false;
        _uploadError =
            'فشل رفع الفيديو (${e.code}): ${e.message ?? e.toString()}';
        _activeUploadTask = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError =
            'تعذر رفع الفيديو؛ تحقق من اتصال الإنترنت ثم أعد المحاولة.';
        _activeUploadTask = null;
      });
    }
  }

  Future<void> _cancelActiveUpload() async {
    await _uploadSub?.cancel();
    _uploadSub = null;
    final task = _activeUploadTask;
    _activeUploadTask = null;
    if (task != null) {
      try {
        await task.cancel();
      } catch (_) {}
    }
  }

  Future<void> _clearSelectedVideo() async {
    if (_saving) return;
    await _cancelActiveUpload();
    final unsavedPath = _uploadedStoragePath;
    if (unsavedPath != null && unsavedPath != _initialStoragePath) {
      await BookingReelMediaService.deleteStorageObjectIfOwned(unsavedPath);
    }
    await _disposePreview();
    if (!mounted) return;
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _uploadedVideoUrl = null;
      _uploadedStoragePath = null;
      _uploading = false;
      _uploadProgress = 0;
      _uploadError = null;
    });
  }

  Future<void> _save() async {
    if (_uploading || _saving) return;
    if (!_formKey.currentState!.validate()) return;

    late final String finalVideoUrl;
    late final String finalStoragePath;
    late final String finalSource;

    if (_sourceMode == _VideoSourceMode.studio) {
      if (_uploadedVideoUrl == null || _uploadedVideoUrl!.trim().isEmpty) {
        setState(() {
          _errorMsg =
              'يرجى اختيار فيديو من الاستديو وانتظار اكتمال رفعه قبل الحفظ.';
        });
        return;
      }
      finalVideoUrl = _uploadedVideoUrl!.trim();
      finalStoragePath = _uploadedStoragePath ?? '';
      finalSource = 'storage';
    } else {
      final urlErr =
          BookingReelMediaService.validateExternalVideoUrl(_videoUrlCtrl.text);
      if (urlErr != null) {
        setState(() => _errorMsg = urlErr);
        return;
      }
      finalVideoUrl = _videoUrlCtrl.text.trim();
      finalStoragePath = '';
      finalSource = 'external';
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final col = FirebaseFirestore.instance.collection('booking_reels');

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'videoUrl': finalVideoUrl,
        'videoSource': finalSource,
        'videoStoragePath': finalStoragePath,
        'videoFileName':
            finalSource == 'storage' ? (_selectedFileName ?? '') : '',
        'videoSizeBytes':
            finalSource == 'storage' ? (_selectedFileSize ?? 0) : 0,
        'thumbnailUrl': _thumbnailCtrl.text.trim(),
        'venueName': _venueNameCtrl.text.trim(),
        'active': _active,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        await col.doc(widget.reelId).update(payload);
      } else {
        payload.addAll({
          'ownerId': uid,
          'venueId': '',
          'category': '',
          'location': '',
          'price': 0,
          'deposit': 0,
          'likesCount': 0,
          'commentsCount': 0,
          'sharesCount': 0,
          'viewsCount': 0,
          'rawVenue': {},
          'createdAt': FieldValue.serverTimestamp(),
        });
        await col.add(payload);
      }

      // حذف الفيديو القديم فقط بعد نجاح الحفظ في Firestore.
      if (_initialStoragePath != null &&
          _initialStoragePath!.isNotEmpty &&
          _initialStoragePath != finalStoragePath) {
        await BookingReelMediaService.deleteStorageObjectIfOwned(
            _initialStoragePath);
      }

      _savedSuccessfully = true;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'حدث خطأ أثناء الحفظ: ${e.toString()}';
        _saving = false;
      });
    }
  }

  InputDecoration _inputDec(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
          color: BookingAdminTheme.textMute(context),
          fontFamily: 'Cairo',
          fontSize: 13),
      hintStyle: TextStyle(
          color: BookingAdminTheme.textMute(context).withValues(alpha: 0.6),
          fontFamily: 'Cairo',
          fontSize: 12),
      prefixIcon: icon != null
          ? Icon(icon, color: BookingAdminTheme.icon(context), size: 18)
          : null,
      filled: true,
      fillColor: BookingAdminTheme.surfaceSecondary(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: BookingAdminTheme.border(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: BookingAdminTheme.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BookingAdminTheme.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            dark ? BookingAdminTheme.bgPrimary : const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: dark ? BookingAdminTheme.surfaceCard : Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            _isEdit ? 'تعديل ريل الحجوزات' : 'إضافة ريل جديد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: BookingAdminTheme.text(context),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: BookingAdminTheme.icon(context), size: 20),
            onPressed: _saving ? null : () => Navigator.pop(context),
            tooltip: 'رجوع',
          ),
          actions: [
            if (!_saving)
              TextButton.icon(
                icon: const Icon(Icons.save_rounded,
                    color: BookingAdminTheme.gold, size: 18),
                label: const Text(
                  'حفظ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: BookingAdminTheme.gold,
                    fontSize: 14,
                  ),
                ),
                onPressed: _uploading ? null : _save,
              ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BookingAdminTheme.gold,
                  ),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x1FEF4444),
                    border: Border.all(color: const Color(0xFFEF4444)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── بطاقة البيانات الأساسية ──────────────────────────────
              _SectionCard(
                dark: dark,
                title: 'البيانات الأساسية',
                icon: Icons.info_outline_rounded,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontFamily: 'Cairo',
                        fontSize: 14),
                    decoration: _inputDec('عنوان الريل *',
                        hint: 'مثال: جولة في شاليه الرافدين',
                        icon: Icons.title_rounded),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'العنوان مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descCtrl,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontFamily: 'Cairo',
                        fontSize: 13),
                    decoration: _inputDec('الوصف (اختياري)',
                        hint: 'وصف مختصر للفيديو…',
                        icon: Icons.description_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _venueNameCtrl,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontFamily: 'Cairo',
                        fontSize: 13),
                    decoration: _inputDec('اسم المكان (اختياري)',
                        hint: 'مثال: شاليه الحبانية',
                        icon: Icons.place_outlined),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ─── بطاقة الفيديو والوسائط ───────────────────────────────
              _SectionCard(
                dark: dark,
                title: 'مصدر الفيديو والوسائط',
                icon: Icons.video_library_outlined,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: Icon(
                          Icons.video_library_rounded,
                          size: 16,
                          color: _sourceMode == _VideoSourceMode.studio
                              ? BookingAdminTheme.gold
                              : BookingAdminTheme.icon(context),
                        ),
                        label: const Text(
                          'رفع من الاستديو',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                        selected: _sourceMode == _VideoSourceMode.studio,
                        selectedColor:
                            BookingAdminTheme.gold.withValues(alpha: 0.18),
                        onSelected: _uploading || _saving
                            ? null
                            : (_) => setState(
                                () => _sourceMode = _VideoSourceMode.studio),
                      ),
                      ChoiceChip(
                        avatar: Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: _sourceMode == _VideoSourceMode.externalUrl
                              ? BookingAdminTheme.gold
                              : BookingAdminTheme.icon(context),
                        ),
                        label: const Text(
                          'رابط فيديو خارجي',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                        selected: _sourceMode == _VideoSourceMode.externalUrl,
                        selectedColor:
                            BookingAdminTheme.gold.withValues(alpha: 0.18),
                        onSelected: _uploading || _saving
                            ? null
                            : (_) => setState(() =>
                                _sourceMode = _VideoSourceMode.externalUrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_sourceMode == _VideoSourceMode.studio) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BookingAdminTheme.gold,
                          side: const BorderSide(color: BookingAdminTheme.gold),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.video_library_rounded, size: 20),
                        label: Text(
                          _selectedFileName == null
                              ? 'اختيار فيديو من الاستديو'
                              : 'اختيار فيديو آخر من الاستديو',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: (_uploading || _saving)
                            ? null
                            : _pickVideoFromStudio,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _HintText(
                      'الصيغة المدعومة: MP4 بحد أقصى 50 ميجابايت. يُرفع الفيديو مباشرةً إلى مساحة ريلز الحجوزات المعزولة.',
                    ),
                    if (_uploadError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x1FEF4444),
                          border: Border.all(color: const Color(0xFFEF4444)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _uploadError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontFamily: 'Cairo',
                                fontSize: 12,
                              ),
                            ),
                            if (_selectedFile != null && !_uploading) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 16),
                                  label: const Text('إعادة محاولة الرفع',
                                      style: TextStyle(
                                          fontFamily: 'Cairo', fontSize: 12)),
                                  onPressed: () =>
                                      _uploadSelectedFile(_selectedFile!),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_selectedFileName != null || _uploading) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BookingAdminTheme.surfaceSecondary(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: BookingAdminTheme.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_previewController != null &&
                                _previewReady) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 220),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AspectRatio(
                                        aspectRatio: _previewController!
                                            .value.aspectRatio,
                                        child: VideoPlayer(_previewController!),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _previewController!.value.isPlaying
                                                ? _previewController!.pause()
                                                : _previewController!.play();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _previewController!.value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ] else if (_previewError) ...[
                              Text(
                                'تعذرت معاينة الفيديو محلياً، لكن يمكنك متابعة الرفع إذا كان الملف صالحاً.',
                                style: TextStyle(
                                  color: BookingAdminTheme.textMute(context),
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_selectedFileName != null)
                              Text(
                                'الملف: $_selectedFileName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if (_selectedFileSize != null)
                                  Text(
                                    'الحجم: ${BookingReelMediaService.formatBytes(_selectedFileSize!)}',
                                    style: TextStyle(
                                      color:
                                          BookingAdminTheme.textMute(context),
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                    ),
                                  ),
                                if (_videoDuration != null)
                                  Text(
                                    'المدة: ${BookingReelMediaService.formatDuration(_videoDuration)}',
                                    style: TextStyle(
                                      color:
                                          BookingAdminTheme.textMute(context),
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            if (_uploading) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: _uploadProgress > 0
                                    ? _uploadProgress
                                    : null,
                                color: BookingAdminTheme.gold,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'جارٍ رفع الفيديو… ${(_uploadProgress * 100).toStringAsFixed(0)}٪',
                                style: const TextStyle(
                                  color: BookingAdminTheme.gold,
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else if (_uploadedVideoUrl != null) ...[
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF4ADE80), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'الفيديو جاهز للحفظ',
                                    style: TextStyle(
                                      color: Color(0xFF4ADE80),
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.close_rounded,
                                    color: Color(0xFFEF4444), size: 16),
                                label: const Text(
                                  'إلغاء الفيديو المختار',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: _saving ? null : _clearSelectedVideo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    TextFormField(
                      controller: _videoUrlCtrl,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: BookingAdminTheme.text(context),
                          fontFamily: 'Cairo',
                          fontSize: 12),
                      decoration: _inputDec('رابط الفيديو الخارجي *',
                          hint: 'https://…',
                          icon: Icons.play_circle_outline_rounded),
                      validator: (v) {
                        if (_sourceMode != _VideoSourceMode.externalUrl) {
                          return null;
                        }
                        return BookingReelMediaService.validateExternalVideoUrl(
                            v);
                      },
                    ),
                    const SizedBox(height: 8),
                    const _HintText(
                      'أدخل رابط فيديو مباشر يبدأ بـ https:// (غير محلي).',
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _thumbnailCtrl,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontFamily: 'Cairo',
                        fontSize: 12),
                    decoration: _inputDec('رابط الصورة المصغرة (اختياري)',
                        hint: 'https://…', icon: Icons.image_outlined),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ─── بطاقة الحالة ─────────────────────────────────────────
              _SectionCard(
                dark: dark,
                title: 'حالة النشر',
                icon: Icons.toggle_on_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نشر الريل فوراً',
                              style: TextStyle(
                                color: BookingAdminTheme.text(context),
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _active
                                  ? 'الريل سيظهر للجمهور بعد الحفظ مباشرةً.'
                                  : 'الريل مخفي ولن يظهر للمستخدمين.',
                              style: TextStyle(
                                color: BookingAdminTheme.textMute(context),
                                fontFamily: 'Cairo',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                        activeThumbColor: BookingAdminTheme.gold,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ─── زر الحفظ الرئيسي ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BookingAdminTheme.gold,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        )
                      : Icon(
                          _isEdit
                              ? Icons.save_rounded
                              : Icons.add_circle_outline_rounded,
                          size: 20),
                  label: Text(
                    _uploading
                        ? 'انتظر اكتمال رفع الفيديو…'
                        : _saving
                            ? 'جارٍ الحفظ…'
                            : (_isEdit ? 'حفظ التعديلات' : 'نشر الريل الجديد'),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: (_saving || _uploading) ? null : _save,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool dark;
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.dark,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? BookingAdminTheme.surfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BookingAdminTheme.border(context)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: BookingAdminTheme.gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: BookingAdminTheme.text(context),
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: BookingAdminTheme.border(context)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  final String text;
  const _HintText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: BookingAdminTheme.textMute(context).withValues(alpha: 0.7),
          fontFamily: 'Cairo',
          fontSize: 11,
        ),
      ),
    );
  }
}
