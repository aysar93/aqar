import 'package:flutter/material.dart';

import '../models/map_property.dart';
import 'map_property_card.dart';

class MapResultsSheet extends StatelessWidget {
  final List<MapProperty> properties;
  final ValueChanged<MapProperty> onPropertyTap;

  const MapResultsSheet({
    super.key,
    required this.properties,
    required this.onPropertyTap,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _background = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: properties.isEmpty ? null : () => _showResults(context),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 58,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.07,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.18,
                ),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: _gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  properties.isEmpty
                      ? 'لا توجد عقارات في المنطقة الظاهرة'
                      : '${properties.length} عقار في المنطقة الظاهرة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (properties.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Text(
                  'عرض',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: _gold,
                  size: 21,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showResults(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.18,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${properties.length} عقار في المنطقة الظاهرة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24,
                    ),
                    itemCount: properties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final property = properties[index];

                      return MapPropertyCard(
                        property: property,
                        onTap: () {
                          Navigator.of(sheetContext).pop();

                          onPropertyTap(property);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
