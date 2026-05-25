import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    this.currentIndex = 0,
    super.key,
  });

  static const height = 74.0;
  static const activeColor = Color(0xFF090909);
  static const inactiveColor = Color(0xFFB8B8B8);

  final int currentIndex;

  static const _items = <_AppBottomNavItem>[
    _AppBottomNavItem(
      label: '홈',
      assetPath: 'assets/icons/icon_home_line.svg',
    ),
    _AppBottomNavItem(
      label: '프로젝트',
      assetPath: 'assets/icons/icon_project_line.svg',
    ),
    _AppBottomNavItem(
      label: '기록',
      assetPath: 'assets/icons/icon_record_line.svg',
    ),
    _AppBottomNavItem(
      label: '마이',
      assetPath: 'assets/icons/icon_my_line.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE8E8E8)),
          ),
        ),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final indexedItem in _items.indexed)
                Expanded(
                  child: _AppBottomNavButton(
                    item: indexedItem.$2,
                    isActive: indexedItem.$1 == currentIndex,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBottomNavButton extends StatelessWidget {
  const _AppBottomNavButton({
    required this.item,
    required this.isActive,
  });

  final _AppBottomNavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? AppBottomNav.activeColor : AppBottomNav.inactiveColor;

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: InkResponse(
        onTap: () {},
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                item.assetPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  height: 16 / 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBottomNavItem {
  const _AppBottomNavItem({
    required this.label,
    required this.assetPath,
  });

  final String label;
  final String assetPath;
}
