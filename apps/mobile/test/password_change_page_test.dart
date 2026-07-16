import 'package:daylink_mobile/src/presentation/password_change_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved minimal regular password page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordChangePage(
          firstLogin: false,
          onChangePassword: (_, _) async {},
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-page-title')), findsOneWidget);
    expect(find.text('修改后，其他设备将退出登录。'), findsOneWidget);
    expect(find.text('当前密码'), findsOneWidget);
    expect(find.text('新密码'), findsOneWidget);
    expect(find.text('确认新密码'), findsOneWidget);
    expect(find.text('至少 12 位，包含大小写字母、数字和符号'), findsOneWidget);
    expect(find.text('保存新密码'), findsOneWidget);
    expect(find.byKey(const Key('password-back')), findsOneWidget);
    expect(find.text('Daylink'), findsNothing);
    expect(find.text('首次登录需要修改密码'), findsNothing);
    expect(find.byKey(const Key('password-logout')), findsNothing);
  });

  testWidgets('validates and submits a regular password change', (
    tester,
  ) async {
    String? currentPassword;
    String? newPassword;
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordChangePage(
          firstLogin: false,
          onChangePassword: (current, replacement) async {
            currentPassword = current;
            newPassword = replacement;
          },
          onLogout: () async {},
          onChanged: () => changed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('password-current')),
      'Current!Pass123',
    );
    await tester.enterText(
      find.byKey(const Key('password-new')),
      'Replacement2!',
    );
    await tester.enterText(
      find.byKey(const Key('password-confirm')),
      'Replacement2!',
    );
    tester.testTextInput.hide();
    await tester.tap(find.byKey(const Key('password-submit')));
    await tester.pumpAndSettle();

    expect(currentPassword, 'Current!Pass123');
    expect(newPassword, 'Replacement2!');
    expect(changed, isTrue);
  });
}
