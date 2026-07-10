import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'shimmer_widget.dart';

class ShimmerLoading {
  // Profile Shimmer
  static Widget profileShimmer() {
    return Column(
      children: [
        SizedBox(height: 20.h),
        // Avatar shimmer
        ShimmerWidget(
          width: 110.r,
          height: 110.r,
          borderRadius: BorderRadius.circular(55.r),
        ),
        SizedBox(height: 20.h),
        // Name shimmer
        ShimmerWidget(
          width: 150.w,
          height: 20.h,
          borderRadius: BorderRadius.circular(10.r),
        ),
        SizedBox(height: 8.h),
        // Subtitle shimmer
        ShimmerWidget(
          width: 100.w,
          height: 14.h,
          borderRadius: BorderRadius.circular(7.r),
        ),
        SizedBox(height: 30.h),
        // Plan card shimmer
        ShimmerWidget(
          width: double.infinity,
          height: 200.h,
          borderRadius: BorderRadius.circular(20.r),
        ),
        SizedBox(height: 20.h),
        // Button shimmer
        ShimmerWidget(
          width: double.infinity,
          height: 50.h,
          borderRadius: BorderRadius.circular(16.r),
        ),
      ],
    );
  }

  // Plan Card Shimmer
  static Widget planCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: ShimmerWidget(
        width: double.infinity,
        height: 180.h,
        borderRadius: BorderRadius.circular(20.r),
      ),
    );
  }

  // Grid Shimmer for Exams
  static Widget examGridShimmer({int itemCount = 6}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ShimmerWidget(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.circular(20.r),
        );
      },
    );
  }

  // List Item Shimmer
  static Widget listItemShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          ShimmerWidget(
            width: 50.w,
            height: 50.w,
            borderRadius: BorderRadius.circular(10.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerWidget(
                  width: double.infinity,
                  height: 16.h,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                SizedBox(height: 8.h),
                ShimmerWidget(
                  width: 100.w,
                  height: 12.h,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Text Line Shimmer
  static Widget textLineShimmer({double? width, double? height}) {
    return ShimmerWidget(
      width: width ?? 100.w,
      height: height ?? 14.h,
      borderRadius: BorderRadius.circular((height ?? 14.h) / 2),
    );
  }

  // Circle Shimmer
  static Widget circleShimmer({required double size}) {
    return ShimmerWidget(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  // Standard Card Shimmer
  static Widget standardCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              circleShimmer(size: 40.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textLineShimmer(width: 150.w, height: 16.h),
                    SizedBox(height: 6.h),
                    textLineShimmer(width: 100.w, height: 12.h),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
