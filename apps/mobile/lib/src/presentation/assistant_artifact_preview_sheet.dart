import 'package:flutter/material.dart';

import '../domain/ai/assistant_artifact_models.dart';

Future<void> showAssistantArtifactPreviewSheet({
  required BuildContext context,
  required AssistantGeneratedArtifact artifact,
  required VoidCallback onDownload,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x99000000),
  builder: (_) =>
      AssistantArtifactPreviewSheet(artifact: artifact, onDownload: onDownload),
);

class AssistantArtifactPreviewSheet extends StatelessWidget {
  const AssistantArtifactPreviewSheet({
    super.key,
    required this.artifact,
    required this.onDownload,
  });

  final AssistantGeneratedArtifact artifact;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('assistant-artifact-preview-sheet'),
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7DAE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 17, 12),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(color: Color(0xFFE1E4E8)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('artifact-preview-close'),
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.maybePop(context),
                      child: const SizedBox.square(
                        dimension: 44,
                        child: Icon(
                          Icons.close_rounded,
                          size: 25,
                          color: Color(0xFF1F2329),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artifact.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F2329),
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${artifact.kind.label} · '
                          '${formatArtifactBytes(artifact.byteSize)}',
                          style: const TextStyle(
                            color: Color(0xFF8F959E),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('artifact-preview-download'),
                    onPressed: onDownload,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1F2329),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: const Text('下载', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: _ArtifactPreviewBody(preview: artifact.preview),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactPreviewBody extends StatelessWidget {
  const _ArtifactPreviewBody({required this.preview});

  final AssistantArtifactPreview preview;

  @override
  Widget build(BuildContext context) => switch (preview) {
    AssistantDocumentPreview document => _DocumentPreview(document: document),
    AssistantSpreadsheetPreview spreadsheet => _SpreadsheetPreview(
      spreadsheet: spreadsheet,
    ),
    AssistantPresentationPreview presentation => _PresentationPreview(
      presentation: presentation,
    ),
  };
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.document});

  final AssistantDocumentPreview document;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('artifact-document-preview'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
    children: [
      Container(
        constraints: const BoxConstraints(minHeight: 580),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              document.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 24,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            for (final paragraph in document.paragraphs) ...[
              Text(
                paragraph,
                style: const TextStyle(
                  color: Color(0xFF333740),
                  fontSize: 15,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 15),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        '1 / 1',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF646A73), fontSize: 13),
      ),
    ],
  );
}

class _SpreadsheetPreview extends StatefulWidget {
  const _SpreadsheetPreview({required this.spreadsheet});

  final AssistantSpreadsheetPreview spreadsheet;

  @override
  State<_SpreadsheetPreview> createState() => _SpreadsheetPreviewState();
}

class _SpreadsheetPreviewState extends State<_SpreadsheetPreview> {
  var _selectedSheet = 0;

  @override
  Widget build(BuildContext context) {
    final sheets = widget.spreadsheet.sheets;
    final selected = sheets[_selectedSheet];
    final columnCount = selected.rows.fold<int>(
      0,
      (count, row) => row.length > count ? row.length : count,
    );
    return Column(
      key: const Key('artifact-spreadsheet-preview'),
      children: [
        SizedBox(
          height: 58,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: sheets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 30),
            itemBuilder: (_, index) {
              final selected = index == _selectedSheet;
              return InkWell(
                key: Key('artifact-spreadsheet-sheet-$index'),
                onTap: () => setState(() => _selectedSheet = index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      sheets[index].name,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF3370FF)
                            : const Color(0xFF1F2329),
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 30 : 0,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3370FF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(
          child: columnCount == 0
              ? const Center(
                  child: Text(
                    '这个工作表暂时没有内容',
                    style: TextStyle(color: Color(0xFF8F959E), fontSize: 14),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: _SpreadsheetTableCard(
                    rows: selected.rows,
                    columnCount: columnCount,
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            children: [
              Text(
                '工作表 ${_selectedSheet + 1} / ${sheets.length}',
                style: const TextStyle(color: Color(0xFF4E5969), fontSize: 13),
              ),
              const SizedBox(height: 10),
              _PreviewPageDots(
                page: _selectedSheet,
                pageCount: sheets.length,
                semanticLabel: '工作表位置',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpreadsheetTableCard extends StatelessWidget {
  const _SpreadsheetTableCard({required this.rows, required this.columnCount});

  final List<List<String>> rows;
  final int columnCount;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('artifact-spreadsheet-table-card'),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E4E8)),
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: SingleChildScrollView(
      key: const Key('artifact-spreadsheet-horizontal-scroll'),
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(108),
          border: TableBorder.all(color: const Color(0xFFDDE1E6)),
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              _spreadsheetRow(
                row: rows[rowIndex],
                rowIndex: rowIndex,
                columnCount: columnCount,
              ),
          ],
        ),
      ),
    ),
  );
}

TableRow _spreadsheetRow({
  required List<String> row,
  required int rowIndex,
  required int columnCount,
}) {
  final isHeader = rowIndex == 0;
  final isSummary = _isSpreadsheetSummaryRow(row);
  return TableRow(
    decoration: BoxDecoration(
      color: isHeader
          ? const Color(0xFFF0F4FF)
          : isSummary
          ? const Color(0xFFFAFBFC)
          : Colors.white,
    ),
    children: [
      for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
        SizedBox(
          height: isHeader ? 54 : 58,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              child: Text(
                columnIndex < row.length ? row[columnIndex] : '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _spreadsheetCellColor(
                    columnIndex < row.length ? row[columnIndex] : '',
                    isHeader: isHeader,
                  ),
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: isHeader || isSummary
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

bool _isSpreadsheetSummaryRow(List<String> row) {
  if (row.isEmpty) return false;
  return const {'合计', '总计', '汇总', '小计'}.contains(row.first.trim());
}

Color _spreadsheetCellColor(String value, {required bool isHeader}) {
  if (isHeader) return const Color(0xFF1F2329);
  return switch (value.trim()) {
    '正常' || '完成' || '已完成' || '通过' => const Color(0xFF12A150),
    '超出' || '异常' || '风险' || '逾期' => const Color(0xFFE65C19),
    '进行中' => const Color(0xFF3370FF),
    _ => const Color(0xFF333740),
  };
}

class _PresentationPreview extends StatefulWidget {
  const _PresentationPreview({required this.presentation});

  final AssistantPresentationPreview presentation;

  @override
  State<_PresentationPreview> createState() => _PresentationPreviewState();
}

class _PresentationPreviewState extends State<_PresentationPreview> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.presentation.slides;
    return Column(
      key: const Key('artifact-presentation-preview'),
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (page) => setState(() => _page = page),
            itemCount: slides.length,
            itemBuilder: (_, index) {
              final slide = slides[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.08,
                    child: _PresentationSlideCard(
                      key: Key('artifact-presentation-slide-$index'),
                      presentationTitle: widget.presentation.title,
                      slide: slide,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            children: [
              Text(
                '${_page + 1} / ${slides.length}',
                style: const TextStyle(color: Color(0xFF4E5969), fontSize: 13),
              ),
              const SizedBox(height: 10),
              _PreviewPageDots(
                page: _page,
                pageCount: slides.length,
                semanticLabel: '左右滑动切换页面',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresentationSlideCard extends StatelessWidget {
  const _PresentationSlideCard({
    super.key,
    required this.presentationTitle,
    required this.slide,
  });

  final String presentationTitle;
  final AssistantPresentationSlide slide;

  @override
  Widget build(BuildContext context) {
    final titleParts = _presentationTextParts(slide.title);
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 24, 23, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDE1E6)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 47,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF3370FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleParts.$1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      titleParts.$2 ?? presentationTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7B8492),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(height: 1, color: const Color(0xFF3370FF)),
          const SizedBox(height: 13),
          Expanded(
            child: slide.bullets.isEmpty
                ? const Center(
                    child: Text(
                      '这一页暂时没有正文',
                      style: TextStyle(color: Color(0xFF8F959E), fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    itemCount: slide.bullets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _PresentationBulletRow(
                      index: index,
                      text: slide.bullets[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PresentationBulletRow extends StatelessWidget {
  const _PresentationBulletRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = _presentationTextParts(text);
    final icon = switch (index % 3) {
      0 => Icons.folder_open_rounded,
      1 => Icons.calendar_month_rounded,
      _ => Icons.verified_user_rounded,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF3370FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parts.$1,
                style: const TextStyle(
                  color: Color(0xFF1F2329),
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (parts.$2 case final description?) ...[
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF646A73),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewPageDots extends StatelessWidget {
  const _PreviewPageDots({
    required this.page,
    required this.pageCount,
    required this.semanticLabel,
  });

  final int page;
  final int pageCount;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dotCount = pageCount.clamp(1, 3);
    final activeDot = pageCount <= dotCount
        ? page
        : (page * dotCount ~/ pageCount).clamp(0, dotCount - 1);
    return Semantics(
      label: semanticLabel,
      child: Row(
        key: const Key('artifact-presentation-page-dots'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < dotCount; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: index == activeDot
                    ? const Color(0xFF3370FF)
                    : const Color(0xFFD3D6DC),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

(String, String?) _presentationTextParts(String value) {
  final normalized = value.trim();
  for (final separator in const ['\n', '：', ': ']) {
    final index = normalized.indexOf(separator);
    if (index > 0 && index < normalized.length - separator.length) {
      return (
        normalized.substring(0, index).trim(),
        normalized.substring(index + separator.length).trim(),
      );
    }
  }
  return (normalized, null);
}

String formatArtifactBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(kilobytes >= 10 ? 0 : 1)} KB';
  }
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(megabytes >= 10 ? 0 : 1)} MB';
}
