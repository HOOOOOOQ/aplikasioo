import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 16, width: double.infinity, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 8),
            Container(height: 12, width: 200, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8))),
          ],
        ),
      ),
    );
  }
}
