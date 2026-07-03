/// Mixin for entities that can be synced between local and remote storage.
///
/// Each syncable entity must provide a unique [syncId] and a [syncTimestamp]
/// that represents when the entity was last modified.
mixin Syncable {
  /// Unique identifier for this entity.
  ///
  /// For simple entities, this is typically the primary key (e.g., `id`).
  /// For composite-key entities, this should be a concatenation like
  /// `"$choirId:$userId"`.
  String get syncId;

  /// Timestamp of the last modification to this entity.
  ///
  /// Used to determine which version wins during bidirectional sync.
  /// The newest timestamp wins.
  DateTime get syncTimestamp;

  /// Whether this entity is soft-deleted (a tombstone).
  ///
  /// Tombstones sync like any other change: the newest timestamp wins, so a
  /// deletion can be overridden by a newer edit and vice versa. Deletion is
  /// never inferred from a row being absent on either side.
  bool get isDeleted;
}
