import 'package:flutter/material.dart';

class LoginWelcomeText extends StatefulWidget {
  const LoginWelcomeText({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;
  static const typingDuration = Duration(seconds: 3);
  static const holdDuration = Duration(seconds: 2);
  static const fadeDuration = Duration(milliseconds: 180);

  @override
  State<LoginWelcomeText> createState() => _LoginWelcomeTextState();
}

class _LoginWelcomeTextState extends State<LoginWelcomeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          LoginWelcomeText.typingDuration +
          LoginWelcomeText.holdDuration +
          LoginWelcomeText.fadeDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LoginWelcomeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && !_reduceMotion) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.text,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final letters = widget.text.characters;
          final elapsed =
              (_controller.value * _controller.duration!.inMilliseconds)
                  .round();
          final typing = LoginWelcomeText.typingDuration.inMilliseconds;
          final holding = LoginWelcomeText.holdDuration.inMilliseconds;
          final fading = LoginWelcomeText.fadeDuration.inMilliseconds;
          final fraction = _reduceMotion
              ? 1.0
              : elapsed < typing
              ? elapsed / typing
              : 1.0;
          final opacity = _reduceMotion || elapsed < typing + holding
              ? 1.0
              : (1 - (elapsed - typing - holding) / fading).clamp(0.0, 1.0);
          final count = (letters.length * fraction).ceil().clamp(
            0,
            letters.length,
          );
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Opacity(
                opacity: 0,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: widget.style,
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  key: const ValueKey('login-welcome-opacity'),
                  opacity: opacity,
                  child: Text(
                    letters.take(count).toString(),
                    key: const ValueKey('login-typed-welcome'),
                    textAlign: TextAlign.center,
                    style: widget.style,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
