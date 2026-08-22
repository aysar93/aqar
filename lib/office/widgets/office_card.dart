import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/office_model.dart';
import '../models/office_statistics_model.dart';
import '../services/office_statistics_service.dart';

class OfficeCard extends StatelessWidget {
  final OfficeModel office;
  final VoidCallback? onTap;

  const OfficeCard({
    super.key,
    required this.office,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const background = Color(0xFF1E293B);

    return StreamBuilder<OfficeStatisticsModel>(
      stream: OfficeStatisticsService().watchStatistics(office.id),
      builder: (context, snapshot) {
        final statistics = snapshot.data;

        final propertiesCount =
            statistics?.totalProperties ?? office.propertiesCount;

        final followersCount =
            statistics?.followersCount ?? office.followersCount;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gold.withValues(alpha: 0.16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(context, gold),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: _buildInfo(
                      context,
                      gold,
                      propertiesCount,
                      followersCount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover(BuildContext context, Color gold) {
    final imageUrl =
        office.coverImageUrl.isNotEmpty ? office.coverImageUrl : office.logoUrl;

    return SizedBox(
      height: 155,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _imagePlaceholder(gold),
              errorWidget: (_, __, ___) => _imagePlaceholder(gold),
            )
          else
            _imagePlaceholder(gold),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          if (office.isVerified)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: Colors.black,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'موثق',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (office.isFeatured)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFD4AF37),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'مميز',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            right: 14,
            bottom: 12,
            left: 14,
            child: Text(
              office.name.isNotEmpty ? office.name : 'مكتب عقاري',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(
    BuildContext context,
    Color gold,
    int propertiesCount,
    int followersCount,
  ) {
    final location = [
      office.city,
      office.district,
      office.areaName,
    ].where((e) => e.trim().isNotEmpty).join(' - ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (location.isNotEmpty)
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: gold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatItem(
              icon: Icons.home_work_outlined,
              value: '$propertiesCount',
              label: 'عقار',
              color: gold,
            ),
            const SizedBox(width: 18),
            _StatItem(
              icon: Icons.people_outline_rounded,
              value: '$followersCount',
              label: 'متابع',
              color: gold,
            ),
            const SizedBox(width: 18),
            _StatItem(
              icon: Icons.star_outline_rounded,
              value: office.rating.toStringAsFixed(1),
              label: 'تقييم',
              color: gold,
            ),
            const Spacer(),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: gold.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: gold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _imagePlaceholder(Color gold) {
    return Container(
      color: const Color(0xFF263548),
      alignment: Alignment.center,
      child: Icon(
        Icons.business_rounded,
        size: 54,
        color: gold.withValues(alpha: 0.65),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
