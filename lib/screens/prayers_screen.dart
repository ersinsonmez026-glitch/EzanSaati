import 'package:flutter/material.dart';

class PrayersScreen extends StatelessWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF002215),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dualar',
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
                  _buildPrayerListItem('1', 'Günün Duası', 'Rızık & Bereket', true),
                  _buildPrayerListItem('2', 'Namaz Duası', 'Sübhâneke', false),
                  _buildPrayerListItem('3', 'Yemek Duası', 'Şükür Duası', false),
                  _buildPrayerListItem('4', 'Uyku Duası', 'Gece Duası', false),
                  _buildPrayerListItem('5', 'Şifa Duası', 'Sağlık & Afiyet', false),
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
                    const Text(
                      'GÜNÜN DUASI',
                      style: TextStyle(color: Color(0xFF8B5A2B), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('Rızık ve Bereket Duası', style: TextStyle(color: Colors.black54, fontSize: 11)),
                    const Divider(color: Color(0xFFD4AF37), height: 20),
                    const Text(
                      'اللَّهُمَّ ارْزُقْنَا حَلَالًا طَيِّبًا وَوَسِّعْ لَنَا فِي رِزْقِنَا',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Allahümme erzuknâ helâlen tayyibâ ve siğ lenâ fî rızkınâ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black87, fontStyle: FontStyle.italic, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '"Allah\'ım, bize helal ve temiz rızık nasip et, rızkımızı genişlet."',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPrayerListItem(String number, String title, String category, bool isActive) {
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
            radius: 10,
            child: Text(number, style: TextStyle(color: isActive ? Colors.white : Colors.black, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isActive ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                Text(category, style: TextStyle(color: isActive ? Colors.black87 : Colors.white54, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
