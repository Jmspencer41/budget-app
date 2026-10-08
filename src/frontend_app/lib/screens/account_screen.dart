import 'package:flutter/material.dart';

import '../ledger.dart';
import '../models.dart';
import '../theme.dart';

class AccountScreen extends StatefulWidget {
  final Ledger ledger;

  const AccountScreen({super.key, required this.ledger});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _password;
  String? _error;

  bool get _hasAccount => widget.ledger.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.ledger.account;
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _email = TextEditingController(text: account?.email ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_hasAccount) {
      final ok = widget.ledger.signIn(_email.text, _password.text);
      if (!ok) setState(() => _error = 'That email or password does not match this device.');
      return;
    }
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (first.isEmpty || last.isEmpty || !email.contains('@') || password.length < 4) {
      setState(() => _error = 'Enter your name, a valid email, and a password of at least 4 characters.');
      return;
    }
    widget.ledger.createAccount(
      Account(firstName: first, lastName: last, email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              Text(
                _hasAccount ? 'Sign in' : 'Create account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _hasAccount
                    ? 'Sign in to the account saved on this device.'
                    : 'Budget Buddy keeps your budgets on this device. Create an account to start.',
                style: const TextStyle(color: AppColors.inkFade),
              ),
              const SizedBox(height: 24),
              if (!_hasAccount) ...[
                TextField(
                  key: const Key('account-first-name'),
                  controller: _firstName,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('account-last-name'),
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const Key('account-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('account-password'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.rust)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: Text(_hasAccount ? 'Sign in' : 'Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
