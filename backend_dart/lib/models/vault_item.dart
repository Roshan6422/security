import 'firestore_model.dart';

/// A vault item (file, photo, note, etc.) belonging to a user.
class VaultItem extends FirestoreModel {
  String user;
  String name;
  String type;
  String size;
  String? url;
  String? storagePath;
  String? content;
  bool isDeleted;
  DateTime? deletedAt;

  VaultItem({
    this.user = '',
    this.name = '',
    this.type = 'document',
    this.size = '0 B',
    this.url,
    this.storagePath,
    this.content,
    this.isDeleted = false,
    this.deletedAt,
  });

  @override
  String get collectionName => 'vaultItems';

  @override
  Map<String, dynamic> toMap() => {
        'user': user,
        'name': name,
        'type': type,
        'size': size,
        'url': url,
        'storagePath': storagePath,
        'content': content,
        'isDeleted': isDeleted,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  /// Creates a [VaultItem] from a Firestore document map.
  factory VaultItem.fromMap(Map<String, dynamic> map) {
    final item = VaultItem(
      user: map['user'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'document',
      size: map['size'] as String? ?? '0 B',
      url: map['url'] as String?,
      storagePath: map['storagePath'] as String?,
      content: map['content'] as String?,
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: FirestoreModel.parseDate(map['deletedAt']),
    );
    item.populateFromMap(map);
    return item;
  }
}

/// Global repository for [VaultItem] documents.
final vaultItemRepo =
    ModelRepository<VaultItem>('vaultItems', VaultItem.fromMap);
