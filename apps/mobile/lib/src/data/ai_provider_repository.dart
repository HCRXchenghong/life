import 'package:drift/drift.dart';

import '../domain/ai/ai_models.dart';
import 'app_database.dart';
import 'secret_vault.dart';

class AiProviderRepository {
  AiProviderRepository(this._db, this._vault);
  final AppDatabase _db;
  final SecretStore _vault;

  Future<void> save(AiProviderModel provider, {String? apiKey}) async {
    if (apiKey != null) await _vault.write(provider.secretRef, apiKey);
    if (apiKey == null && await _vault.read(provider.secretRef) == null) {
      throw StateError('API key is required for a new provider');
    }
    await _db
        .into(_db.aiProviderConfigs)
        .insertOnConflictUpdate(
          AiProviderConfigsCompanion.insert(
            id: provider.id,
            name: provider.name,
            kind: provider.kind.name,
            baseUrl: provider.baseUrl.toString().replaceFirst(
              RegExp(r'/$'),
              '',
            ),
            textModel: provider.textModel,
            imageModel: Value(provider.imageModel),
            secretRef: provider.secretRef,
            enabled: Value(provider.enabled),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<List<AiProviderModel>> list() async {
    final rows = await _db.select(_db.aiProviderConfigs).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<(AiProviderModel, String)> loadWithKey(String id) async {
    final row = await (_db.select(
      _db.aiProviderConfigs,
    )..where((table) => table.id.equals(id))).getSingle();
    final key = await _vault.read(row.secretRef);
    if (key == null) throw StateError('AI provider key is missing');
    return (_fromRow(row), key);
  }

  AiProviderModel _fromRow(AiProviderConfig row) => AiProviderModel(
    id: row.id,
    name: row.name,
    kind: AiProviderKind.values.byName(row.kind),
    baseUrl: Uri.parse(row.baseUrl),
    textModel: row.textModel,
    imageModel: row.imageModel,
    secretRef: row.secretRef,
    enabled: row.enabled,
  );
}
