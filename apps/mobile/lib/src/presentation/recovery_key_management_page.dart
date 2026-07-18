import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/sync/content_encryption_models.dart';

typedef RecoveryKeyRotationReadyCallback =
    Future<void> Function(RecoveryKeyRotationDraft draft);

class RecoveryKeyManagementPage extends StatefulWidget {
  const RecoveryKeyManagementPage({
    super.key,
    required this.source,
    required this.onRotationReady,
  });

  final ContentEncryptionSource source;
  final RecoveryKeyRotationReadyCallback onRotationReady;

  @override
  State<RecoveryKeyManagementPage> createState() =>
      _RecoveryKeyManagementPageState();
}

class _RecoveryKeyManagementPageState extends State<RecoveryKeyManagementPage> {
  var _busy = false;

  Future<void> _rotate() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新生成恢复密钥？'),
        content: const Text('新密钥会在你确认安全保存后启用，旧恢复密钥随后立即失效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('recovery-key-rotate-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final draft = await widget.source.prepareRecoveryKeyRotation();
      if (!mounted) return;
      await widget.onRotationReady(draft);
    } on ContentEncryptionException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('无法安全生成新的恢复密钥，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
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
    child: PopScope(
      canPop: !_busy,
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
            key: const Key('recovery-key-management-back'),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            padding: const EdgeInsets.only(left: 18),
            icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
          ),
          title: const Text(
            '恢复密钥',
            key: Key('recovery-key-management-title'),
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
        body: ListView(
          key: const Key('recovery-key-management-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 49, 24, 38),
          children: [
            const _ShieldKeyIcon(),
            const SizedBox(height: 24),
            const Text(
              '恢复密钥已保存',
              key: Key('recovery-key-management-heading'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '用于在新设备恢复你的加密内容。\n已保存的密钥不会再次显示。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.52),
            ),
            const SizedBox(height: 47),
            const Text(
              '恢复状态',
              style: TextStyle(
                color: Color(0xFF646A73),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 11),
            Container(
              key: const Key('recovery-key-status-card'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: const Column(
                children: [
                  _StatusRow(label: '保存状态', value: '已确认'),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 17),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
                  _StatusRow(label: '恢复范围', value: '日程、对话与主机内容'),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                key: const Key('recovery-key-rotate'),
                onPressed: _busy ? null : _rotate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.1,
                          color: _blue,
                        ),
                      )
                    : const Text('重新生成恢复密钥'),
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              '重新生成后，旧恢复密钥将立即失效',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShieldKeyIcon extends StatelessWidget {
  const _ShieldKeyIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 72,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.shield_outlined, color: _blue, size: 72),
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.key_rounded, color: _blue, size: 31),
        ),
      ],
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

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
