# Sync Architecture

This document describes how synchronization works in Repertoire Coach, including runtime triggers, algorithm details, entity ordering, and data movement between Flutter, local storage, and Supabase.

## Scope
- Bidirectional entity sync between local Drift DB and Supabase.
- How sync is triggered and observed in app state.
- Why entity order matters for foreign keys.

## High-Level Flow

```mermaid
flowchart LR
  UI[Flutter UI] --> Providers[Riverpod Providers]
  Providers --> SyncController[SyncController]
  SyncController --> SyncService[SyncService]
  SyncService --> SyncAlgorithm[SyncAlgorithm]

  SyncAlgorithm --> LocalDS[Local Data Sources<br/>Drift SQLite/sql.js]
  SyncAlgorithm --> RemoteDS[Remote Data Sources<br/>Supabase PostgREST]

  LocalDS --> LocalDB[(Local DB)]
  RemoteDS --> Supabase[(Supabase Postgres)]
```

## Trigger Points

Sync starts from one of two paths:
- Automatic trigger after sign-in (`authSyncTriggerProvider`)
- Manual trigger from UI (choir list refresh/sync action)

```mermaid
sequenceDiagram
  autonumber
  participant U as User
  participant A as Auth State
  participant P as authSyncTriggerProvider
  participant C as SyncController
  participant S as SyncService

  U->>A: Sign in
  A-->>P: currentUser != null
  P->>C: syncFromRemote() (async)
  C->>S: syncFromRemote(userId)
  S-->>C: Progress updates per entity
  C-->>P: SyncState.success | SyncState.error
```

## Sync State Machine

```mermaid
stateDiagram-v2
  [*] --> idle
  idle --> syncing: syncFromRemote()
  syncing --> success: all steps complete
  syncing --> error: exception
  success --> idle: resetState()
  error --> idle: resetState()
```

## Entity Order

`SyncService` runs entities in this strict order to respect dependencies:

1. choirs
2. choir_members
3. concerts
4. songs
5. tracks
6. marker_sets
7. markers
8. favorites

```mermaid
flowchart TD
  choirs --> choir_members --> concerts --> songs --> tracks --> marker_sets --> markers --> favorites
```

Why this order:
- `concerts` depend on `choirs`
- `songs` depend on `concerts`
- `tracks` depend on `songs`
- `marker_sets` depend on `tracks`
- `markers` depend on `marker_sets`
- `favorites` depend on `tracks` and `songs`

## Generic Algorithm (Push-Before-Pull)

The core algorithm is implemented in `lib/core/sync/sync_algorithm.dart`.

```mermaid
flowchart TD
  A[Load unsyncedLocal, syncedLocal, allRemote] --> B[Build remoteById map]
  B --> C{For each unsynced local item}

  C -->|locally deleted| D[deleteOnRemote if exists]
  D --> E[markSynced]

  C -->|missing remotely| F[createOnRemote]
  F --> G[markSynced]

  C -->|exists both| H{local newer?}
  H -->|yes| I[updateOnRemote]
  I --> J[markSynced]
  H -->|no| K[upsertLocal from remote]
  K --> L[markSynced]

  E --> M[hardDeleteSyncedDeleted]
  G --> M
  J --> M
  L --> M

  M --> N[Pull phase: upsert remote items not handled in push]
  N --> O[hardDeleteSyncedNotIn remoteIds]
  O --> P[SyncResult]
```

## Decision Table

```mermaid
flowchart LR
  X[Unsynced local item] --> Y{Is soft-deleted?}
  Y -->|Yes| Y1[Delete remote if present + mark synced]
  Y -->|No| Z{Exists remotely?}
  Z -->|No| Z1[Create remote + mark synced]
  Z -->|Yes| W{local.updatedAt > remote.updatedAt?}
  W -->|Yes| W1[Update remote + mark synced]
  W -->|No| W2[Upsert remote copy locally + mark synced]
```

## Data Flow for Local Writes

Repositories write locally first and mark records for sync. The sync layer is responsible for remote propagation.

```mermaid
sequenceDiagram
  autonumber
  participant UI as UI Action
  participant Repo as Repository
  participant LDS as Local Data Source
  participant DB as Local DB
  participant Sync as SyncService
  participant RDS as Remote Data Source
  participant SB as Supabase

  UI->>Repo: create/update/delete entity
  Repo->>LDS: write(markForSync: true)
  LDS->>DB: persist + synced=false
  Note over DB: record is now visible locally

  Sync->>LDS: getUnsynced*
  Sync->>RDS: create/update/delete remote
  RDS->>SB: PostgREST request
  Sync->>LDS: markSynced / cleanup
  LDS->>DB: synced=true or hard-delete
```

## Adapter Responsibilities

Each sync adapter maps the generic algorithm to one entity type.

```mermaid
classDiagram
  class SyncAdapter {
    <<interface>>
    +getUnsyncedLocal()
    +getSyncedLocal()
    +getAllRemote()
    +isLocallyDeleted(item)
    +createOnRemote(item)
    +updateOnRemote(item)
    +deleteOnRemote(id)
    +upsertLocal(item)
    +markSynced(id)
    +hardDeleteSyncedDeleted()
    +hardDeleteSyncedNotIn(ids)
  }

  class ChoirSyncAdapter
  class SongSyncAdapter
  class TrackSyncAdapter
  class MarkerSetSyncAdapter
  class MarkerSyncAdapter
  class FavoriteTrackSyncAdapter

  SyncAdapter <|.. ChoirSyncAdapter
  SyncAdapter <|.. SongSyncAdapter
  SyncAdapter <|.. TrackSyncAdapter
  SyncAdapter <|.. MarkerSetSyncAdapter
  SyncAdapter <|.. MarkerSyncAdapter
  SyncAdapter <|.. FavoriteTrackSyncAdapter
```

## Error Handling and Retry Behavior
- Per-item push errors are counted and logged; sync continues with other items.
- Failed items remain unsynced and are retried in the next sync cycle.
- Fatal errors abort the current entity sync and set sync state to `error`.

## Notes on Consistency
- Sync is eventual, not transactional across all entities.
- UI can show partially synced data while sync is in progress.
- Provider invalidation after successful sync refreshes key screens.

## File Map
- `lib/core/services/sync_service.dart`
- `lib/core/sync/sync_algorithm.dart`
- `lib/core/sync/adapters/*`
- `lib/presentation/providers/sync_provider.dart`
