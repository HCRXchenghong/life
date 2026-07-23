import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/ai/assistant_artifact_models.dart';

class AssistantArtifactPreviewPage extends StatelessWidget {
  const AssistantArtifactPreviewPage({super.key, required this.artifact});

  final AssistantGeneratedArtifact artifact;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('artifact-preview-close'),
          tooltip: '关闭预览',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              artifact.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${artifact.kind.label} · ${formatArtifactBytes(artifact.byteSize)}',
              style: const TextStyle(
                color: Color(0xFF8F959E),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _ArtifactPreviewBody(preview: artifact.preview),
      ),
    ),
  );
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
        if (sheets.length > 1)
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: sheets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ChoiceChip(
                label: Text(sheets[index].name),
                selected: index == _selectedSheet,
                onSelected: (_) => setState(() => _selectedSheet = index),
              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(132),
                      border: TableBorder.all(color: const Color(0xFFDDE1E6)),
                      children: [
                        for (
                          var rowIndex = 0;
                          rowIndex < selected.rows.length;
                          rowIndex++
                        )
                          TableRow(
                            decoration: BoxDecoration(
                              color: rowIndex == 0
                                  ? const Color(0xFFF0F4FF)
                                  : Colors.white,
                            ),
                            children: [
                              for (
                                var columnIndex = 0;
                                columnIndex < columnCount;
                                columnIndex++
                              )
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    columnIndex < selected.rows[rowIndex].length
                                        ? selected.rows[rowIndex][columnIndex]
                                        : '',
                                    style: TextStyle(
                                      color: const Color(0xFF333740),
                                      fontSize: 13,
                                      fontWeight: rowIndex == 0
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.title,
                              style: const TextStyle(
                                color: Color(0xFF1F2329),
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            for (final bullet in slide.bullets)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 7),
                                      child: CircleAvatar(
                                        radius: 2.5,
                                        backgroundColor: Color(0xFF3370FF),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        bullet,
                                        style: const TextStyle(
                                          color: Color(0xFF4E5969),
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            '${_page + 1} / ${slides.length}',
            style: const TextStyle(color: Color(0xFF646A73), fontSize: 13),
          ),
        ),
      ],
    );
  }
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
