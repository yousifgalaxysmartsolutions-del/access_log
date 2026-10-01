import 'package:flutter/material.dart';

/// Sweeping highlight shared by every placeholder block.
///
/// Extracted from the dashboard skeleton so screens that show a loading
/// placeholder reuse one implementation and one visual language.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        final sweep = _controller.value * 2 - 1;
        return LinearGradient(
          begin: Alignment(-1 + sweep, -1 + sweep),
          end: Alignment(1 + sweep, 1 + sweep),
          colors: const [
            Color(0xFFECECEC),
            Color(0xFFF8F8F8),
            Color(0xFFECECEC),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(bounds);
      },
      child: child,
    ),
    child: widget.child,
  );
}

/// A single shimmering placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
