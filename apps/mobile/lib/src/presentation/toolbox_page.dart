import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_navigation.dart';

enum ToolboxTool {
  friendSchedule,
  imageGeneration,
  wordDocument,
  spreadsheetPresentation,
}

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({
    super.key,
    required this.onToolSelected,
    required this.onDestinationSelected,
  });

  final ValueChanged<ToolboxTool> onToolSelected;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 27, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '工具箱',
                      key: Key('toolbox-title'),
                      style: TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 36,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      '常用能力，随用随取',
                      style: TextStyle(
                        color: Color(0xFF646A73),
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      '常用工具',
                      style: TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ToolRow(
                      children: [
                        _ToolCard(
                          key: const Key('tool-friend-schedule'),
                          icon: const _FriendScheduleIcon(),
                          title: '好友选时间',
                          subtitle: '发链接，一起定时间',
                          onTap: () =>
                              onToolSelected(ToolboxTool.friendSchedule),
                        ),
                        _ToolCard(
                          key: const Key('tool-image-generation'),
                          icon: const _ImageGenerationIcon(),
                          title: 'AI 生图',
                          subtitle: '描述想法，生成图片',
                          onTap: () =>
                              onToolSelected(ToolboxTool.imageGeneration),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ToolRow(
                      children: [
                        _ToolCard(
                          key: const Key('tool-word-document'),
                          icon: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF3370FF),
                            size: 32,
                          ),
                          title: 'Word 文档',
                          subtitle: '生成并保存文档',
                          onTap: () => onToolSelected(ToolboxTool.wordDocument),
                        ),
                        _ToolCard(
                          key: const Key('tool-spreadsheet-presentation'),
                          icon: const _SpreadsheetPresentationIcon(),
                          title: '表格与演示',
                          subtitle: 'Excel、PPT',
                          onTap: () => onToolSelected(
                            ToolboxTool.spreadsheetPresentation,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          DaylinkBottomNavigation(
            currentDestination: AppDestination.toolbox,
            onSelected: onDestinationSelected,
          ),
        ],
      ),
    ),
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: AspectRatio(aspectRatio: 1.43, child: children[0])),
      const SizedBox(width: 16),
      Expanded(child: AspectRatio(aspectRatio: 1.43, child: children[1])),
    ],
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFD9DCE1)),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 14, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(dimension: 34, child: icon),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8F959E),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FriendScheduleIcon extends StatelessWidget {
  const _FriendScheduleIcon();

  @override
  Widget build(BuildContext context) => const Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(Icons.calendar_month_outlined, color: Color(0xFF3370FF), size: 31),
      Positioned(
        right: -1,
        bottom: -1,
        child: Icon(Icons.group_outlined, color: Color(0xFF3370FF), size: 17),
      ),
    ],
  );
}

class _ImageGenerationIcon extends StatelessWidget {
  const _ImageGenerationIcon();

  @override
  Widget build(BuildContext context) => const Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(
        Icons.add_photo_alternate_outlined,
        color: Color(0xFF3370FF),
        size: 32,
      ),
      Positioned(
        right: -1,
        top: -4,
        child: Icon(Icons.auto_awesome, color: Color(0xFF3370FF), size: 13),
      ),
    ],
  );
}

class _SpreadsheetPresentationIcon extends StatelessWidget {
  const _SpreadsheetPresentationIcon();

  @override
  Widget build(BuildContext context) => const Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(Icons.table_chart_outlined, color: Color(0xFF3370FF), size: 30),
      Positioned(
        right: -2,
        bottom: 0,
        child: Icon(
          Icons.slideshow_outlined,
          color: Color(0xFF3370FF),
          size: 18,
        ),
      ),
    ],
  );
}
