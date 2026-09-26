import 'package:flutter/material.dart';

import '../theme.dart';

/// Henüz hazırlanmamış bölümler için geçici sayfa.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String image;

  const ComingSoonScreen({super.key, required this.title, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      appBar: goldAppBar(title),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Image.asset(image),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.hourglass_top, color: AppColors.gold, size: 36),
              const SizedBox(height: 12),
              Text(
                '$title bölümü hazırlanıyor',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu bölüm bir sonraki güncellemede eklenecek inşallah.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
