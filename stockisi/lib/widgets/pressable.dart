import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Membungkus konten yang bisa ditekan dengan umpan balik ala iOS:
/// elemen mengecil sedikit **saat jari menyentuh**, bukan saat dilepas.
///
/// Tetap memakai [InkWell] supaya semantik, fokus keyboard, dan area sentuh
/// minimum tetap diurus Flutter; hanya riak Material yang dimatikan karena
/// tema sudah memasang `NoSplash.splashFactory`.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed && widget.onTap != null ? AppMotion.pressedScale : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: AppMotion.of(context, AppMotion.press),
      curve: AppMotion.curveOf(context, AppMotion.enter),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
