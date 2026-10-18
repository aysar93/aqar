import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/media_store.dart';
import '../services/media_location.dart';

// Private images use authenticated SDK reads, never a persistent network-image cache.
// Legacy Cloudinary and public HTTPS links continue using the existing network path.
class MediaImage extends StatefulWidget {
  final String url;
  final MediaStore? store;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  const MediaImage(this.url,
      {super.key,
      this.store,
      this.width,
      this.height,
      this.fit,
      this.errorBuilder,
      this.loadingBuilder});
  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  MediaStore get _store => widget.store ?? MediaStore.instance;
  String get _bucket => widget.store?.bucket ?? MediaLocation.defaultBucket;
  Future<Uint8List>? _bytes;
  String? _loadedUid;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.store != widget.store) _load();
  }

  bool get _privateImage => MediaLocation.needsAuth(widget.url, _bucket);
  void _load() {
    _loadedUid = _privateImage ? _store.auth.currentUser?.uid : null;
    _bytes = _loadedUid == null ? null : _store.readPrivate(widget.url);
  }

  Widget _error(Object error) =>
      widget.errorBuilder?.call(context, error, null) ??
      const Icon(Icons.broken_image);
  @override
  Widget build(BuildContext context) {
    if (!_privateImage) {
      return Image.network(widget.url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
          loadingBuilder: widget.loadingBuilder);
    }
    return StreamBuilder(
        stream: _store.auth.authStateChanges(),
        initialData: _store.auth.currentUser,
        builder: (context, auth) {
          if (!auth.hasData) {
            _loadedUid = null;
            _bytes = null;
            return _error(StateError('Authentication required'));
          }
          if (_loadedUid != auth.data!.uid) {
            _loadedUid = auth.data!.uid;
            _bytes = _store.readPrivate(widget.url);
          }
          return FutureBuilder<Uint8List>(
              key: ValueKey('${auth.data!.uid}:${widget.url}'),
              future: _bytes,
              builder: (context, state) {
                if (state.hasError) return _error(state.error!);
                if (!state.hasData) {
                  return SizedBox(
                      width: widget.width,
                      height: widget.height,
                      child: const Center(child: CircularProgressIndicator()));
                }
                return Image.memory(state.data!,
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    errorBuilder: widget.errorBuilder);
              });
        });
  }
}
