import 'package:flutter/material.dart';
import '../../core/design/aqar_sizes.dart';
import '../../core/design/aqar_spacing.dart';
import '../../core/design/aqar_radius.dart';
import '../../core/design/aqar_text.dart';

class SearchSection extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onFilterTap;

  const SearchSection({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    required this.onFilterTap,
  });

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  static const Color _gold = Color(0xffD4AF37);

  VoidCallback? _controllerListener;

  @override
  void initState() {
    super.initState();

    _controllerListener = () {
      if (mounted) {
        setState(() {});
      }
    };

    widget.controller.addListener(_controllerListener!);
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      widget.controller.removeListener(_controllerListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AqarSizes.buttonHeight(context),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff263548),
            Color(0xff1E293B),
          ],
        ),
        borderRadius: AqarRadius.dialog(context),
        border: Border.all(
          color: _gold.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: AqarSpacing.xs(context)),
          Container(
            margin: EdgeInsets.only(
              right: AqarSpacing.sm(context),
              left: AqarSpacing.xs(context),
            ),
            width: AqarSizes.searchCircle(context),
            height: AqarSizes.searchCircle(context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(
                color: _gold.withValues(alpha: 0.18),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onSubmitted?.call(widget.controller.text);
              },
              child: Icon(
                Icons.search_rounded,
                color: _gold,
                size: AqarSizes.searchIcon(context),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                FocusScope.of(context).unfocus();
                widget.onSubmitted?.call(value);
              },
              style: TextStyle(
                color: Colors.white,
                fontSize: AqarText.searchInput(context),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: AqarSpacing.md(context),
                ),
                hintText: "ابحث عن عقار، منطقة، رقم إعلان",
                hintStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: AqarText.searchHint(context),
                ),
                suffixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: widget.controller.text.isNotEmpty
                      ? IconButton(
                          key: const ValueKey('clear'),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () {
                            widget.controller.clear();
                            widget.onChanged('');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : const SizedBox(
                          key: ValueKey('empty'),
                          width: 1,
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AqarSpacing.xs(context),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onFilterTap,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: AqarSizes.filterButton(context),
                  height: AqarSizes.filterButton(context),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xffF8D86B),
                        Color(0xffD4AF37),
                      ],
                    ),
                    boxShadow: const [],
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: Colors.black,
                    size: AqarSizes.filterIcon(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
