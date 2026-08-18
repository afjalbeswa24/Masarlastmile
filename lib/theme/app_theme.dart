import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF1C4373);
  static const purple = Color(0xFF2B7FC4);
  static const purpleLight = Color(0xFFE3EEF9);
  static const background = Color(0xFFF7F8FA);
  static const border = Color(0xFFE3E6EA);
  static const rowDivider = Color(0xFFCDD3DA);
  static const textPrimary = Color(0xFF1E2A3A);
  static const textSecondary = Color(0xFF6B7684);

  static const statusPending = Color(0xFFF3E275);
  static const statusPickedUp = Color(0xFF2F80ED);
  static const statusSorted = Color(0xFF9B51E0);
  static const statusAssigned = Color(0xFFF2994A);
  static const statusOutForDelivery = Color(0xFF2563EB);
  static const statusDelivered = Color(0xFF16A34A);
  static const statusFailed = Color(0xFFEB5757);
  static const statusCancelled = Color(0xFF4F4F4F);
  static const statusRescheduled = Color(0xFF2D9CDB);
  static const statusReturnedToShipper = Color(0xFF8D6E63);
}

Color statusColor(String status) {
  switch (status) {
    case 'pending': return AppColors.statusPending;
    case 'picked_up': return AppColors.statusPickedUp;
    case 'sorted': return AppColors.statusSorted;
    case 'assigned': return AppColors.statusAssigned;
    case 'out_for_delivery': return AppColors.statusOutForDelivery;
    case 'delivered': return AppColors.statusDelivered;
    case 'failed': return AppColors.statusFailed;
    case 'cancelled': return AppColors.statusCancelled;
    case 'rescheduled': return AppColors.statusRescheduled;
    case 'returned_to_shipper': return AppColors.statusReturnedToShipper;
    default: return AppColors.statusPending;
  }
}


String statusLabel(String status) {
  switch (status) {
    case 'pending': return 'Pending';
    case 'picked_up': return 'Picked Up';
    case 'sorted': return 'Sorted';
    case 'assigned': return 'Assigned';
    case 'out_for_delivery': return 'Out for Delivery';
    case 'delivered': return 'Delivered';
    case 'failed': return 'Failed';
    case 'cancelled': return 'Cancelled';
    case 'rescheduled': return 'Rescheduled';
    case 'returned_to_shipper': return 'Returned to Shipper';
    default: return status;
  }
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      primary: AppColors.purple,
    ),
    fontFamily: 'Roboto',
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}