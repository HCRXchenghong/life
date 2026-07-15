import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/application/daylink_services.dart';
import 'src/data/app_authentication.dart';
import 'src/data/app_session_monitor.dart';
import 'src/presentation/login_page.dart';

const _configuredApiBaseUrl = String.fromEnvironment(
  'DAYLINK_API_BASE_URL',
  defaultValue: 'https://192.168.101.71:8443/api/',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  runApp(const DaylinkApp());
}

typedef RuntimeFactory =
    Future<AppRuntime> Function(
      AppSessionCredentials session,
      AppAuthentication authentication,
    );

abstract interface class AppRuntime {
  Future<void> reconcile();
  Future<void> close();
}

abstract interface class ForcedSignOutAwareRuntime {
  Stream<String> get forcedSignOuts;
  bool get isSignedOut;
}

class DaylinkApp extends StatefulWidget {
  const DaylinkApp({
    super.key,
    this.authentication,
    this.runtimeFactory,
    this.apiBaseUri,
  });

  final AppAuthentication? authentication;
  final RuntimeFactory? runtimeFactory;
  final Uri? apiBaseUri;

  @override
  State<DaylinkApp> createState() => _DaylinkAppState();
}

class _DaylinkAppState extends State<DaylinkApp> with WidgetsBindingObserver {
  late final AppAuthentication _authentication;
  AppRuntime? _runtime;
  AppSessionCredentials? _session;
  StreamSubscription<String>? _forcedSignOutSubscription;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authentication =
        widget.authentication ??
        AppAuthenticator(
          apiBaseUri: widget.apiBaseUri ?? Uri.parse(_configuredApiBaseUrl),
        );
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final session = await _authentication.restore();
      if (!mounted) return;
      if (session != null) await _activate(session);
    } on Object {
      // Secure storage or local service startup failure falls back to the login
      // gate without exposing platform details.
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  Future<void> _login(String username, String password) async {
    final session = await _authentication.login(
      username: username,
      password: password,
      deviceName: _deviceName(),
    );
    try {
      await _activate(session);
    } on Object {
      await _authentication.clear();
      throw const AppAuthenticationException('本地服务启动失败，请重试');
    }
  }

  Future<void> _activate(AppSessionCredentials session) async {
    final runtime = await (widget.runtimeFactory ?? _startRuntime)(
      session,
      _authentication,
    );
    if (!mounted) {
      await runtime.close();
      return;
    }
    await _forcedSignOutSubscription?.cancel();
    _runtime = runtime;
    _session = session;
    if (runtime is ForcedSignOutAwareRuntime) {
      final signOutAware = runtime as ForcedSignOutAwareRuntime;
      _forcedSignOutSubscription = signOutAware.forcedSignOuts.listen((_) {
        unawaited(_handleForcedSignOut(runtime));
      });
      if (signOutAware.isSignedOut) {
        await _handleForcedSignOut(runtime);
        return;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleForcedSignOut(AppRuntime runtime) async {
    if (!identical(_runtime, runtime)) return;
    await _authentication.clear();
    await runtime.close();
    await _forcedSignOutSubscription?.cancel();
    _forcedSignOutSubscription = null;
    _runtime = null;
    _session = null;
    if (mounted) setState(() {});
  }

  static Future<AppRuntime> _startRuntime(
    AppSessionCredentials session,
    AppAuthentication authentication,
  ) => session.passwordChangeRequired
      ? Future<AppRuntime>.value(
          DaylinkSessionRuntime.start(
            apiBaseUri: authentication.apiBaseUri,
            accessToken: authentication.accessToken,
            refreshAccessToken: authentication.refresh,
            clearCredentials: authentication.clear,
          ),
        )
      : DaylinkRuntime.startForAccount(
          session.accountId,
          apiBaseUri: authentication.apiBaseUri,
          accessToken: authentication.accessToken,
          refreshAccessToken: authentication.refresh,
          clearCredentials: authentication.clear,
        );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runtime?.reconcile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_forcedSignOutSubscription?.cancel());
    unawaited(_runtime?.close());
    _authentication.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Daylink',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3370FF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    ),
    home: _bootstrapping
        ? const ColoredBox(color: Color(0xFFF7F8FA))
        : _session == null
        ? LoginPage(onLogin: _login)
        : const ColoredBox(
            key: Key('authenticated-page-pending-review'),
            color: Color(0xFFF7F8FA),
          ),
  );
}

String _deviceName() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'Daylink iOS',
  TargetPlatform.android => 'Daylink Android',
  _ => 'Daylink device',
};

class DaylinkRuntime implements AppRuntime, ForcedSignOutAwareRuntime {
  DaylinkRuntime._(this.services);

  final DaylinkServices services;
  final StreamController<String> _forcedSignOutController =
      StreamController<String>.broadcast();
  bool _signedOut = false;
  bool _closed = false;

  static Future<DaylinkRuntime> startForAccount(
    String accountId, {
    required Uri apiBaseUri,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    required SessionActionCallback clearCredentials,
  }) async {
    final services = await DaylinkServices.start(accountId: accountId);
    final runtime = DaylinkRuntime._(services);
    services.monitorSession(
      apiBaseUri: apiBaseUri,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
      clearCredentials: clearCredentials,
      onForcedSignOut: runtime._forceSignOut,
    );
    return runtime;
  }

  @override
  Stream<String> get forcedSignOuts => _forcedSignOutController.stream;

  @override
  bool get isSignedOut => _signedOut;

  Future<void> _forceSignOut(String reason) async {
    if (_signedOut) return;
    _signedOut = true;
    await services.close();
    if (!_forcedSignOutController.isClosed) {
      _forcedSignOutController.add(reason);
    }
  }

  @override
  Future<void> reconcile() =>
      _signedOut ? Future<void>.value() : services.reconcile();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await services.close();
    await _forcedSignOutController.close();
  }
}

/// Keeps forced sign-out active before a first-login password change without
/// opening the account database or any user content.
class DaylinkSessionRuntime implements AppRuntime, ForcedSignOutAwareRuntime {
  DaylinkSessionRuntime._(this._monitor);

  final AppSessionMonitor _monitor;
  final StreamController<String> _forcedSignOutController =
      StreamController<String>.broadcast();
  bool _signedOut = false;
  bool _closed = false;

  static DaylinkSessionRuntime start({
    required Uri apiBaseUri,
    required AccessTokenProvider accessToken,
    required SessionRefreshCallback refreshAccessToken,
    required SessionActionCallback clearCredentials,
  }) {
    late DaylinkSessionRuntime runtime;
    final monitor = AppSessionMonitor(
      apiBaseUri: apiBaseUri,
      accessToken: accessToken,
      refreshAccessToken: refreshAccessToken,
      clearCredentials: clearCredentials,
      onForcedSignOut: (reason) => runtime._forceSignOut(reason),
    );
    runtime = DaylinkSessionRuntime._(monitor);
    monitor.start();
    return runtime;
  }

  @override
  Stream<String> get forcedSignOuts => _forcedSignOutController.stream;

  @override
  bool get isSignedOut => _signedOut;

  Future<void> _forceSignOut(String reason) async {
    if (_signedOut) return;
    _signedOut = true;
    if (!_forcedSignOutController.isClosed) {
      _forcedSignOutController.add(reason);
    }
  }

  @override
  Future<void> reconcile() => _monitor.reconcile();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _monitor.close();
    await _forcedSignOutController.close();
  }
}
