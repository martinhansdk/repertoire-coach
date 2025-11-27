# Testing Guidelines for Repertoire Coach

This document provides comprehensive guidelines for writing and maintaining tests in the Repertoire Coach project.

## Table of Contents

1. [Testing Strategy Overview](#testing-strategy-overview)
2. [Test Organization](#test-organization)
3. [Testing Standards by Layer](#testing-standards-by-layer)
4. [Test Patterns and Best Practices](#test-patterns-and-best-practices)
5. [Common Pitfalls to Avoid](#common-pitfalls-to-avoid)
6. [Test Utilities and Helpers](#test-utilities-and-helpers)
7. [Coverage Goals](#coverage-goals)
8. [Running Tests](#running-tests)

---

## Testing Strategy Overview

### Test Pyramid

Repertoire Coach follows the test pyramid approach:

```
        /\
       /E2E\      Integration Tests (10%)
      /------\
     /Widget  \   Widget/Screen Tests (30%)
    /----------\
   /   Unit     \ Unit Tests (60%)
  /--------------\
```

**Unit Tests (60%)**: Test individual classes and functions in isolation
- Domain entities
- Data models
- Repository implementations
- Use cases and business logic
- Utility functions

**Widget Tests (30%)**: Test UI components and user interactions
- Individual widgets
- Dialogs and forms
- Screen layouts
- User interactions

**Integration Tests (10%)**: Test complete workflows
- End-to-end user journeys
- Cross-layer interactions
- Database persistence

### Current Status

**Overall Coverage**: 42% of source files tested (28/67 files)

**By Layer**:
- ✅ Domain entities: 91% (10/11 files)
- ⚠️ Data layer: 50% (10/20 files)
- ❌ Presentation layer: 27% (7/26 files)

**Priority Areas** (untested):
1. All 6 provider files (416 lines)
2. All 7 data source files (450+ lines)
3. AudioPlayerScreen (245 lines)
4. 4 major screens (705 lines)
5. 5 model files

---

## Test Organization

### Directory Structure

Tests mirror the `lib/` directory structure:

```
test/
├── data/
│   ├── models/           # Data model tests
│   ├── repositories/     # Repository implementation tests
│   ├── datasources/      # Data source tests (TO BE ADDED)
│   └── services/         # Service tests
├── domain/
│   ├── entities/         # Entity tests
│   └── usecases/         # Use case tests (TO BE ADDED)
├── integration/          # Integration tests
├── presentation/
│   ├── screens/          # Screen tests
│   ├── widgets/          # Widget tests
│   └── providers/        # Provider tests (TO BE ADDED)
├── helpers/              # Test utilities (TO BE ADDED)
└── widget_test.dart      # Smoke test
```

### Naming Conventions

- Test files: `{feature_name}_test.dart`
- Test file location: Mirror source file path
  - Source: `lib/domain/entities/song.dart`
  - Test: `test/domain/entities/song_test.dart`

---

## Testing Standards by Layer

### Domain Layer Testing

#### Entity Tests

**What to Test**:
- Object creation with valid data
- Equality comparison
- Business logic methods (e.g., `Concert.isUpcoming`)
- Edge cases and validation

**What NOT to Test**:
- Simple property getters
- Generated code (e.g., `copyWith`, props)

**Example**:
```dart
// test/domain/entities/concert_test.dart
void main() {
  group('Concert', () {
    test('should correctly identify upcoming concerts', () {
      final concert = Concert(
        id: '1',
        name: 'Spring Concert',
        date: DateTime.now().add(const Duration(days: 7)),
        choirId: 'choir1',
        choirName: 'Test Choir',
      );

      expect(concert.isUpcoming, isTrue);
    });

    test('should correctly identify past concerts', () {
      final concert = Concert(
        id: '1',
        name: 'Winter Concert',
        date: DateTime.now().subtract(const Duration(days: 30)),
        choirId: 'choir1',
        choirName: 'Test Choir',
      );

      expect(concert.isPast, isTrue);
    });
  });
}
```

**Coverage Goal**: 100% of entity classes with business logic

---

### Data Layer Testing

#### Model Tests

**What to Test**:
- Conversion from entity to model (`fromEntity`)
- Conversion from model to entity (`toEntity`)
- Round-trip conversion (entity → model → entity)
- Inheritance relationship
- Edge cases (null handling, optional fields)

**What NOT to Test**:
- Properties already tested in entity tests
- Simple getters

**Example**:
```dart
// test/data/models/song_model_test.dart
void main() {
  group('SongModel', () {
    test('should be a subclass of Song entity', () {
      expect(SongModel.fromEntity(song), isA<Song>());
    });

    test('should convert from entity correctly', () {
      final entity = Song(/* ... */);
      final model = SongModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.title, entity.title);
      // ... verify all properties
    });

    test('should maintain all properties through round-trip conversion', () {
      final original = Song(/* ... */);
      final model = SongModel.fromEntity(original);
      final converted = model.toEntity();

      expect(converted, equals(original));
    });
  });
}
```

**Coverage Goal**: 100% of model classes

#### Repository Tests

**What to Test**:
- All CRUD operations
- Sorting and filtering logic
- Error handling
- Edge cases (not found, empty results)
- Soft delete behavior

**Pattern**: Use in-memory database

**Example**:
```dart
// test/data/repositories/concert_repository_impl_test.dart
void main() {
  late db.AppDatabase database;
  late LocalConcertDataSource dataSource;
  late ConcertRepository repository;

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = LocalConcertDataSource(database);
    repository = ConcertRepositoryImpl(dataSource);
    await _seedTestData(dataSource);
  });

  tearDown(() async {
    await database.close();
  });

  group('Concert Repository', () {
    test('should return concerts sorted by date', () async {
      final concerts = await repository.getConcertsByChoir('choir1');

      // Upcoming concerts first (ascending)
      final upcoming = concerts.where((c) => c.isUpcoming).toList();
      expect(upcoming[0].date.isBefore(upcoming[1].date), isTrue);

      // Past concerts last (descending)
      final past = concerts.where((c) => c.isPast).toList();
      expect(past[0].date.isAfter(past[1].date), isTrue);
    });

    test('should return null for non-existent concert', () async {
      final concert = await repository.getConcertById('nonexistent');
      expect(concert, isNull);
    });
  });
}
```

**Coverage Goal**: 90%+ of repository implementations

#### Data Source Tests (MISSING - HIGH PRIORITY)

**What to Test**:
- All database queries
- Soft delete vs hard delete
- Sync state management
- Stream vs Future operations
- Query filters

**Pattern**: Use in-memory Drift database

**Coverage Goal**: 80%+ of data source implementations

---

### Presentation Layer Testing

#### Provider Tests (MISSING - CRITICAL)

**What to Test**:
- Provider initialization
- Provider dependencies
- Async data loading
- Error states
- Provider disposal

**Pattern**: Use `ProviderContainer` for isolated testing

**Example**:
```dart
// test/presentation/providers/concert_provider_test.dart
void main() {
  group('concertRepositoryProvider', () {
    test('should provide ConcertRepository instance', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(
            db.AppDatabase.forTesting(NativeDatabase.memory()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(concertRepositoryProvider);

      expect(repository, isNotNull);
      expect(repository, isA<ConcertRepository>());
    });
  });
}
```

**Coverage Goal**: 100% of provider files

#### Screen Tests

**What to Test**:
- Loading state display
- Empty state display
- Error state display
- Data display
- User interactions
- Navigation

**Pattern**: Use `ProviderScope` with overrides

**Example**:
```dart
// test/presentation/screens/concert_list_screen_test.dart
void main() {
  testWidgets('should display loading indicator while loading', (tester) async {
    final repository = MockConcertRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ConcertListScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should display concerts when loaded', (tester) async {
    final repository = MockConcertRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          concertRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ConcertListScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Spring Concert'), findsOneWidget);
    expect(find.text('Summer Concert'), findsOneWidget);
  });
}
```

**Coverage Goal**: 80%+ of screens

#### Widget Tests

**What to Test**:
- Widget rendering
- Property display
- User interactions (taps, text entry)
- Callbacks
- Conditional rendering

**Pattern**: Wrap in `MaterialApp` or `Scaffold`

**Example**:
```dart
// test/presentation/widgets/concert_card_test.dart
void main() {
  testWidgets('should display concert information', (tester) async {
    final concert = Concert(
      id: '1',
      name: 'Spring Concert',
      date: DateTime(2025, 4, 15),
      choirId: 'choir1',
      choirName: 'Test Choir',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcertCard(
            concert: concert,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Spring Concert'), findsOneWidget);
    expect(find.text('Test Choir'), findsOneWidget);
  });

  testWidgets('should call onTap when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConcertCard(
            concert: concert,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ConcertCard));
    expect(tapped, isTrue);
  });
}
```

**Coverage Goal**: 70%+ of widgets

---

### Integration Testing

**What to Test**:
- Complete user workflows
- Cross-layer interactions
- Data persistence across operations
- Concurrent operations

**Example**:
```dart
// test/integration/song_crud_integration_test.dart
void main() {
  group('Song CRUD Integration Test', () {
    late db.AppDatabase database;
    late LocalSongDataSource dataSource;
    late SongRepository repository;

    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = LocalSongDataSource(database);
      repository = SongRepositoryImpl(dataSource);
    });

    tearDown(() async {
      await database.close();
    });

    test('should complete full CRUD lifecycle', () async {
      // Create
      final song = Song(id: '1', title: 'Test Song', concertId: 'c1');
      await repository.createSong(song);

      // Read
      final retrieved = await repository.getSongById('1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Test Song');

      // Update
      final updated = retrieved.copyWith(title: 'Updated Song');
      await repository.updateSong(updated);
      final afterUpdate = await repository.getSongById('1');
      expect(afterUpdate!.title, 'Updated Song');

      // Delete
      await repository.deleteSong('1');
      final afterDelete = await repository.getSongById('1');
      expect(afterDelete, isNull);
    });
  });
}
```

**Coverage Goal**: All critical user workflows

---

## Test Patterns and Best Practices

### AAA Pattern

All tests should follow Arrange-Act-Assert:

```dart
test('should do something', () {
  // Arrange - Set up test data and dependencies
  final input = 'test input';
  final expected = 'expected output';

  // Act - Execute the behavior being tested
  final result = function(input);

  // Assert - Verify the result
  expect(result, equals(expected));
});
```

### Database Testing Pattern

Always use in-memory databases:

```dart
setUp(() async {
  database = db.AppDatabase.forTesting(NativeDatabase.memory());
  dataSource = LocalSongDataSource(database);
  repository = SongRepositoryImpl(dataSource);
});

tearDown(() async {
  await database.close();
});
```

### Async Testing

Use `pumpAndSettle()` for widget tests with async operations:

```dart
testWidgets('should load data', (tester) async {
  await tester.pumpWidget(/* ... */);

  // Wait for all animations and async operations
  await tester.pumpAndSettle();

  expect(find.text('Data loaded'), findsOneWidget);
});
```

### Provider Override Pattern

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      // Override with value
      repositoryProvider.overrideWithValue(mockRepository),

      // Override with async function
      dataProvider('id').overrideWith((arg) async => mockData),
    ],
    child: const MaterialApp(home: MyScreen()),
  ),
);
```

### Test Data Isolation

Each test should be independent:

```dart
// BAD - Shared mutable state
final sharedSong = Song(/* ... */);

test('test 1', () {
  // Modifies shared state
});

test('test 2', () {
  // Depends on test 1's modifications
});

// GOOD - Independent state
test('test 1', () {
  final song = Song(/* ... */);
  // Test uses its own data
});

test('test 2', () {
  final song = Song(/* ... */);
  // Independent data
});
```

---

## Common Pitfalls to Avoid

### 1. Testing Implementation Details

```dart
// BAD - Tests internal implementation
test('should call _internalMethod', () {
  expect(object._internalMethod(), /* ... */);
});

// GOOD - Tests public behavior
test('should return correct result', () {
  expect(object.publicMethod(), expectedResult);
});
```

### 2. Over-Mocking

```dart
// BAD - Mocking simple value objects
final mockSong = MockSong();
when(mockSong.id).thenReturn('1');
when(mockSong.title).thenReturn('Test');

// GOOD - Use real objects when simple
final song = Song(id: '1', title: 'Test', /* ... */);
```

### 3. Testing Generated Code

```dart
// BAD - Testing Equatable props
test('should have correct props', () {
  expect(song.props, [song.id, song.title, /* ... */]);
});

// GOOD - Test equality behavior only
test('should support equality comparison', () {
  final song1 = Song(id: '1', title: 'Test');
  final song2 = Song(id: '1', title: 'Test');
  expect(song1, equals(song2));
});
```

### 4. Duplicate Test Coverage

```dart
// AVOID - Entity test already covers this
// test/domain/entities/song_test.dart
test('should create valid instance', () {
  final song = Song(/* ... */);
  expect(song.title, 'Test Song');
});

// test/data/models/song_model_test.dart - DON'T repeat
test('should create valid instance', () {
  final model = SongModel(/* ... */);
  expect(model.title, 'Test Song');  // Redundant
});

// BETTER - Model test focuses on conversion
test('should convert from entity', () {
  final entity = Song(/* ... */);
  final model = SongModel.fromEntity(entity);
  expect(model.toEntity(), equals(entity));
});
```

### 5. Skipping Tests Without Good Reason

```dart
// BAD - Skip without fixing
test('should handle edge case', () {
  // TODO: Fix this later
}, skip: true);

// GOOD - Skip with specific reason and tracking
test('should play audio', () {
  // Test implementation
}, skip: 'Requires audio system mock - tracked in issue #123');
```

---

## Test Utilities and Helpers

### Creating Shared Test Utilities

**Location**: `test/helpers/`

**Purpose**: Reduce duplication and improve test maintainability

### Recommended Helpers (TO BE CREATED)

#### 1. Test Database Helper

```dart
// test/helpers/test_database_helper.dart
class TestDatabaseHelper {
  static Future<db.AppDatabase> createTestDatabase() async {
    return db.AppDatabase.forTesting(NativeDatabase.memory());
  }

  static Future<void> seedTestChoirs(
    LocalChoirDataSource dataSource,
  ) async {
    await dataSource.upsertChoir(
      ChoirModel(id: 'choir1', name: 'Test Choir', ownerId: 'user1'),
      markForSync: false,
    );
  }

  static Future<void> seedTestConcerts(
    LocalConcertDataSource dataSource,
  ) async {
    await dataSource.upsertConcert(
      ConcertModel(
        id: 'concert1',
        name: 'Spring Concert',
        date: DateTime(2025, 4, 15),
        choirId: 'choir1',
        choirName: 'Test Choir',
      ),
      markForSync: false,
    );
  }
}
```

#### 2. Test Provider Overrides

```dart
// test/helpers/test_provider_helper.dart
class TestProviderHelper {
  static List<Override> getStandardOverrides({
    required db.AppDatabase database,
  }) {
    return [
      databaseProvider.overrideWithValue(database),
      // Add other common overrides
    ];
  }
}
```

#### 3. Test Widget Wrapper

```dart
// test/helpers/test_widget_wrapper.dart
Widget createTestWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}
```

---

## Coverage Goals

### By Layer

| Layer | Goal | Current | Priority |
|-------|------|---------|----------|
| Domain Entities | 100% | 91% | Low |
| Domain Use Cases | 90% | 0% | High |
| Data Models | 100% | 50% | High |
| Data Repositories | 90% | 80% | Medium |
| Data Sources | 80% | 0% | Critical |
| Services | 80% | 100%* | Medium |
| Providers | 100% | 0% | Critical |
| Screens | 80% | 33% | High |
| Widgets | 70% | 46% | Medium |

*FileStorageService has tests but they're skipped

### Overall Coverage Target

- **Phase 1** (Current): 42% → 60% (3 months)
- **Phase 2** (Supabase): 60% → 75% (3 months)
- **Phase 3+**: 75% → 85% (ongoing)

### Definition of "Coverage"

- **File coverage**: Percentage of source files with test files
- **Line coverage**: Percentage of lines executed by tests (use `flutter test --coverage`)
- **Branch coverage**: Percentage of conditional branches tested

---

## Running Tests

### Run All Tests

```bash
# Using Docker (REQUIRED in CI)
scripts/test.sh

# Verbose output
scripts/test.sh --verbose
```

### Run Specific Tests

```bash
# Run single test file
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  flutter test test/domain/entities/song_test.dart

# Run tests in directory
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  flutter test test/domain/

# Run tests matching pattern
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  flutter test --name "should create"
```

### Generate Coverage Report

```bash
# Generate coverage data
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  flutter test --coverage

# View HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Watch Mode (Local Development)

```bash
# Not available in Docker - use for local development only
flutter test --watch
```

---

## Test Checklist for New Features

Before marking a feature complete:

- [ ] All new domain entities have tests
- [ ] All new models have conversion tests
- [ ] Repository methods have unit tests
- [ ] Data sources have integration tests
- [ ] Providers have unit tests
- [ ] Screens have widget tests (loading, error, empty, data states)
- [ ] Custom widgets have widget tests
- [ ] Critical user workflows have integration tests
- [ ] Edge cases are tested
- [ ] Error scenarios are tested
- [ ] Tests pass in Docker environment
- [ ] No skipped tests without documented reason

---

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Riverpod Testing Guide](https://riverpod.dev/docs/cookbooks/testing)
- [Drift Testing Guide](https://drift.simonbinder.eu/docs/testing/)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)

---

## Questions?

If you're unsure how to test something:
1. Check existing tests for similar patterns
2. Review this guide
3. Ask in PR review or team discussion
4. Update this guide with new patterns

**Remember**: Tests are documentation. Write tests that clearly communicate intent and expected behavior.
