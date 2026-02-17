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
}
