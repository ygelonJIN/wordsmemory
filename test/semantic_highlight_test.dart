import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:demo1red/backend/study.dart';

void main() {
  // 在所有测试前初始化 FFI
  setUpAll(() {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('filterInvalidHighlightUuids', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE Note (
          Concept_UUID TEXT PRIMARY KEY,
          Spelling TEXT NOT NULL,
          Phonetic TEXT NOT NULL,
          Definition TEXT NOT NULL
        ) STRICT
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('valid UUIDs keep c=1', () async {
      await db.insert('Note', {
        'Concept_UUID': 'uuid-valid-1',
        'Spelling': 'test',
        'Phonetic': 'test',
        'Definition': 'test',
      });

      final segments = [
        {'t': 'hello', 'c': 1, 'u': 'uuid-valid-1'},
      ];

      await filterInvalidHighlightUuids(segments, db);

      expect(segments[0]['c'], 1);
    });

    test('invalid UUIDs set c=0', () async {
      final segments = [
        {'t': 'hello', 'c': 1, 'u': 'uuid-invalid'},
      ];

      await filterInvalidHighlightUuids(segments, db);

      expect(segments[0]['c'], 0);
    });

    test('mixed valid/invalid UUIDs in same list', () async {
      await db.insert('Note', {
        'Concept_UUID': 'uuid-valid-1',
        'Spelling': 'a',
        'Phonetic': 'a',
        'Definition': 'a',
      });
      await db.insert('Note', {
        'Concept_UUID': 'uuid-valid-2',
        'Spelling': 'b',
        'Phonetic': 'b',
        'Definition': 'b',
      });

      final segments = [
        {'t': 'word1', 'c': 1, 'u': 'uuid-valid-1'},
        {'t': 'word2', 'c': 1, 'u': 'uuid-invalid'},
        {'t': 'word3', 'c': 1, 'u': 'uuid-valid-2'},
      ];

      await filterInvalidHighlightUuids(segments, db);

      expect(segments[0]['c'], 1, reason: 'valid uuid-1 should keep c=1');
      expect(segments[1]['c'], 0, reason: 'invalid uuid should set c=0');
      expect(segments[2]['c'], 1, reason: 'valid uuid-2 should keep c=1');
    });

    test('no highlights at all', () async {
      final segments = [
        {'t': 'plain', 'c': 0, 'u': ''},
        {'t': 'text', 'c': 0, 'u': ''},
      ];

      await filterInvalidHighlightUuids(segments, db);

      expect(segments[0]['c'], 0);
      expect(segments[1]['c'], 0);
    });

    test('empty segments list', () async {
      final segments = <Map<String, dynamic>>[];

      await filterInvalidHighlightUuids(segments, db);

      expect(segments, isEmpty);
    });

    test('highlight with empty uuid stays c=1 (defensive)', () async {
      // seg['u'] is empty string, so the where clause filters it out.
      // The function only invalidates when uuid is non-empty and not in DB.
      // Empty uuid is treated as not-a-highlight by the WHERE clause.
      final segments = [
        {'t': 'word', 'c': 1, 'u': ''},
      ];

      await filterInvalidHighlightUuids(segments, db);

      // c stays 1 because empty uuid is skipped (not in highlightUuids list)
      // This is correct: empty uuid with c=1 is a data bug, but not this function's job
      expect(segments[0]['c'], 1);
    });

    test('duplicate UUIDs in segments handled correctly', () async {
      await db.insert('Note', {
        'Concept_UUID': 'uuid-dup',
        'Spelling': 'dup',
        'Phonetic': 'dup',
        'Definition': 'dup',
      });

      final segments = [
        {'t': 'word1', 'c': 1, 'u': 'uuid-dup'},
        {'t': 'word2', 'c': 1, 'u': 'uuid-dup'},
        {'t': 'word3', 'c': 1, 'u': 'uuid-missing'},
      ];

      await filterInvalidHighlightUuids(segments, db);

      expect(segments[0]['c'], 1, reason: 'valid uuid should keep c=1');
      expect(segments[1]['c'], 1, reason: 'valid uuid should keep c=1');
      expect(segments[2]['c'], 0, reason: 'missing uuid should set c=0');
    });
  });
}
