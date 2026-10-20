import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  final FilterQuality filterQuality;
  final BaseCacheManager? publicCacheManager;
  final Animation<double>? opacity;
  const MediaImage(this.url,
      {super.key,
      this.store,
      this.width,
      this.height,
      this.fit,
      this.errorBuilder,
      this.loadingBuilder,
      this.filterQuality = FilterQuality.medium,
      this.publicCacheManager,
      this.opacity});
  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> with WidgetsBindingObserver {
  Timer? _retry;
  int _attempt = 0;
  int _epoch = 0;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _epoch++;
        _load();
      });
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleRetry(Object error) {
    final status = error is HttpExceptionWithStatus
        ? error.statusCode
        : error is NetworkImageLoadException
            ? error.statusCode
            : null;
    if (status != null && status != 408 && status != 429 && status < 500) {
      return;
    }
    if (status == null &&
        error is! SocketException &&
        error is! TimeoutException) {
      return;
    }
    if (_retry?.isActive ?? false) {
      return;
    }
    const seconds = [5, 10, 20, 40, 60];
    _retry = Timer(Duration(seconds: seconds[_attempt < 4 ? _attempt : 4]), () {
      if (mounted) {
        setState(() {
          _attempt++;
        });
      }
    });
  }

  MediaStore get _store => widget.store ?? MediaStore.instance;
  String get _bucket => widget.store?.bucket ?? MediaLocation.defaultBucket;
  Future<Uint8List>? _bytes;
  String? _loadedUid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      return CachedNetworkImage(
          key: ValueKey('${widget.url}:$_attempt:$_epoch'),
          imageUrl: widget.url,
          cacheManager: widget.publicCacheManager,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          imageBuilder: widget.opacity == null
              ? null
              : (context, provider) => Image(
                  image: provider,
                  opacity: widget.opacity,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  filterQuality: widget.filterQuality),
          errorWidget: (context, url, error) {
            _scheduleRetry(error);
            return _error(error);
          },
          placeholder: (context, url) => SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Center(child: CircularProgressIndicator())));
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
              key: ValueKey('${auth.data!.uid}:${widget.url}:$_epoch'),
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
