import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_authentication.dart';

typedef ChangePasswordCallback =
    Future<void> Function(String currentPassword, String newPassword);
typedef LogoutCallback = Future<void> Function();

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({
    super.key,
    required this.onChangePassword,
    required this.onLogout,
    this.firstLogin = true,
    this.onChanged,
  });

  final ChangePasswordCallback onChangePassword;
  final LogoutCallback onLogout;
  final bool firstLogin;
  final VoidCallback? onChanged;

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _loggingOut = false;
  String? _error;

  bool get _busy => _submitting || _loggingOut;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onChangePassword(_currentPassword.text, _newPassword.text);
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      widget.onChanged?.call();
    } on AppAuthenticationException catch (error) {
      if (!mounted) return;
      _currentPassword.clear();
      setState(() => _error = error.message);
    } on Object {
      if (!mounted) return;
      _currentPassword.clear();
      setState(() => _error = '修改密码失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      await widget.onLogout();
    } on Object {
      if (!mounted) return;
      setState(() => _error = '退出登录失败，请重试');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: AutofillGroup(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 88, 32, 22),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _CompactBrand(),
                        const SizedBox(height: 80),
                        Text(
                          widget.firstLogin ? '设置新密码' : '修改密码',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 32,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.firstLogin ? '首次登录需要修改密码' : '修改后，其他设备将退出登录',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 17,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 38),
                        const _FieldLabel('当前密码'),
                        const SizedBox(height: 10),
                        _PasswordField(
                          fieldKey: const Key('password-current'),
                          controller: _currentPassword,
                          enabled: !_busy,
                          obscureText: _obscureCurrent,
                          hint: '请输入当前密码',
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _newPasswordFocus.requestFocus(),
                          onToggleVisibility: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? '请输入当前密码' : null,
                        ),
                        const SizedBox(height: 28),
                        const _FieldLabel('新密码'),
                        const SizedBox(height: 10),
                        _PasswordField(
                          fieldKey: const Key('password-new'),
                          controller: _newPassword,
                          focusNode: _newPasswordFocus,
                          enabled: !_busy,
                          obscureText: _obscureNew,
                          hint: '请输入新密码',
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                              _confirmPasswordFocus.requestFocus(),
                          onToggleVisibility: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入新密码';
                            }
                            final error = validateStrongAppPassword(value);
                            if (error != null) return error;
                            if (value == _currentPassword.text) {
                              return '新密码不能与当前密码相同';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '至少 12 位，包含大小写字母、数字和符号',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 27),
                        const _FieldLabel('确认新密码'),
                        const SizedBox(height: 10),
                        _PasswordField(
                          fieldKey: const Key('password-confirm'),
                          controller: _confirmPassword,
                          focusNode: _confirmPasswordFocus,
                          enabled: !_busy,
                          obscureText: _obscureConfirm,
                          hint: '请再次输入新密码',
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onToggleVisibility: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          validator: (value) =>
                              value != _newPassword.text ? '两次输入的新密码不一致' : null,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            key: const Key('password-submit'),
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              disabledBackgroundColor: _primary.withValues(
                                alpha: 0.58,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    widget.firstLogin
                                        ? '完成并进入 Daylink'
                                        : '保存新密码',
                                  ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            key: const Key('password-change-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD54941),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (widget.firstLogin) ...[
                          const Spacer(),
                          const SizedBox(height: 48),
                          TextButton(
                            key: const Key('password-logout'),
                            onPressed: _busy ? null : _logout,
                            style: TextButton.styleFrom(
                              foregroundColor: _muted,
                              disabledForegroundColor: _muted.withValues(
                                alpha: 0.5,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            child: _loggingOut
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      color: _muted,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('退出登录'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox.square(
        dimension: 44,
        child: ClipRect(
          child: Transform.scale(
            scale: 1.58,
            child: Image.asset(
              'assets/branding/daylink_app_icon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      const Text(
        'Daylink',
        style: TextStyle(
          color: _text,
          fontSize: 30,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _text,
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.fieldKey,
    required this.controller,
    this.focusNode,
    required this.enabled,
    required this.obscureText,
    required this.hint,
    required this.autofillHints,
    required this.textInputAction,
    required this.onSubmitted,
    required this.onToggleVisibility,
    required this.validator,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool obscureText;
  final String hint;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onToggleVisibility;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    autofillHints: autofillHints,
    autocorrect: false,
    enableSuggestions: false,
    obscureText: obscureText,
    textInputAction: textInputAction,
    maxLength: 128,
    buildCounter:
        (_, {required currentLength, required isFocused, maxLength}) => null,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    decoration: _inputDecoration(hint).copyWith(
      suffixIcon: IconButton(
        tooltip: obscureText ? '显示密码' : '隐藏密码',
        onPressed: enabled ? onToggleVisibility : null,
        icon: Icon(
          obscureText
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 22,
          color: _muted,
        ),
      ),
    ),
  );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(
    color: Color(0xFF9AA0A9),
    fontSize: 16,
    fontWeight: FontWeight.w400,
  ),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: _fieldBorder,
  enabledBorder: _fieldBorder,
  disabledBorder: _fieldBorder,
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: _primary, width: 1.4),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: Color(0xFFD54941)),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: const BorderSide(color: Color(0xFFD54941), width: 1.4),
  ),
);

final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(11),
  borderSide: const BorderSide(color: Color(0xFFD4D7DC)),
);

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF646A73);
const _primary = Color(0xFF3370FF);
