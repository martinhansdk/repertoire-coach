# Testing Guidelines for Repertoire Coach

This document provides comprehensive testing standards and best practices for the Repertoire Coach project.

**Last Updated**: 2025-12-05
**Current Coverage**: 56.3% (381 passing tests, 21 skipped)

## Table of Contents

1. [Testing Strategy Overview](#testing-strategy-overview)
2. [Test Organization](#test-organization)
3. [Testing Standards by Layer](#testing-standards-by-layer)
4. [Test Patterns and Best Practices](#test-patterns-and-best-practices)
5. [Common Pitfalls to Avoid](#common-pitfalls-to-avoid)
6. [Test Utilities](#test-utilities)
7. [Coverage Goals](#coverage-goals)
8. [Running Tests](#running-tests)
9. [Test Checklist for New Features](#test-checklist-for-new-features)

---

## Testing Strategy Overview

### Test Pyramid

Follow the test pyramid distribution:
- **60% Unit Tests**: Fast, isolated tests of business logic
- **30% Widget Tests**: UI component tests with mocked dependencies
- **10% Integration Tests**: End-to-end user workflows

### Why This Matters

- **Unit tests** are fast and pinpoint issues quickly
- **Widget tests** verify UI behavior without full app overhead
- **Integration tests** validate complete user workflows but are slower

### Current State vs Goals

| Layer | Current | Goal | Status |
|-------|---------|------|--------|
| Domain Entities | 100% | 100% | ✅ **DONE** |
| Data Models | ~80% | 90% | ⚠️ Good progress |
| Repositories | ~70% | 90% | ⚠️ Needs improvement |
| Data Sources | ~50% | 100% | ⚠️ Critical gap |
| Providers | ~80% | 100% | ⚠️ Good progress |
| Screens | ~50% | 80% | ⚠️ Moderate coverage |
| Widgets | ~60% | 70% | ⚠️ Close to goal |

**Overall: 56.3% line coverage** - Solid improvement from 42%, but room to grow!

---

## Test Organization

### Directory Structure

```
test/
├── domain/
│   ├── entities/          # Entity business logic tests
│   └── usecases/          # Use case tests (future)
├── data/
│   ├── models/            # Serialization/conversion tests
│   ├── repositories/      # Repository implementation tests
│   └── datasources/       # Data source tests
├── presentation/
│   ├── providers/         # Provider tests
│   ├── screens/           # Screen widget tests
│   └── widgets/           # Reusable widget tests
├── integration/           # End-to-end workflow tests
└── helpers/               # Shared test utilities
    ├── test_fixtures.dart
    ├── test_database_helper.dart
    └── test_widget_wrapper.dart
```

### File Naming Conventions

- Test files: `{feature_name}_test.dart`
- Match source file names: `song.dart` → `song_test.dart`
- Integration tests: `{workflow}_integration_test.dart`

---

## Testing Standards by Layer

### 1. Domain Layer (Entities)

**Coverage Goal**: 100%

**What to Test**:
- Business logic methods
- Validation rules
- Edge cases and boundary conditions
- Equality and hash code (if using Equatable)

**What NOT to Test**:
- Simple property getters
- Generated Equatable code (props list)
- toString methods (unless custom logic)

**Example**:
```dart
// Test business logic in Concert entity
test('isConcluded returns true for past concerts', () {
  final concert = Concert(
    id: 'c1',
    name: 'Past Concert',
    date: DateTime.now().subtract(Duration(days: 1)),
  );

  expect(concert.isConcluded, isTrue);
});

test('isConcluded returns false for future concerts', () {
  final concert = Concert(
    id: 'c1',
    name: 'Future Concert',
    date: DateTime.now().add(Duration(days: 1)),
  );

  expect(concert.isConcluded, isFalse);
});
```

**Pattern**: AAA (Arrange-Act-Assert)
```dart
test('description of behavior', () {
  // Arrange: Set up test data
  final entity = Entity(...);

  // Act: Execute the behavior
  final result = entity.someMethod();

  // Assert: Verify the outcome
  expect(result, expectedValue);
});
```

---

### 2. Data Layer

#### 2a. Models

**Coverage Goal**: 100%

**What to Test**:
- JSON serialization (toJson)
- JSON deserialization (fromJson)
- Entity conversion (toEntity, fromEntity)
- Edge cases (null values, missing fields)

**Example**:
```dart
group('SongModel', () {
  test('fromJson creates valid model', () {
    final json = {
      'id': 's1',
      'title': 'Test Song',
      'concert_id': 'c1',
      'created_at': '2025-11-27T12:00:00Z',
    };

    final model = SongModel.fromJson(json);

    expect(model.id, 's1');
    expect(model.title, 'Test Song');
    expect(model.concertId, 'c1');
  });

  test('toJson produces correct JSON', () {
    final model = SongModel(
      id: 's1',
      title: 'Test Song',
      concertId: 'c1',
    );

    final json = model.toJson();

    expect(json['id'], 's1');
    expect(json['title'], 'Test Song');
    expect(json['concert_id'], 'c1');
  });

  test('toEntity converts to domain entity', () {
    final model = SongModel(id: 's1', title: 'Test Song');
    final entity = model.toEntity();

    expect(entity, isA<Song>());
    expect(entity.id, 's1');
    expect(entity.title, 'Test Song');
  });
});
```

#### 2b. Data Sources

**Coverage Goal**: 100%

**What to Test**:
- CRUD operations (create, read, update, delete)
- Soft delete operations
- Sync state management
- Query filtering and sorting
- Stream behavior
- Error handling

**Example**:
```dart
group('LocalSongDataSource', () {
  late AppDatabase database;
  late LocalSongDataSource dataSource;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    dataSource = LocalSongDataSource(database);
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase(database);
  });

  test('createSong inserts song into database', () async {
    final song = SongModel(id: 's1', title: 'Test Song');

    await dataSource.createSong(song);

    final retrieved = await dataSource.getSong('s1');
    expect(retrieved, isNotNull);
    expect(retrieved!.title, 'Test Song');
  });
});
```

#### 2c. Repositories

**Coverage Goal**: 90%

**What to Test**:
- All public methods
- Business logic in repository layer
- Error handling and edge cases
- Sorting/filtering logic
- Stream transformations

**Example**:
```dart
group('SongRepositoryImpl', () {
  late AppDatabase database;
  late SongRepositoryImpl repository;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    repository = SongRepositoryImpl(LocalSongDataSource(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('getSongsForConcert returns songs sorted chronologically', () async {
    // Arrange: Create songs with different order values
    await repository.createSong(Song(id: 's1', concertId: 'c1', order: 2));
    await repository.createSong(Song(id: 's2', concertId: 'c1', order: 1));
    await repository.createSong(Song(id: 's3', concertId: 'c1', order: 3));

    // Act: Retrieve songs
    final songs = await repository.getSongsForConcert('c1');

    // Assert: Verify sorting
    expect(songs[0].id, 's2'); // order: 1
    expect(songs[1].id, 's1'); // order: 2
    expect(songs[2].id, 's3'); // order: 3
  });
});
```

---

### 3. Presentation Layer

#### 3a. Providers

**Coverage Goal**: 100%

**What to Test**:
- Provider initialization
- Dependency injection
- Async data loading
- State updates
- Disposal/cleanup

**Example**:
```dart
group('ConcertProvider', () {
  test('concertListProvider loads concerts from repository', () async {
    final mockRepository = MockConcertRepository();
    final concerts = [
      Concert(id: 'c1', name: 'Concert 1'),
      Concert(id: 'c2', name: 'Concert 2'),
    ];
    when(mockRepository.getAllConcerts()).thenAnswer((_) async => concerts);

    final container = ProviderContainer(
      overrides: [
        concertRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );

    final asyncConcerts = await container.read(concertsProvider.future);

    expect(asyncConcerts, hasLength(2));
    expect(asyncConcerts[0].name, 'Concert 1');
  });

  test('concertListProvider handles errors gracefully', () async {
    final mockRepository = MockConcertRepository();
    when(mockRepository.getAllConcerts()).thenThrow(Exception('DB error'));

    final container = ProviderContainer(
      overrides: [
        concertRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );

    final asyncValue = container.read(concertsProvider);

    await expectLater(
      asyncValue.future,
      throwsA(isA<Exception>()),
    );
  });
});
```

#### 3b. Screens

**Coverage Goal**: 80%

**What to Test**:
- Widget builds successfully
- Loading states
- Error states
- Empty states
- User interactions (taps, scrolls)
- Navigation
- Data display

**Example**:
```dart
group('ConcertListScreen', () {
  testWidgets('shows loading indicator while loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertsProvider.overrideWith(
            (ref) => const AsyncValue.loading(),
          ),
        ],
        child: MaterialApp(home: ConcertListScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('displays concerts when loaded', (tester) async {
    final concerts = [
      Concert(id: 'c1', name: 'Spring Concert'),
      Concert(id: 'c2', name: 'Winter Concert'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertsProvider.overrideWith(
            (ref) => AsyncValue.data(concerts),
          ),
        ],
        child: MaterialApp(home: ConcertListScreen()),
      ),
    );

    expect(find.text('Spring Concert'), findsOneWidget);
    expect(find.text('Winter Concert'), findsOneWidget);
  });

  testWidgets('navigates to detail screen when concert tapped', (tester) async {
    final concerts = [Concert(id: 'c1', name: 'Spring Concert')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertsProvider.overrideWith(
            (ref) => AsyncValue.data(concerts),
          ),
        ],
        child: MaterialApp(
          home: ConcertListScreen(),
          routes: {
            '/concert-detail': (_) => Scaffold(body: Text('Detail Screen')),
          },
        ),
      ),
    );

    await tester.tap(find.text('Spring Concert'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Screen'), findsOneWidget);
  });
});
```

#### 3c. Widgets

**Coverage Goal**: 70%

**What to Test**:
- Widget renders correctly with different data
- Callbacks are invoked properly
- Conditional rendering
- Edge cases (null values, empty lists)

**Example**:
```dart
group('TrackListTile', () {
  testWidgets('displays track information', (tester) async {
    final track = Track(
      id: 't1',
      name: 'Soprano',
      audioFile: '/path/to/audio.mp3',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackListTile(track: track, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Soprano'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (tester) async {
    var tapped = false;
    final track = Track(id: 't1', name: 'Soprano');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackListTile(
            track: track,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TrackListTile));

    expect(tapped, isTrue);
  });
});
```

---

## Test Patterns and Best Practices

### 1. AAA Pattern (Arrange-Act-Assert)

Always structure tests in three clear sections:

```dart
test('description', () {
  // Arrange: Set up test data and dependencies
  final entity = Entity(id: '1', name: 'Test');
  final repository = MockRepository();

  // Act: Execute the behavior being tested
  final result = entity.someMethod();

  // Assert: Verify the outcome
  expect(result, expectedValue);
});
```

### 2. Use Descriptive Test Names

```dart
// ❌ Bad: Vague test name
test('concert test', () { ... });

// ✅ Good: Descriptive test name
test('isConcluded returns true for concerts with past dates', () { ... });
```

### 3. Test One Thing Per Test

```dart
// ❌ Bad: Testing multiple behaviors
test('concert operations', () {
  final concert = Concert(...);
  expect(concert.isConcluded, isFalse);
  expect(concert.isUpcoming, isTrue);
  expect(concert.formattedDate, '2025-04-15');
});

// ✅ Good: Separate tests for each behavior
test('isConcluded returns false for future concerts', () { ... });
test('isUpcoming returns true for future concerts', () { ... });
test('formattedDate returns correctly formatted date', () { ... });
```

### 4. Use Test Groups for Organization

```dart
group('Concert', () {
  group('date logic', () {
    test('isConcluded returns true for past concerts', () { ... });
    test('isConcluded returns false for future concerts', () { ... });
  });

  group('equality', () {
    test('concerts with same ID are equal', () { ... });
    test('concerts with different IDs are not equal', () { ... });
  });
});
```

### 5. Use setUp and tearDown for Common Setup

```dart
group('SongRepository', () {
  late AppDatabase database;
  late SongRepository repository;

  setUp(() async {
    database = TestDatabaseHelper.createTestDatabase();
    repository = SongRepositoryImpl(LocalSongDataSource(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('createSong adds song to database', () async { ... });
  test('deleteSong removes song from database', () async { ... });
});
```

### 6. Use In-Memory Databases for Data Layer Tests

```dart
// ✅ Good: Use in-memory database for Drift
setUp(() async {
  database = TestDatabaseHelper.createTestDatabase();
});

tearDown(() async {
  await database.close();
});
```

### 7. Mock External Dependencies

```dart
// For providers, mock repository dependencies
final container = ProviderContainer(
  overrides: [
    songRepositoryProvider.overrideWithValue(mockRepository),
  ],
);

// For widgets, override providers
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      songListProvider.overrideWith((ref) => AsyncValue.data(songs)),
    ],
    child: MaterialApp(home: SongListScreen()),
  ),
);
```

### 8. Test Edge Cases and Error Conditions

```dart
test('fromJson handles missing optional fields', () {
  final json = {'id': 's1', 'title': 'Song'}; // Missing optional fields
  final model = SongModel.fromJson(json);
  expect(model.id, 's1');
});

test('getSong returns null for non-existent ID', () async {
  final song = await dataSource.getSong('non-existent');
  expect(song, isNull);
});

test('createSong throws exception on duplicate ID', () async {
  await dataSource.createSong(SongModel(id: 's1', title: 'Song'));

  expect(
    () => dataSource.createSong(SongModel(id: 's1', title: 'Song')),
    throwsA(isA<Exception>()),
  );
});
```

### 9. Use Independent Test Data

```dart
// ❌ Bad: Shared mutable state
final sharedSong = Song(id: 's1', title: 'Shared');

test('test 1', () {
  sharedSong.title = 'Modified'; // Mutates shared state
});

test('test 2', () {
  expect(sharedSong.title, 'Shared'); // FAILS! Title was modified
});

// ✅ Good: Independent test data
test('test 1', () {
  final song = Song(id: 's1', title: 'Test 1');
  song.title = 'Modified';
});

test('test 2', () {
  final song = Song(id: 's1', title: 'Test 2');
  expect(song.title, 'Test 2');
});
```

### 10. Test Async Code Properly

```dart
// ✅ Use async/await
test('async method returns expected value', () async {
  final result = await repository.getSong('s1');
  expect(result, isNotNull);
});

// ✅ Use expectLater for streams
test('stream emits expected values', () {
  final stream = repository.watchSongs();

  expectLater(
    stream,
    emitsInOrder([
      hasLength(0),
      hasLength(1),
      hasLength(2),
    ]),
  );
});
```

---

## Common Pitfalls to Avoid

### 1. Testing Implementation Details

```dart
// ❌ Bad: Testing private implementation
test('_internalMethod does something', () { ... });

// ✅ Good: Test public behavior
test('publicMethod returns expected result', () { ... });
```

### 2. Over-Mocking

```dart
// ❌ Bad: Mocking entities (value objects)
final mockSong = MockSong();
when(mockSong.title).thenReturn('Test');

// ✅ Good: Use real entities, mock services
final song = Song(id: 's1', title: 'Test');
final mockRepository = MockSongRepository();
```

### 3. Testing Generated Code

```dart
// ❌ Bad: Testing Equatable-generated code
test('props includes all properties', () {
  final song = Song(id: 's1');
  expect(song.props, [song.id, song.title, ...]);
});

// ✅ Good: Test actual equality behavior if custom logic
test('songs with same ID are equal', () {
  final song1 = Song(id: 's1', title: 'A');
  final song2 = Song(id: 's1', title: 'B');
  expect(song1, equals(song2));
});
```

### 4. Brittle Tests (Too Specific)

```dart
// ❌ Bad: Testing exact string formatting
test('concert toString returns exact format', () {
  final concert = Concert(name: 'Spring Concert', date: DateTime(2025, 4, 15));
  expect(concert.toString(), 'Concert(name: Spring Concert, date: 2025-04-15)');
});

// ✅ Good: Test behavior, not formatting
test('concert toString includes name and date', () {
  final concert = Concert(name: 'Spring Concert', date: DateTime(2025, 4, 15));
  final str = concert.toString();
  expect(str, contains('Spring Concert'));
  expect(str, contains('2025-04-15'));
});
```

### 5. Not Cleaning Up Resources

```dart
// ❌ Bad: Not closing database
test('some test', () async {
  final database = TestDatabaseHelper.createTestDatabase();
  // ... test code ...
  // Database not closed - resource leak!
});

// ✅ Good: Use tearDown to clean up
late AppDatabase database;

setUp(() async {
  database = TestDatabaseHelper.createTestDatabase();
});

tearDown(() async {
  await database.close();
});
```

### 6. Skipping Tests Without Documentation

```dart
// ❌ Bad: Skip without explanation
skip: true,

// ✅ Good: Document why test is skipped
skip: 'Requires platform-specific audio player - tracked in issue #123',
```

---

## Test Utilities

### Recommended Test Helpers

#### 1. test/helpers/test_fixtures.dart

Create shared test data to reduce duplication:

```dart
// Shared test data
class TestFixtures {
  static Concert springConcert({String? id}) => Concert(
    id: id ?? 'c1',
    name: 'Spring Concert 2025',
    date: DateTime(2025, 4, 15),
  );

  static Song testSong({String? id, String? concertId}) => Song(
    id: id ?? 's1',
    title: 'Test Song',
    concertId: concertId ?? 'c1',
  );

  static Track sopranoTrack({String? id, String? songId}) => Track(
    id: id ?? 't1',
    name: 'Soprano',
    songId: songId ?? 's1',
    audioFile: '/test/audio.mp3',
  );
}
```

#### 2. test/helpers/test_database_helper.dart

Simplify database setup:

```dart
class TestDatabaseHelper {
  static AppDatabase createTestDatabase() {
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  static Future<void> closeTestDatabase(AppDatabase db) async {
    await db.close();
  }

  static Future<void> seedConcerts(AppDatabase db, List<Concert> concerts) async {
    for (final concert in concerts) {
      await db.into(db.concerts).insert(
        ConcertsCompanion.insert(
          // ...
        ),
      );
    }
  }
}
```

#### 3. test/helpers/test_widget_wrapper.dart

Simplify widget test setup:

```dart
class TestWidgetWrapper {
  static Widget wrapWithMaterialApp(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );
  }

  static Widget wrapWithScaffold(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return wrapWithMaterialApp(
      Scaffold(body: child),
      overrides: overrides,
    );
  }
}
```

---

## Coverage Goals

### Overall Goals

- **Minimum**: 80% line coverage
- **Target**: 90% line coverage for critical paths
- **Domain entities**: 100%
- **Repositories**: 90%+
- **Providers**: 100%
- **Screens**: 80%+

### Layer-Specific Goals

| Layer | Coverage Goal | Rationale |
|-------|--------------|-----------|
| Domain Entities | 100% | Core business logic - must be bulletproof |
| Data Models | 100% | Serialization errors cause data corruption |
| Repositories | 90% | Critical data operations |
| Data Sources | 80% | Database layer - high risk |
| Providers | 100% | State management - affects entire app |
| Screens | 80% | User-facing - high visibility |
| Widgets | 70% | Reusable components |

### What NOT to Count Toward Coverage

- Generated code (build_runner output)
- Simple property getters
- toString methods (unless custom logic)
- Equatable props lists

---

## Running Tests

### Using Docker (Recommended)

**Run all tests:**
```bash
scripts/test.sh
```

**Run specific tests:**
```bash
scripts/test.sh test/path/to/your_test.dart
```

**Run with verbose output:**
```bash
scripts/test.sh --verbose
```

**Run analyze + test:**
```bash
scripts/validate.sh
```

### Generate Coverage Report

**Recommended: Use the coverage script (includes summary):**
```bash
scripts/coverage.sh
```

This will:
- Run all tests with coverage enabled
- Generate `coverage/lcov.info` report
- Display coverage percentage summary
- Save detailed log to `logs/coverage-*.log`

**Alternative: Manual coverage generation:**
```bash
scripts/test.sh --coverage

# View coverage in browser (requires lcov)
# On macOS: open coverage/html/index.html
# On Linux: xdg-open coverage/html/index.html
genhtml coverage/lcov.info -o coverage/html
```

### Coverage in CI/CD

Coverage is **automatically generated** and displayed in GitHub Actions:

1. Every push/PR triggers the `coverage` job
2. Coverage summary appears in the workflow summary:
   - Coverage percentage with visual indicator
   - Lines covered (e.g., 1,234 / 1,543)
   - Test counts (passing/skipped)
   - Quality badge: ✅ ≥80% | ⚠️ 60-80% | ❌ <60%
3. Coverage report uploaded as artifact (30-day retention)

**View CI coverage:**
- Go to any workflow run on GitHub
- Click "Summary" tab
- See "📊 Test Coverage Report" section

**Download coverage report:**
- Go to workflow run → Artifacts
- Download `coverage-report.zip`
- Extract and view `lcov.info`

### Watch Mode (For Development)

```bash
# Not available in Docker - use local Flutter if installed
flutter test --watch
```

---

## Test Checklist for New Features

When implementing a new feature, ensure:

### Domain Layer
- [ ] Entity class created with business logic
- [ ] All entity methods have unit tests
- [ ] Edge cases tested (null, empty, boundary values)
- [ ] Equality and hash code tested (if applicable)

### Data Layer
- [ ] Model class created with serialization
- [ ] `fromJson` and `toJson` tested
- [ ] `toEntity` and `fromEntity` tested
- [ ] Data source created with CRUD operations
- [ ] All data source methods tested with in-memory database
- [ ] Repository implementation created
- [ ] All repository methods tested
- [ ] Sorting/filtering logic tested

### Presentation Layer
- [ ] Provider created for state management
- [ ] Provider initialization tested
- [ ] Provider error handling tested
- [ ] Screen widget created
- [ ] Screen loading state tested
- [ ] Screen error state tested
- [ ] Screen empty state tested
- [ ] Screen data display tested
- [ ] User interactions tested (taps, navigation)
- [ ] Reusable widgets tested

### Integration
- [ ] End-to-end user workflow tested
- [ ] Error recovery tested
- [ ] Concurrent operations tested (if applicable)

### Pre-Commit
- [ ] `scripts/validate.sh` passes (analyze + test)
- [ ] No skipped tests (or documented why)
- [ ] Coverage meets layer-specific goals

---

## Summary

### Key Principles

1. **Write tests first** (TDD) or immediately after implementation
2. **Follow the test pyramid** (60% unit, 30% widget, 10% integration)
3. **Use AAA pattern** (Arrange-Act-Assert)
4. **Test behavior, not implementation**
5. **Use in-memory databases** for data layer
6. **Mock external dependencies** only
7. **Create independent test data**
8. **Clean up resources** in tearDown
9. **Validate before committing** (scripts/validate.sh)

### Critical Gaps to Address

1.  **Screen Tests**: Coverage is low (33%). Focus on adding widget tests for all screens.
2.  **Skipped Tests**: 2 tests related to native functionality (`just_audio` and `path_provider`) are still skipped. These should be addressed with a more robust testing strategy for platform-specific code.

### Next Steps

1.  Increase screen test coverage to 80%.
2.  Implement a strategy for testing platform-specific code (e.g., using fakes or integration tests on real devices).
3.  Continue to write tests for all new features.

---

**For detailed implementation roadmap, see TODO.md**

**For project-specific context, see CLAUDE.md**