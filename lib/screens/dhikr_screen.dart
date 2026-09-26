import 'package:flutter/material.dart';

import '../widgets/page_shell.dart';

class DhikrScreen extends StatefulWidget {
  const DhikrScreen({super.key});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  int _counter = 0;
  final int _target = 33;

  void _increment() {
    setState(() {
      _counter++;
    });
  }

  void _reset() {
    setState(() {
      _counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Zikir Sayacı',
      subtitle: 'Zikir, kalbin huzurudur...',
      children: [
        Column(
          children: [
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _increment,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF003B25),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Zikir Sayısı', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      '$_counter',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Hedef: $_target', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Dokun', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('Sıfırla', style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
