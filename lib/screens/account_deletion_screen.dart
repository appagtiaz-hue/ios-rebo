import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../theme/home_palette.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key, this.service});
  final AccountDeletionGateway? service;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  late final AccountDeletionGateway _service;
  final _password = TextEditingController();
  bool _loading = true,
      _busy = false,
      _confirmed = false,
      _pending = false,
      _deleted = false;
  String? _error, _method;
  int? _backupDays;
  List<String> _methods = [];
  String t(String key) =>
      (AppLocalizations.of(context) ?? AppLocalizations(const Locale('ar')))
          .translate(key);

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        AccountDeletionService(
          providerProof: AuthService.proofForAccountDeletion,
        );
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pending = await _service.hasPending();
      if (pending) {
        if (mounted)
          setState(() {
            _pending = true;
            _loading = false;
          });
        return;
      }
      final options = await _service.options();
      final methods = (options['methods'] as List)
          .whereType<String>()
          .where((method) => ['password', 'google', 'apple'].contains(method))
          .toList();
      if (methods.isEmpty)
        throw StateError('No supported identity verification');
      if (mounted)
        setState(() {
          _methods = methods;
          _method = methods.first;
          _backupDays = options['backupRetentionDays'] as int?;
          _loading = false;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'deleteUnavailable';
        });
    }
  }

  Future<void> _submit() async {
    if (_busy || !_confirmed || _method == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(t('deleteConfirmTitle')),
        content: Text(t('deleteConfirmBody')),
        actions: [
          TextButton(
            key: const ValueKey('delete-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            key: const ValueKey('delete-final-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFAB3029),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('deletePermanent')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authorization = await _service.authorize(_method!, _password.text);
      _password.clear();
      if (authorization == null) return;
      if (!mounted) return;
      setState(() => _pending = true);
      _apply(await _service.delete(authorization));
    } on AccountDeletionFailure catch (error) {
      if (mounted)
        setState(
          () => _error = error.status == 429
              ? 'deleteWait'
              : error.status == 401
              ? 'deleteIdentityError'
              : 'deleteUnavailable',
        );
    } catch (_) {
      if (mounted) setState(() => _error = 'deleteUnavailable');
    } finally {
      _password.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(DeletionOutcome outcome) {
    if (!mounted) return;
    setState(() {
      _deleted = outcome == DeletionOutcome.deleted;
      _pending =
          outcome == DeletionOutcome.unknown ||
          outcome == DeletionOutcome.cleanupPending;
      _error = switch (outcome) {
        DeletionOutcome.unknown => 'deleteUnknown',
        DeletionOutcome.cleanupPending => 'deleteCleanupPending',
        DeletionOutcome.notDeleted => 'deleteNotCompleted',
        DeletionOutcome.deleted => null,
      };
    });
  }

  Future<void> _recover() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await _service.recover();
      _apply(outcome);
      if (outcome == DeletionOutcome.notDeleted) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    const danger = Color(0xFFAB3029);
    return PopScope(
      canPop: !_busy && !_pending && !_deleted,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.background,
          foregroundColor: p.ink,
          automaticallyImplyLeading: !_pending && !_deleted && !_busy,
          title: Text(
            t(_deleted ? 'deleteSuccessTitle' : 'deleteAccountTitle'),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            _deleted
                                ? Icons.check_circle_outline
                                : Icons.person_remove_outlined,
                            size: 48,
                            color: _deleted
                                ? p.green
                                : p.dark
                                ? const Color(0xFFF0ADA5)
                                : danger,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            t(_deleted ? 'deleteSuccessBody' : 'deleteWarning'),
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 17,
                              height: 1.6,
                            ),
                          ),
                          if (!_deleted) ...[
                            const SizedBox(height: 20),
                            for (final entry in [
                              ('deleteDataIdentity', Icons.person_outline),
                              ('deleteDataProgress', Icons.fact_check_outlined),
                              (
                                'deleteDataPlans',
                                Icons.workspace_premium_outlined,
                              ),
                              (
                                'deleteDataDevices',
                                Icons.phonelink_erase_outlined,
                              ),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      entry.$2,
                                      color: p.secondary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        t(entry.$1),
                                        style: TextStyle(
                                          color: p.ink,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const Divider(height: 32),
                            Text(
                              t('deleteBilling'),
                              style: TextStyle(color: p.secondary, height: 1.5),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: p.green),
                              onPressed: _busy
                                  ? null
                                  : () => launchUrl(
                                      Uri.parse(
                                        Theme.of(context).platform ==
                                                TargetPlatform.iOS
                                            ? 'https://apps.apple.com/account/subscriptions'
                                            : 'https://play.google.com/store/account/subscriptions',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                              child: Text(t('deleteManageSubscriptions')),
                            ),
                            Text(
                              t('deleteProofRetention'),
                              style: TextStyle(color: p.secondary, height: 1.5),
                            ),
                            if (_backupDays != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  t(
                                    'deleteBackups',
                                  ).replaceAll('{days}', '$_backupDays'),
                                  style: TextStyle(
                                    color: p.secondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  t(_error!),
                                  key: const ValueKey('delete-error'),
                                  style: TextStyle(
                                    color: p.dark
                                        ? const Color(0xFFF0ADA5)
                                        : danger,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          if (_deleted) ...[
                            const SizedBox(height: 24),
                            FilledButton(
                              key: const ValueKey('delete-complete'),
                              onPressed: () =>
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (_) => false,
                                  ),
                              child: Text(t('deleteReturnLogin')),
                            ),
                          ] else if (_pending) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const ValueKey('delete-recover'),
                              onPressed: _busy ? null : _recover,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                t(
                                  _busy ? 'deleteWorking' : 'deleteCheckStatus',
                                ),
                              ),
                            ),
                          ] else if (_methods.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            if (_methods.length > 1)
                              DropdownButtonFormField<String>(
                                initialValue: _method,
                                decoration: InputDecoration(
                                  labelText: t('deleteVerifyWith'),
                                ),
                                items: [
                                  for (final method in _methods)
                                    DropdownMenuItem(
                                      value: method,
                                      child: Text(t('deleteMethod_$method')),
                                    ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(() {
                                        _method = value;
                                        _password.clear();
                                      }),
                              ),
                            if (_method == 'password')
                              TextField(
                                key: const ValueKey('delete-password'),
                                controller: _password,
                                obscureText: true,
                                enabled: !_busy,
                                enableSuggestions: false,
                                autocorrect: false,
                                maxLength: 1024,
                                decoration: InputDecoration(
                                  labelText: t('deletePassword'),
                                  counterText: '',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            CheckboxListTile(
                              key: const ValueKey('delete-understand'),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _confirmed,
                              title: Text(
                                t('deleteUnderstand'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(
                                      () => _confirmed = value ?? false,
                                    ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const ValueKey('delete-start'),
                              style: FilledButton.styleFrom(
                                backgroundColor: danger,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onPressed:
                                  !_busy &&
                                      _confirmed &&
                                      (_method != 'password' ||
                                          _password.text.isNotEmpty)
                                  ? _submit
                                  : null,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.delete_forever_outlined),
                              label: Text(
                                t(_busy ? 'deleteWorking' : 'deletePermanent'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() => _loading = true);
                                      _load();
                                    },
                              child: Text(t('deleteRetry')),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
