import 'package:flutter/material.dart';

import '../../core/widgets/support_hub_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF0B0C0E) : const Color(0xFFF7FAF9),
      body: const Center(
        child: WaslLogoMark(size: 148, circular: true),
      ),
    );
  }
}
