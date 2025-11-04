import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../domain/models.dart';
import '../domain/repositories.dart';

class JsonStateStore implements StateStore {
  final String dataDir;
  final String fileName;

  JsonStateStore({required this.dataDir, this.fileName = 'state.json'});

  File get _file => File(p.join(dataDir, fileName));

  @override
  Future<AppState> load() async {
    final dir = Directory(dataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (!await _file.exists()) {
      final s = AppState.empty();
      await save(s);
      return s;
    }
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return AppState.empty();
    return AppState.fromJson(jsonDecode(content));
  }

  @override
  Future<void> save(AppState state) async {
    final toSave = state.copyWith(updatedAt: DateTime.now());
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toSave.toJson()),
    );
  }
}
