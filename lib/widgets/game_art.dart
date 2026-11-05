import 'package:flutter/material.dart';

/// Gambar untuk permainan dan karakter anak. Tiap emoji dipetakan ke berkas gambar di
/// asset/image/game/ (Microsoft Fluent Emoji, lisensi MIT), sehingga tampilannya sama di semua HP
/// dan di browser. Bila berkasnya tidak ada, emoji aslinya yang ditampilkan.
class GameArt extends StatelessWidget {
  final String emoji;
  final double size;

  const GameArt(this.emoji, {super.key, this.size = 48});

  /// Nama berkas diambil dari kode karakter pertama, misalnya singa menjadi 1f981.png.
  static String assetFor(String emoji) => 'asset/image/game/${emoji.runes.first.toRadixString(16)}.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetFor(emoji),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => FittedBox(child: Text(emoji)),
      ),
    );
  }
}

/// Beberapa gambar berjajar, untuk soal seperti "hitung semangkanya". [text] berisi emoji dipisah spasi.
class GameArtRow extends StatelessWidget {
  final String text;
  final double size;

  const GameArtRow(this.text, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [for (final item in text.split(' ').where((part) => part.isNotEmpty)) GameArt(item, size: size)],
    );
  }
}
