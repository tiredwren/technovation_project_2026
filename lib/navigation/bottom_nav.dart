import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    super.key,
    this.onTabChange,
    required this.labels,
    required this.numberOfTabs,
    required this.icons,
    required this.selectedIndex,
  });

  final void Function(int)? onTabChange;
  final List<String> labels;
  final int numberOfTabs;
  final List<IconData> icons;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF283618),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: GNav(
          selectedIndex: selectedIndex,
          backgroundColor: const Color(0xFF283618),
          activeColor: const Color(0xFFfefae0),
          color: const Color(0xFFfefae0),
          tabBackgroundColor: const Color(0xFF606c38),
          gap: 5,
          padding: const EdgeInsets.all(16),
          onTabChange: (value) {
            if (onTabChange != null) {
              print("tab index changed: $value");
              onTabChange!(value);
            }
          },
          tabs: List.generate(
            numberOfTabs,
                (index) => GButton(
              icon: icons[index],
              text: labels[index],
            ),
          ),
        ),
      ),
    );
  }
}
