import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../services/network_service.dart';

class NetworkHelper {
  /// Check internet connection and show dialog if not connected
  /// Returns true if connected, false if not connected
  static Future<bool> checkConnection(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    final isConnected = await NetworkService.isConnected();

    if (!isConnected && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 28.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'لا يوجد اتصال بالإنترنت',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'يرجى الاتصال بالإنترنت لتحميل الأسئلة',
            style: TextStyle(fontSize: 15.sp),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text(
                'العودة',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            if (onRetry != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'إعادة المحاولة',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      );
    }

    return isConnected;
  }
}
