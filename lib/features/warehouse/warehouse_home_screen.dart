import 'package:flutter/material.dart';

import '../../core/theme/ref_style.dart';
import 'items_screen.dart';
import 'parties_screen.dart';

/// إدارة المخزن — 4 كروت ملونة بتتوزع على الشاشة بدون سكرول.
class WarehouseHomeScreen extends StatelessWidget {
  const WarehouseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'إدارة المخزن',
      body: RefFitList(
        children: [
          _card(context, 'الاصناف', Icons.inventory_2_rounded, const ItemsScreen(),
              const [Color(0xFF0E8C97), Color(0xFF38D1C4)]),
          _card(context, 'العملاء', Icons.groups_rounded,
              const PartiesScreen.customers(),
              const [Color(0xFF1D6FE0), Color(0xFF5DB0FF)]),
          _card(context, 'الموردين', Icons.local_shipping_rounded,
              const PartiesScreen.suppliers(),
              const [Color(0xFFF76B1C), Color(0xFFFFA94D)]),
          _card(context, 'المخازن', Icons.warehouse_rounded,
              const PartiesScreen.warehouses(),
              const [Color(0xFF7C3AED), Color(0xFFB794F6)]),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, Widget page,
      List<Color> colors) {
    return RefMenuCard(
      title: title,
      icon: icon,
      colors: colors,
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}
