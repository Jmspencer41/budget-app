import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models.dart';

void main() {
  test('a remote session is saved without the password', () {
    const account = Account(
      id: 'user-1',
      firstName: 'Philip',
      lastName: 'Bierley',
      email: 'philip@home.lab',
      password: '',
      token: 'signed-token',
    );

    final saved = account.toJson();

    expect(saved.containsKey('password'), isFalse);
    expect(saved['token'], 'signed-token');
    expect(Account.fromJson(saved).token, 'signed-token');
    expect(Account.fromJson(saved).password, isEmpty);
  });
}
