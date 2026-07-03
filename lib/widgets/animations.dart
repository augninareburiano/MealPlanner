import 'package:flutter/material.dart';

/// Plays a one-shot fade + slide-up as the child appears. Use an increasing
/// [delay] on siblings for a staggered entrance.
///
/// The delay is built into a single [AnimationController] via an [Interval]
/// (rather than a `Future.delayed` timer), so it never leaves a pending timer —
/// which keeps widget tests clean.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);

    final startFraction = total.inMilliseconds == 0
        ? 0.0
        : widget.delay.inMilliseconds / total.inMilliseconds;
    _anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(startFraction, 1, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _anim.value) * widget.offsetY),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A number that animates (counts up/down) whenever [value] changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
