import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

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
    this.height = 48,
    this.borderRadius = 12,
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
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    HapticFeedback.selectionClick();
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
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final isEnabled = widget.onPressed != null;
    final baseBg = widget.isSecondary
        ? AppColors.surfaceElevated
        : (widget.color ?? AppColors.primary);
    final effectiveBg = isEnabled ? baseBg : AppColors.surfaceVariant;

    final defaultText = widget.isSecondary
        ? AppColors.textPrimary
        : (widget.color != null ? Colors.white : AppColors.onPrimary);
    final effectiveTextColor = widget.textColor ?? (isEnabled ? defaultText : AppColors.textDisabled);

    Widget child = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.gradient == null ? effectiveBg : null,
        gradient: widget.gradient != null
            ? LinearGradient(colors: widget.gradient!)
            : null,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.isSecondary ? AppColors.border : AppColors.borderLight.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: effectiveTextColor,
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text,
              style: TextStyle(
                color: effectiveTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );

    if (disableMotion || !isEnabled) {
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
