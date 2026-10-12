import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/question.dart';
import '../services/database_service.dart';
import '../theme/home_palette.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Question> _questions = [];
  List<int> _answers = [];
  int _index = 0;
  int? _selected;
  bool _loading = true;
  bool _checked = false;
  bool _completed = false;
  final _scroll = ScrollController();
  AppLocalizations get _strings =>
      AppLocalizations.of(context) ?? AppLocalizations(const Locale('ar'));
  String _t(String key) => _strings.translate(key);

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await DatabaseService.getTrialQuestions();
      final processed = questions.map((q) {
        final correct = q.options[q.correctAnswerIndex];
        final options = List<String>.of(q.options)..shuffle();
        return q.copyWith(
          options: options,
          correctAnswerIndex: options.indexOf(correct),
        );
      }).toList()..shuffle();
      if (!mounted) return;
      setState(() {
        _questions = processed;
        _answers = List.filled(processed.length, -1);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _advance() {
    setState(() {
      if (_index == _questions.length - 1) {
        _completed = true;
      } else {
        _index++;
        _selected = _answers[_index] >= 0 ? _answers[_index] : null;
        _checked = false;
      }
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _text(
    String text, {
    double size = 15,
    bool bold = false,
    Color? color,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color ?? HomePalette.of(context).ink,
      height: 1.55,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: () => Navigator.maybePop(context),
                        color: p.ink,
                        icon: const BackButtonIcon(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _text(_t('trialTitle'), size: 18, bold: true),
                      ),
                      if (!_loading && !_completed && _questions.isNotEmpty)
                        Semantics(
                          label: _t('question'),
                          child: _text(
                            '${_index + 1}/${_questions.length}',
                            color: p.green,
                            bold: true,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.quiz_outlined,
                                  color: p.green,
                                  size: 40,
                                ),
                                const SizedBox(height: 16),
                                _text(_t('trialLoading')),
                                const SizedBox(height: 20),
                                LinearProgressIndicator(
                                  color: p.green,
                                  backgroundColor: p.greenSoft,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _questions.isEmpty
                      ? Center(child: _text(_t('noQuestionsAvailable')))
                      : SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: _completed ? _results(p) : _question(p),
                        ),
                ),
                if (!_loading && _questions.isNotEmpty) _actions(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(HomePalette p) {
    final q = _questions[_index];
    final correct = _selected == q.correctAnswerIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_index + 1) / _questions.length,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
          color: p.green,
          backgroundColor: p.greenSoft,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.edit_note_rounded, color: p.gold, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: _text(
                _t('chooseCorrectAnswer'),
                size: 13,
                color: p.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _text(q.questionText, size: 20, bold: true),
        const SizedBox(height: 24),
        for (var i = 0; i < q.options.length; i++) _option(q, i, p),
        if (_checked) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('trial-explanation'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      correct ? Icons.check_circle_outline : Icons.info_outline,
                      color: p.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _text(
                        _t(correct ? 'trialCorrect' : 'trialReview'),
                        bold: true,
                      ),
                    ),
                  ],
                ),
                if (!correct) ...[
                  const SizedBox(height: 8),
                  _text(
                    '${_t('correctAnswerLabel')} ${q.options[q.correctAnswerIndex]}',
                  ),
                ],
                if (q.answerJustification.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _text(
                    _t('homeExplanationTitle'),
                    size: 13,
                    color: p.secondary,
                  ),
                  const SizedBox(height: 4),
                  _text(q.answerJustification),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _option(Question q, int i, HomePalette p) {
    final selected = _selected == i;
    final correct = _checked && i == q.correctAnswerIndex;
    final wrong = _checked && selected && !correct;
    final danger = p.dark ? const Color(0xFFF0ADA5) : const Color(0xFF9E342A);
    final border = correct || selected ? (wrong ? danger : p.green) : p.border;
    final labels = _strings.locale.languageCode == 'ar'
        ? ['أ', 'ب', 'ج', 'د']
        : ['A', 'B', 'C', 'D'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        child: Material(
          color: correct || selected ? p.greenSoft : p.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: border,
              width: selected || correct ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('trial-option-$i'),
            onTap: _checked
                ? null
                : () => setState(() {
                    _selected = i;
                    _answers[_index] = i;
                  }),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: correct || wrong
                          ? Icon(
                              correct
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: border,
                              size: 24,
                            )
                          : _text(
                              i < labels.length ? labels[i] : '${i + 1}',
                              bold: true,
                              color: selected ? p.green : p.secondary,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _text(q.options[i], size: 16)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(HomePalette p) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    child: Row(
      children: [
        if (!_completed && _index > 0 && !_checked) ...[
          IconButton(
            key: const ValueKey('trial-previous'),
            tooltip: _t('previous'),
            color: p.green,
            icon: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
            ),
            onPressed: () {
              setState(() {
                _index--;
                _selected = _answers[_index] >= 0 ? _answers[_index] : null;
              });
              if (_scroll.hasClients) _scroll.jumpTo(0);
            },
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: FilledButton(
            key: const ValueKey('trial-primary'),
            style: FilledButton.styleFrom(
              backgroundColor: p.button,
              foregroundColor: p.buttonInk,
              disabledBackgroundColor: p.greenSoft,
              disabledForegroundColor: p.secondary,
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _completed
                ? () => Navigator.maybePop(context)
                : _selected == null
                ? null
                : _checked
                ? _advance
                : () => setState(() => _checked = true),
            child: Text(
              _t(
                _completed
                    ? 'trialReturnHome'
                    : !_checked
                    ? 'trialCheck'
                    : _index == _questions.length - 1
                    ? 'finishTest'
                    : 'next',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _results(HomePalette p) {
    final correct = List.generate(
      _questions.length,
      (i) => i,
    ).where((i) => _answers[i] == _questions[i].correctAnswerIndex).length;
    final percent = (correct / _questions.length * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.task_alt_rounded, size: 48, color: p.green),
        const SizedBox(height: 12),
        Center(child: _text(_t('testResult'), size: 22, bold: true)),
        const SizedBox(height: 12),
        Center(child: _text('$percent%', size: 36, bold: true, color: p.green)),
        Center(
          child: _text('$correct / ${_questions.length}', color: p.secondary),
        ),
        const SizedBox(height: 16),
        _text(_t('trialResultNote'), size: 13, color: p.secondary),
        const SizedBox(height: 24),
        for (var i = 0; i < _questions.length; i++)
          if (_answers[i] != _questions[i].correctAnswerIndex) ...[
            Divider(color: p.border),
            const SizedBox(height: 8),
            _text(_questions[i].questionText, size: 17, bold: true),
            const SizedBox(height: 8),
            _text(
              '${_t('trialYourAnswer')} ${_answers[i] >= 0 ? _questions[i].options[_answers[i]] : _t('notAnswered')}',
              color: p.secondary,
            ),
            const SizedBox(height: 8),
            _text(
              '${_t('correctAnswerLabel')} ${_questions[i].options[_questions[i].correctAnswerIndex]}',
              color: p.green,
            ),
            if (_questions[i].answerJustification.isNotEmpty) ...[
              const SizedBox(height: 8),
              _text(_questions[i].answerJustification),
            ],
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}
