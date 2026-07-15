import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_authentication.dart';

typedef LoginCallback = Future<void> Function(String username, String password);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final LoginCallback onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    TextInput.finishAutofillContext();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onLogin(_username.text.trim(), _password.text);
    } on AppAuthenticationException catch (error) {
      if (!mounted) return;
      _password.clear();
      setState(() => _error = error.message);
      _passwordFocus.requestFocus();
    } on Object {
      if (!mounted) return;
      _password.clear();
      setState(() => _error = '登录失败，请稍后重试');
      _passwordFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                padding: const EdgeInsets.fromLTRB(32, 88, 32, 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Brand(),
                        const SizedBox(height: 76),
                        const Text(
                          '登录 Daylink',
                          style: TextStyle(
                            color: _text,
                            fontSize: 32,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '继续管理你的日程与主机',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 17,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 43),
                        const _FieldLabel('账号'),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('login-username'),
                          controller: _username,
                          enabled: !_submitting,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          maxLength: 32,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '请输入账号'
                              : null,
                          decoration: _inputDecoration('请输入账号'),
                        ),
                        const SizedBox(height: 25),
                        const _FieldLabel('密码'),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('login-password'),
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_submitting,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          maxLength: 128,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) =>
                              value == null || value.isEmpty ? '请输入密码' : null,
                          decoration: _inputDecoration('请输入密码').copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 22,
                                color: _muted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const Key('login-submit'),
                            onPressed: _submitting ? null : _submit,
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
                                : const Text('登录'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            key: const Key('login-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD54941),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const Spacer(),
                        const SizedBox(height: 48),
                        const Text(
                          '账号由 Daylink 管理员创建',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
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
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox.square(
        dimension: 64,
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
      const SizedBox(width: 14),
      const Text(
        'Daylink',
        style: TextStyle(
          color: _text,
          fontSize: 36,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
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
