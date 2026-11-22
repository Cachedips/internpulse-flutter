import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class StipendBadge extends StatelessWidget {
  final String type; // paid | unpaid | allowance | unknown
  const StipendBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (type) {
      case 'paid':
        label = 'Paid';
        color = AppColors.success;
        break;
      case 'allowance':
        label = 'Allowance';
        color = AppColors.accentDark;
        break;
      case 'unpaid':
        label = 'Unpaid';
        color = AppColors.warning;
        break;
      default:
        label = 'Stipend ?';
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
