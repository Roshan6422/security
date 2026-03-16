import 'dart:convert';
import 'dart:io';

import 'package:dart_firebase_admin/firestore.dart';
import 'package:uuid/uuid.dart';

import '../config/firebase.dart';

const _uuid = Uuid();

// ─── In-Memory Store (fallback when Firebase is not available) ──────
Map<String, Map<String, Map<String, dynamic>>> _inMemoryStore = {};
bool _loadedFromDisk = false;
const String _dbFile = 'data/temp_db.json';

void _saveToDisk() {
  try {
    final dir = Directory('data');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File(_dbFile).writeAsStringSync(jsonEncode(_inMemoryStore));
  } catch (e) {
    print('Failed to save in-memory DB to disk: $e');
  }
}

void _loadFromDisk() {
  if (_loadedFromDisk) return;
  try {
    final file = File(_dbFile);
    if (file.existsSync()) {
      final rawData = file.readAsStringSync();
      if (rawData.trim().isNotEmpty) {
        final data = jsonDecode(rawData) as Map<String, dynamic>;
        _inMemoryStore = data.map((key, value) => MapEntry(
            key,
            (value as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)))));
        print('✅ Loaded in-memory DB from disk');
      }
    }
  } catch (e) {
    print('❌ Failed to load in-memory DB from disk: $e');
    _inMemoryStore = {};
  } finally {
    _loadedFromDisk = true;
  }
}

Map<String, Map<String, dynamic>> _getMemoryCollection(String name) {
  _loadFromDisk();
  return _inMemoryStore.putIfAbsent(name, () => {});
}

// ────────────────────────────────────────────────────────────────────

/// Abstract base class providing Firestore CRUD with an automatic
/// in-memory fallback when Firebase is not initialised.
///
/// Subclasses must override [collectionName] to specify the Firestore
/// collection. They should also provide a factory constructor that
/// calls [FirestoreModel.fromMap].
abstract class FirestoreModel {
  String? id;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// The Firestore collection name for this model.
  String get collectionName;

  /// Converts this model to a JSON-compatible map **excluding** `_id`.
  Map<String, dynamic> toMap();

  /// Populates this model's fields from a map (used by subclass factories).
  void populateFromMap(Map<String, dynamic> map) {
    id = map['_id'] as String?;
    createdAt = parseDate(map['createdAt']);
    updatedAt = parseDate(map['updatedAt']);
  }

  /// Serialises the model for JSON responses (includes `_id`).
  Map<String, dynamic> toJson() {
    final map = toMap();
    map['_id'] = id;
    map['createdAt'] = createdAt?.toIso8601String();
    map['updatedAt'] = updatedAt?.toIso8601String();
    return map;
  }

  // ─── Instance Methods ──────────────────────────────────────────────

  /// Persists changes to Firestore (or in-memory store).
  Future<void> save() async {
    updatedAt = DateTime.now();
    final data = toMap();
    data['updatedAt'] = updatedAt!.toIso8601String();

    if (!FirebaseConfig.isInitialized) {
      _memSave(data);
      return;
    }

    final col = FirebaseConfig.db!.collection(collectionName);
    if (id != null) {
      await col.doc(id!).update(data);
    } else {
      createdAt = DateTime.now();
      data['createdAt'] = createdAt!.toIso8601String();
      final docRef = await col.add(data);
      id = docRef.id;
    }
  }

  /// Deletes this document from Firestore (or in-memory store).
  Future<void> deleteOne() async {
    if (id == null) return;

    if (!FirebaseConfig.isInitialized) {
      _memDeleteOne();
      return;
    }
    await FirebaseConfig.db!.collection(collectionName).doc(id!).delete();
  }

  // ─── In-Memory Instance Helpers ────────────────────────────────────

  void _memSave(Map<String, dynamic> data) {
    final col = _getMemoryCollection(collectionName);
    if (id != null) {
      col[id!] = {...?col[id], ...data};
    } else {
      id = _uuid.v4();
      createdAt = DateTime.now();
      data['createdAt'] = createdAt!.toIso8601String();
      col[id!] = data;
    }
    _saveToDisk();
  }

  void _memDeleteOne() {
    if (id == null) return;
    final col = _getMemoryCollection(collectionName);
    col.remove(id);
    _saveToDisk();
  }

  // ─── Utilities ─────────────────────────────────────────────────────

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Provides the static query methods (find, create, deleteMany) for a
/// given [FirestoreModel] subclass.
///
/// Each model should create a companion repository instance, e.g.:
/// ```dart
/// final userRepo = ModelRepository<User>('users', User.fromMap);
/// ```
class ModelRepository<T extends FirestoreModel> {
  /// Creates a repository for the given [collectionName].
  ModelRepository(this.collectionName, this._fromMap);

  /// The Firestore collection this repository operates on.
  final String collectionName;

  /// Factory function that creates a [T] from a data map.
  final T Function(Map<String, dynamic>) _fromMap;

