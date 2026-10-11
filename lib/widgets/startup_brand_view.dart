import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class StartupBrandView extends StatefulWidget {
  const StartupBrandView({super.key, required this.languageCode});
  final String languageCode;

  static const messageDuration = Duration(seconds: 1);
  static const messageKeys = [
    'startupMessageGoal',
    'startupMessageUnderstand',
    'startupMessagePractice',
    'startupMessageReady',
  ];

  @override
  State<StartupBrandView> createState() => _StartupBrandViewState();
}

class _StartupBrandViewState extends State<StartupBrandView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typing;
  int _messageIndex = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _typing =
        AnimationController(
          vsync: this,
          duration: StartupBrandView.messageDuration,
        )..addListener(() {
          final elapsed = _typing.lastElapsedDuration?.inMicroseconds ?? 0;
          final next =
              (elapsed ~/ StartupBrandView.messageDuration.inMicroseconds) %
              StartupBrandView.messageKeys.length;
          if (mounted && next != _messageIndex) {
            setState(() => _messageIndex = next);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _typing.stop();
    } else if (!_typing.isAnimating) {
      _typing.repeat();
    }
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations(Locale(widget.languageCode));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sentence = text.translate(
      StartupBrandView.messageKeys[_messageIndex],
    );
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF111815) : const Color(0xFFF6F8F7),
      body: Directionality(
        textDirection: widget.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth > constraints.maxHeight;
              Widget panel(Widget child) =>
                  sideBySide ? Expanded(child: child) : child;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Flex(
                      direction: sideBySide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.asset(
                                      'assets/images/app_icon.png',
                                      width: 128,
                                      height: 128,
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    widget.languageCode == 'ar'
                                        ? 'اجتياز'
                                        : 'Agtiaz',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                      color: dark
                                          ? Colors.white
                                          : const Color(0xFF006C35),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    text.translate('startupTagline'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      letterSpacing: 0,
                                      color: dark
                                          ? const Color(0xFFB9CFC2)
                                          : const Color(0xFF53685D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        panel(
                          ColoredBox(
                            color: const Color(0xFF064D36),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Text(
                                    text.translate('startupEncouragement'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBDE0CC),
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height:
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(20) *
                                        1.5 *
                                        3,
                                    width: double.infinity,
                                    child: Center(
                                      child: Semantics(
                                        label: sentence,
                                        child: ExcludeSemantics(
                                          child: AnimatedBuilder(
                                            animation: _typing,
                                            builder: (context, _) {
                                              final letters =
                                                  sentence.characters;
                                              final count = _reduceMotion
                                                  ? letters.length
                                                  : (_typing.value *
                                                            letters.length)
                                                        .ceil();
                                              return Text(
                                                letters.take(count).toString(),
                                                key: const ValueKey(
                                                  'startup-typed-message',
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 3,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  height: 1.5,
                                                  letterSpacing: 0,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(
                                    height: 1,
                                    color: Colors.white.withValues(alpha: .15),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      for (final item in const [
                                        (
                                          'startupPractice',
                                          Icons.edit_outlined,
                                          Color(0xFFF1CA65),
                                        ),
                                        (
                                          'startupUnderstand',
                                          Icons.lightbulb_outline,
                                          Color(0xFF99E0BD),
                                        ),
                                        (
                                          'startupProgress',
                                          Icons.trending_up_rounded,
                                          Color(0xFF99CFF7),
                                        ),
                                      ])
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Icon(
                                                item.$2,
                                                color: item.$3,
                                                size: 22,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                text.translate(item.$1),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  letterSpacing: 0,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
