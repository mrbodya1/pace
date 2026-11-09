import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/account_service.dart';
import '../auth/sign_in_page.dart';
import 'welcome_stories.dart';

/// The application subtree exists only while the user has an accepted session.
class StartupFlow extends StatefulWidget {
  const StartupFlow({super.key, required this.home, this.accounts});
  final Widget home;
  final AccountService? accounts;

  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow> {
  static const welcomeKey = 'pace_welcome_completed_v1';
  late final accounts = widget.accounts ?? AccountService.instance;
  bool loading = true, introduced = false, entered = false;
  String? error;

  @override
  void initState() {
    super.initState();
    accounts.addListener(_accountChanged);
    _restore();
  }

  @override
  void dispose() {
    accounts.removeListener(_accountChanged);
    super.dispose();
  }

  void _accountChanged() {
    if (entered && accounts.account == null) {
      setState(() => entered = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await accounts.initialize();
      if (!mounted) return;
      setState(() {
        introduced =
            (prefs.getBool(welcomeKey) ?? false) || accounts.account != null;
        entered = accounts.account != null;
        loading = false;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = failure is AccountError
            ? failure.message
            : 'Не удалось открыть PACE. Повтори попытку.';
      });
    }
  }

  Future<void> _completeWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(welcomeKey, true)) {
      throw StateError('Welcome was not saved');
    }
    if (mounted) setState(() => introduced = true);
  }

  void _authenticated() {
    if (accounts.account != null) setState(() => entered = true);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _restore,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final stage = entered
        ? 'home'
        : introduced
        ? 'auth'
        : 'welcome';
    // Replacing the nested Navigator removes protected routes on logout and
    // prevents Back from reopening welcome/auth after a successful login.
    return KeyedSubtree(
      key: ValueKey(stage),
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) {
            if (entered) return widget.home;
            if (!introduced) {
              return WelcomeStories(onComplete: _completeWelcome);
            }
            return SignInPage(
              accounts: accounts,
              allowGuest: false,
              onAuthenticated: _authenticated,
            );
          },
        ),
      ),
    );
  }
}
