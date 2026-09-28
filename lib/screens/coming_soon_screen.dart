import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/page_shell.dart';
import '../widgets/gold_icon.dart';

/// Henüz hazırlanmamış bölümler için geçici sayfa.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String? image;

  const ComingSoonScreen({super.key, required this.title, this.image});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: title,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (image != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Image.asset(image!),
                ),
              const SizedBox(height: 24),
              const GoldIcon(Icons.hourglass_top, size: 36),
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
      ],
    );
  }
}
