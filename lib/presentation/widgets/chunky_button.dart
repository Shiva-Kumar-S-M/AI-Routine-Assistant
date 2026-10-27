import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChunkyButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final List<Color>? gradient;
  final double height;
  final double borderRadius;
  final bool isSecondary;

  const ChunkyButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color,
    this.textColor,
    this.gradient,
    this.height = 54,
    this.borderRadius = 20,
    this.isSecondary = false,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed == null) return;
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget child = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.gradient == null
            ? (widget.color ??
                (widget.isSecondary
                    ? const Color(0xFF232338)
                    : theme.colorScheme.primary))
            : null,
        gradient: widget.gradient != null
            ? LinearGradient(colors: widget.gradient!)
            : null,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.isSecondary
            ? Border.all(color: const Color(0xFF383854), width: 1.5)
            : null,
        boxShadow: widget.isSecondary || widget.onPressed == null
            ? null
            : [
                BoxShadow(
                  color: (widget.color ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: widget.textColor ?? Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text,
              style: TextStyle(
                color: widget.textColor ?? Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );

    if (disableMotion) {
      return GestureDetector(
        onTap: widget.onPressed,
        child: child,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: child,
      ),
    );
  }
}
