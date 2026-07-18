import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

class ContentMasterKeyPage extends StatefulWidget {
  const ContentMasterKeyPage({super.key, required this.source});

  final ContentEncryptionSource source;

  @override
  State<ContentMasterKeyPage> createState() => _ContentMasterKeyPageState();
}

class _ContentMasterKeyPageState extends State<ContentMasterKeyPage> {
  ContentEncryptionState? _state;
  var _loading = true;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    try {
      final state = await widget.source.loadContentEncryptionState();
      if (!mounted || generation != _generation) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
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
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 66,
        leading: IconButton(
          key: const Key('content-master-key-back'),
          onPressed: () => Navigator.maybePop(context),
          padding: const EdgeInsets.only(left: 18),
          icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
        ),
        title: const Text(
          '内容主密钥',
          key: Key('content-master-key-title'),
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _divider),
        ),
      ),
      body: _loading
          ? const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          : _state == null
          ? _LoadFailure(onRetry: _load)
          : _MasterKeyBody(state: _state!),
    ),
  );
}

class _MasterKeyBody extends StatelessWidget {
  const _MasterKeyBody({required this.state});

  final ContentEncryptionState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const Key('content-master-key-scroll'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(25, 56, 25, 31),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 87),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ShieldLockIcon(),
              const SizedBox(height: 26),
              const Text(
                '内容主密钥已保护',
                key: Key('content-master-key-heading'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                '用于加密日程、对话与主机内容。\n密钥本身不会显示。',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 14, height: 1.55),
              ),
              const SizedBox(height: 47),
              const _SectionLabel('密钥状态'),
              const SizedBox(height: 11),
              Container(
                key: const Key('content-master-key-status-card'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  children: [
                    _StatusRow(label: '当前状态', value: _statusLabel(state)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 17),
                      child: Divider(height: 1, thickness: 1, color: _divider),
                    ),
                    _StatusRow(
                      label: '密钥版本',
                      value: state.keyVersion == null
                          ? '不可用'
                          : '第 ${state.keyVersion} 版',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const _SectionLabel('加密方式'),
              const SizedBox(height: 11),
              Container(
                key: const Key('content-master-key-algorithm-card'),
                height: 67,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: const Row(
                  children: [
                    Text('内容加密', style: TextStyle(color: _text, fontSize: 16)),
                    Spacer(),
                    Text(
                      contentEncryptionAlgorithmLabel,
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(top: 59),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: _muted, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '内容主密钥不可查看或导出',
                      style: TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShieldLockIcon extends StatelessWidget {
  const _ShieldLockIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 78,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.shield_outlined, color: _blue, size: 78),
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.lock_outline_rounded, color: _blue, size: 33),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF646A73),
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _text, fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(color: _muted, fontSize: 14)),
        ],
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('密钥状态加载失败', style: TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

String _statusLabel(ContentEncryptionState state) => switch (state.status) {
  ContentEncryptionSetupStatus.enabled ||
  ContentEncryptionSetupStatus.recoveryPending => '已解锁',
  ContentEncryptionSetupStatus.locked => '待解锁',
  ContentEncryptionSetupStatus.notConfigured => '未创建',
};

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
