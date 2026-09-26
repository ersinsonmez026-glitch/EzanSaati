import 'package:flutter/material.dart';

class SurahsScreen extends StatelessWidget {
  const SurahsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF002215),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Sureler',
          style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'serif'),
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF002B1B),
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  _buildSurahItem('1', 'Fâtiha', '7 ayet', true),
                  _buildSurahItem('2', 'Bakara', '286 ayet', false),
                  _buildSurahItem('3', 'Âl-i İmrân', '200 ayet', false),
                  _buildSurahItem('4', 'Nisâ', '176 ayet', false),
                  _buildSurahItem('5', 'Mâide', '120 ayet', false),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDD0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('سُورَةُ الْفَاتِحَةِ', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('FÂTİHA SURESİ', style: TextStyle(color: Color(0xFF8B5A2B), fontWeight: FontWeight.bold)),
                    const Divider(color: Color(0xFFD4AF37), height: 20),
                    const Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Rahmân ve Rahîm olan Allah\'ın adıyla.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSurahItem(String number, String title, String ayahs, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF003B25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isActive ? Colors.black : const Color(0xFFD4AF37),
            radius: 12,
            child: Text(number, style: TextStyle(color: isActive ? Colors.white : Colors.black, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isActive ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(ayahs, style: TextStyle(color: isActive ? Colors.black87 : Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
