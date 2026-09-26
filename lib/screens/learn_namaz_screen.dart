import 'package:flutter/material.dart';

class LearnNamazScreen extends StatelessWidget {
  const LearnNamazScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF002215),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Namaz Öğren',
          style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'serif'),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF003B25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37)),
              ),
              child: Column(
                children: [
                  const Text('Sabah Namazı', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('2 rekât Sünnet + 2 rekât Farz', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Divider(color: Color(0xFFD4AF37), height: 30),
                  _buildStepRow('1', 'Niyet', 'Sabah namazının sünnetini kılmaya niyet edilir.'),
                  _buildStepRow('2', 'Tekbir', '"Allahu Ekber" diyerek namaza başlanır.'),
                  _buildStepRow('3', 'Kıyam', 'Sübhâneke, Eûzü-Besmele ve Fâtiha okunur.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStepRow(String number, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37),
            radius: 14,
            child: Text(number, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 15)),
                Text(desc, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
