import 'package:flutter/material.dart';

/// Logo teks Cashifly dari file PNG asset.
/// Gunakan [height] untuk mengatur ukuran.
class CashiflyLogo extends StatelessWidget {
  final double height;

  const CashiflyLogo({super.key, this.height = 52});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/logo.png',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
