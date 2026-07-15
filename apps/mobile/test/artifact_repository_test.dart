import 'dart:io';
import 'dart:typed_data';

import 'package:daylink_mobile/src/data/artifact_client.dart';
import 'package:daylink_mobile/src/data/artifact_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated Office files are stored inside the current account', () async {
    final root = await Directory.systemTemp.createTemp(
      'daylink-artifact-isolation-',
    );
    addTearDown(() => root.delete(recursive: true));
    const accountA = '22c2475a-2dd9-45a3-bfab-0ad5599fc835';
    const accountB = '1d2d2dbf-b5c0-45ec-b06e-8ce62a26eddd';
    final payload = GeneratedArtifactPayload(
      bytes: Uint8List.fromList(const [0x50, 0x4b, 0x03, 0x04]),
      contentType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      extension: 'docx',
    );

    final savedA = await ArtifactRepository(
      accountId: accountA,
      rootDirectory: root,
    ).save(title: '../周计划', artifact: payload);
    final savedB = await ArtifactRepository(
      accountId: accountB,
      rootDirectory: root,
    ).save(title: '周计划', artifact: payload);

    expect(savedA.localPath, contains('/accounts/$accountA/artifacts/'));
    expect(savedB.localPath, contains('/accounts/$accountB/artifacts/'));
    expect(savedA.localPath, isNot(savedB.localPath));
    expect(savedA.displayName, isNot(contains('..')));
    expect(await File(savedA.localPath).readAsBytes(), payload.bytes);
  });
}
