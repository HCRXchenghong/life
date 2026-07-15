import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/secret_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account database factory rejects untrusted path input', () {
    expect(
      () => AppDatabase.openForAccount('../../shared'),
      throwsArgumentError,
    );
  });

  test('secret vault requires a canonical server account id', () {
    expect(() => SecretVault(accountId: '../other'), throwsArgumentError);
    expect(
      () => SecretVault(accountId: '123e4567-e89b-12d3-a456-426614174000'),
      returnsNormally,
    );
  });
}