  /// Finds a single document matching [query].
  Future<T?> findOne(Map<String, dynamic> query) async {
    if (!FirebaseConfig.isInitialized) {
      return _memFindOne(query);
    }

    // Fast-path: lookup by _id
    if (query.containsKey('_id')) {
      final doc = await FirebaseConfig.db!
          .collection(collectionName)
          .doc(query['_id'] as String)
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['_id'] = doc.id;
      return _fromMap(data);
    }

    var ref = FirebaseConfig.db!.collection(collectionName)
        as Query<Map<String, dynamic>>;
    for (final entry in query.entries) {
      ref = ref.where(entry.key, WhereFilter.equal, entry.value);
    }
    final snapshot = await ref.limit(1).get();
    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    data['_id'] = doc.id;
    return _fromMap(data);
  }

  /// Finds a document by its Firestore ID.
  Future<T?> findById(String id) async {
    return findOne({'_id': id});
  }

  /// Returns all documents matching [query], optionally sorted.
  Future<List<T>> find([
    Map<String, dynamic> query = const {},
    Map<String, String> sortOptions = const {},
  ]) async {
    if (!FirebaseConfig.isInitialized) {
      return _memFind(query);
    }

    var ref = FirebaseConfig.db!.collection(collectionName)
        as Query<Map<String, dynamic>>;
    for (final entry in query.entries) {
      ref = ref.where(entry.key, WhereFilter.equal, entry.value);
    }
    for (final entry in sortOptions.entries) {
      ref = ref.orderBy(entry.key,
          descending: entry.value == 'desc');
    }
    final snapshot = await ref.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['_id'] = doc.id;
      return _fromMap(data);
    }).toList();
  }

  /// Creates a new document. If '_id' is provided in [data], uses it as the document ID.
  Future<T> create(Map<String, dynamic> data) async {
    final now = DateTime.now().toIso8601String();
    data['createdAt'] = now;
    data['updatedAt'] = now;

    if (!FirebaseConfig.isInitialized) {
      return _memCreate(data);
    }

    if (data.containsKey('_id') && data['_id'] != null) {
      final id = data['_id'] as String;
      // Exclude _id from the firestore payload, but keep it in the data map for _fromMap later
      final payload = Map<String, dynamic>.from(data)..remove('_id');
      await FirebaseConfig.db!.collection(collectionName).doc(id).set(payload);
    } else {
      final payload = Map<String, dynamic>.from(data)..remove('_id');
      final docRef = await FirebaseConfig.db!.collection(collectionName).add(payload);
      data['_id'] = docRef.id;
    }
    
    return _fromMap(data);
  }

  /// Deletes all documents matching [query].
  Future<void> deleteMany(Map<String, dynamic> query) async {
    if (!FirebaseConfig.isInitialized) {
      _memDeleteMany(query);
      return;
    }

    var ref = FirebaseConfig.db!.collection(collectionName)
        as Query<Map<String, dynamic>>;
    for (final entry in query.entries) {
      ref = ref.where(entry.key, WhereFilter.equal, entry.value);
    }
    final snapshot = await ref.get();
    for (final doc in snapshot.docs) {
      await doc.ref.delete();
    }
  }

  // ─── In-Memory Implementations ─────────────────────────────────────

  T? _memFindOne(Map<String, dynamic> query) {
    final col = _getMemoryCollection(collectionName);

    if (query.containsKey('_id')) {
      final doc = col[query['_id']];
      if (doc == null) return null;
      return _fromMap({...doc, '_id': query['_id']});
    }

    for (final entry in col.entries) {
      bool match = true;
      for (final q in query.entries) {
        if (entry.value[q.key] != q.value) {
          match = false;
          break;
        }
      }
      if (match) return _fromMap({...entry.value, '_id': entry.key});
    }
    return null;
  }

  List<T> _memFind(Map<String, dynamic> query) {
    final col = _getMemoryCollection(collectionName);
    final results = <T>[];

    for (final entry in col.entries) {
      bool match = true;
      for (final q in query.entries) {
        final docValue = entry.value[q.key];
        final effective =
            (docValue == null && q.value is bool) ? false : docValue;
        if (effective != q.value) {
          match = false;
          break;
        }
      }
      if (match) results.add(_fromMap({...entry.value, '_id': entry.key}));
    }
    return results;
  }

  T _memCreate(Map<String, dynamic> data) {
    final col = _getMemoryCollection(collectionName);
    final id = (data['_id'] as String?) ?? _uuid.v4();
    data['_id'] = id;
    col[id] = Map<String, dynamic>.from(data);
    _saveToDisk();
    return _fromMap(data);
  }

  void _memDeleteMany(Map<String, dynamic> query) {
    final col = _getMemoryCollection(collectionName);
    final toRemove = <String>[];
    for (final entry in col.entries) {
      bool match = true;
      for (final q in query.entries) {
        if (entry.value[q.key] != q.value) {
          match = false;
          break;
        }
      }
      if (match) toRemove.add(entry.key);
    }
    for (final k in toRemove) {
      col.remove(k);
    }
    if (toRemove.isNotEmpty) _saveToDisk();
  }
}
