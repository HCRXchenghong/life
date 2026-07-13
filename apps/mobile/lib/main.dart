import 'dart:async';

import 'package:flutter/material.dart';

import 'src/application/daylink_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaylinkApp());
}

typedef RuntimeFactory = Future<AppRuntime> Function();

abstract interface class AppRuntime {
  Future<void> reconcile();
  Future<void> close();
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
    unawaited(_runtime?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ColoredBox(color: Color(0xFFF7F2E8)),
  );
}

class DaylinkRuntime implements AppRuntime {
  DaylinkRuntime._(this.services);

  final DaylinkServices services;

  static Future<DaylinkRuntime> start() async {
    return DaylinkRuntime._(await DaylinkServices.start());
  }

  @override
  Future<void> reconcile() => services.reconcile();

  @override
  Future<void> close() => services.close();
}
