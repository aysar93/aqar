import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PropertyImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PropertyImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.borderRadius,
  });

  bool get _isAsset => imagePath.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final Widget image;

    if (_isAsset) {
      image = _buildAssetImage();
    } else {
      image = _buildNetworkImage();
    }

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }

  Widget _buildAssetImage() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xff0F172A),
      alignment: Alignment.center,
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorWidget(),
      ),
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imagePath,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: const Color.fromARGB(255, 168, 180, 202),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Color(0xffD4AF37),
        ),
      ),
      errorWidget: (_, __, ___) => _errorWidget(),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xff1E293B),
      alignment: Alignment.center,
      child: const Icon(
        Icons.home_work_rounded,
        color: Color(0xffD4AF37),
        size: 70,
      ),
    );
  }
}
