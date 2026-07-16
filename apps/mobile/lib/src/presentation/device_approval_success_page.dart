import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeviceApprovalSuccessPage extends StatelessWidget {
  const DeviceApprovalSuccessPage({super.key});

  void _finish(BuildContext context) => Navigator.of(context).pop(true);

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
          key: const Key('approval-success-back'),
          onPressed: () => _finish(context),
          padding: const EdgeInsets.only(left: 18),
          icon: const Icon(Icons.arrow_back_rounded, size: 29, color: _text),
        ),
        title: const Text(
          '恢复加密内容',
          key: Key('approval-success-title'),
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
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const Key('approval-success-scroll'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(26, 69, 26, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 97),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const _SuccessShieldIcon(),
                  const SizedBox(height: 27),
                  const Text(
                    '加密内容已恢复',
                    key: Key('approval-success-heading'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _text,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    '这台设备现在可以安全同步你的日程、\n对话与主机内容。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 45),
                  Container(
                    key: const Key('approval-success-card'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Column(
                      children: [
                        _SuccessRow(label: '内容密钥', value: '已恢复'),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: _divider,
                          ),
                        ),
                        _SuccessRow(label: '同步状态', value: '准备就绪'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 57),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const Key('approval-success-done'),
                      onPressed: () => _finish(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('完成'),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, color: _muted, size: 19),
                      SizedBox(width: 7),
                      Text(
                        '密钥仅保存在你的受信设备中',
                        style: TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SuccessRow extends StatelessWidget {
  const _SuccessRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _text,
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(value, style: const TextStyle(color: _muted, fontSize: 14.5)),
          const SizedBox(width: 10),
          const Icon(
            Icons.check_circle_outline_rounded,
            color: _blue,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

class _SuccessShieldIcon extends StatelessWidget {
  const _SuccessShieldIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 68,
    height: 68,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.shield_outlined, color: _blue, size: 67),
        Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Icon(Icons.check_rounded, color: _blue, size: 32),
        ),
      ],
    ),
  );
}

const _background = Color(0xFFF7F8FA);
const _text = Color(0xFF1F2329);
const _muted = Color(0xFF8F959E);
const _blue = Color(0xFF3370FF);
const _divider = Color(0xFFE7E9ED);
const _cardBorder = Color(0xFFDDE1E7);
