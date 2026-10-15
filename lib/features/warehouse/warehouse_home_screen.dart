import 'package:flutter/material.dart';

import '../../core/theme/ref_style.dart';
import 'items_screen.dart';
import 'parties_screen.dart';

/// إدارة المخزن — 4 كروت بيضاء مثل الصورة.
class WarehouseHomeScreen extends StatelessWidget {
  const WarehouseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RefScaffold(
      title: 'إدارة المخزن',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          _card(context, 'الاصناف', Icons.inventory_2_rounded, const ItemsScreen()),
          _card(context, 'العملاء', Icons.groups_rounded, const PartiesScreen.customers()),
          _card(context, 'الموردين', Icons.local_shipping_rounded, const PartiesScreen.suppliers()),
          _card(context, 'المخازن', Icons.warehouse_rounded, const PartiesScreen.warehouses()),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 23, fontWeight: FontWeight.w800, color: RefColors.navy)),
              ),
              Icon(icon, size: 52, color: RefColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
