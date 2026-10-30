import 'package:flutter/material.dart';

import '../theme.dart';

class Avatar extends StatelessWidget {
  final String id;
  final String name;
  final double size;

  const Avatar(
      {super.key, required this.id, required this.name, this.size = 54});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarPalette[
        id.codeUnits.fold(0, (a, b) => a + b) % AppColors.avatarPalette.length];
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.15)!, color],
        ),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600)),
    );
  }
}
