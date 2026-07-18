import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/poster_share_service.dart';
import '../application/poster_template_renderer.dart';
import '../domain/poster/poster_template_models.dart';
import '../domain/share/share_poll_models.dart';

class FriendInvitePosterSheet extends StatefulWidget {
  const FriendInvitePosterSheet({
    super.key,
    required this.template,
    required this.data,
    required this.invite,
    this.renderer = const PosterTemplateRenderer(),
    this.shareService = const PosterShareService(),
  });

  final PosterTemplate template;
  final PosterRenderData data;
  final FriendPollInvite invite;
  final PosterTemplateRenderer renderer;
  final PosterShareService shareService;

  @override
  State<FriendInvitePosterSheet> createState() =>
      _FriendInvitePosterSheetState();
}

class _FriendInvitePosterSheetState extends State<FriendInvitePosterSheet> {
  Uint8List? _bytes;
  String? _error;
  var _busy = false;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_render());
  }

  Future<void> _render() async {
    try {
      final bytes = await widget.renderer.render(
        template: widget.template,
        data: widget.data,
      );
      if (mounted) setState(() => _bytes = bytes);
    } on Object {
      if (mounted) setState(() => _error = '海报生成失败，请稍后重试');
    }
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (_busy || bytes == null) return;
    setState(() => _busy = true);
    try {
      await widget.shareService.saveToGallery(
        bytes: bytes,
        inviteId: widget.invite.id,
      );
      _saved = true;
      _message('海报已保存到相册');
    } on PosterShareException catch (error) {
      _message(error.message);
    } on Object {
      _message('暂时无法保存海报');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (_busy || bytes == null) return;
    setState(() => _busy = true);
    var savedBeforeShare = _saved;
    if (!savedBeforeShare) {
      try {
        await widget.shareService.saveToGallery(
          bytes: bytes,
          inviteId: widget.invite.id,
        );
        savedBeforeShare = true;
        _saved = true;
      } on Object {
        // A denied gallery permission must not prevent the user from sharing.
      }
    }
    try {
      await widget.shareService.share(
        bytes: bytes,
        inviteId: widget.invite.id,
        inviteUrl: widget.invite.inviteUrl,
        activityTitle: widget.data.activityTitle,
        sharePositionOrigin: _sharePositionOrigin(),
      );
      if (!savedBeforeShare) _message('海报未保存到相册，但仍可继续分享');
    } on Object {
      _message('暂时无法调起分享');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: widget.invite.inviteUrl.toString()),
      ).timeout(const Duration(seconds: 2));
      _message('专属链接已复制');
    } on Object {
      _message('复制失败，请稍后重试');
    }
  }

  Rect _sharePositionOrigin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(value)),
      );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DCE3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.invite.displayName}的邀请海报',
                        style: const TextStyle(
                          color: Color(0xFF1F2329),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.template.name} · 每位朋友二维码不同',
                        style: const TextStyle(
                          color: Color(0xFF8F959E),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio:
                    widget.template.schema.canvas.width /
                    widget.template.schema.canvas.height,
                child: _poster(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('friend-poster-copy-link'),
                    onPressed: _busy ? null : _copy,
                    child: const Text('复制链接'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('friend-poster-save'),
                    onPressed: _busy || _bytes == null ? null : _save,
                    child: Text(_saved ? '已保存' : '保存相册'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton(
                    key: const Key('friend-poster-share'),
                    onPressed: _busy || _bytes == null ? null : _share,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3370FF),
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('分享海报'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _poster() {
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _render,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
    );
  }
}
