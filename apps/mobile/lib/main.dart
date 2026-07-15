import 'dart:async';

import 'package:flutter/material.dart';

import 'src/application/daylink_services.dart';
import 'src/data/app_session_monitor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaylinkApp());
}

typedef RuntimeFactory = Future<AppRuntime> Function();

abstract interface class AppRuntime {
  Future<void> reconcile();
  Future<void> close();
}

abstract interface class ForcedSignOutAwareRuntime {
  Stream<String> get forcedSignOuts;
  bool get isSignedOut;
}

/// Headless application shell. Product screens intentionally live outside this
/// milestone; the shell only starts persistence and native background services.
class DaylinkApp extends StatefulWidget {
  const DaylinkApp({super.key, this.runtimeFactory});

  final RuntimeFactory? runtimeFactory;

  @override
  State<DaylinkApp> createState() => _DaylinkAppState();
}

class _DaylinkAppState extends State<DaylinkApp> with WidgetsBindingObserver {
  AppRuntime? _runtime;
  StreamSubscription<String>? _forcedSignOutSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  Future<void> _start() async {
    final runtime = await (widget.runtimeFactory ?? DaylinkRuntime.start)();
    if (!mounted) {
      await runtime.close();
      return;
    }
    _runtime = runtime;
    if (runtime is ForcedSignOutAwareRuntime) {
      final signOutAware = runtime as ForcedSignOutAwareRuntime;
      _forcedSignOutSubscription = signOutAware.forcedSignOuts.listen((_) {
        if (!mounted) return;
        unawaited(runtime.close());
        setState(() => _runtime = null);
      });
      if (signOutAware.isSignedOut) {
        await runtime.close();
        if (mounted) setState(() => _runtime = null);
      }
    }
  }

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ColoredBox(color: Color(0xFFF7F2E8)),
  );
}

class DaylinkRuntime implements AppRuntime, ForcedSignOutAwareRuntime {
  DaylinkRuntime._(this.services);

  final DaylinkServices? services;
  final StreamController<String> _forcedSignOutController =
      StreamController<String>.broadcast();
  bool _signedOut = false;
  bool _closed = false;

  /// Signed-out startup never opens an account database. The login flow will
  /// replace this runtime with [startForAccount] after server authentication.
  static Future<DaylinkRuntime> start() async => DaylinkRuntime._(null);

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
    await services?.close();
    if (!_forcedSignOutController.isClosed) {
      _forcedSignOutController.add(reason);
    }
  }

  @override
  Future<void> reconcile() => _signedOut
      ? Future<void>.value()
      : services?.reconcile() ?? Future<void>.value();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await services?.close();
    await _forcedSignOutController.close();
  }
}
