import 'package:flutter/material.dart';

class SholovvoLogo extends StatelessWidget {
  final double size;
  const SholovvoLogo({super.key, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: size * 0.15,
                  child: Container(
                    width: size * 0.55,
                    height: size * 0.32,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(size * 0.3),
                        right: Radius.circular(size * 0.3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: size * 0.15,
                  child: Container(
                    width: size * 0.55,
                    height: size * 0.32,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(size * 0.3),
                        right: Radius.circular(size * 0.3),
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.water_drop, color: Colors.white, size: 26),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            children: [
              TextSpan(text: 'S', style: TextStyle(color: Colors.green)),
              TextSpan(text: 'holovvo', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Save Lives • Connect Hearts',
          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500, letterSpacing: 0.8),
        ),
      ],
    );
  }
}
