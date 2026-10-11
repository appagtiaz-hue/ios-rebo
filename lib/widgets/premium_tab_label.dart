import 'package:flutter/material.dart';
import '../constants/colors.dart';

class PremiumTabLabel extends StatefulWidget {
  final String label;
  final bool selected;

  const PremiumTabLabel({
    super.key,
    required this.label,
    this.selected = false,
  });

  @override
  State<PremiumTabLabel> createState() => _PremiumTabLabelState();
}

class _PremiumTabLabelState extends State<PremiumTabLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final glow = Curves.easeInOut.transform(_controller.value);
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Opacity(
                    opacity: glow,
                    child: Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFFC33670),
                      size: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.selected ? const Color(0xFF1C1C1C) : null,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(
                        color: AppColors.secondary.withValues(
                          alpha: glow * 0.45,
                        ),
                        blurRadius: glow * 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Opacity(
                    opacity: 1 - glow,
                    child: Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFF2778C9),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
