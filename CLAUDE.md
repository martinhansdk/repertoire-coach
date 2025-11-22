# Working with Claude on Repertoire Coach

This document provides context and guidelines for working with Claude Code (or any AI assistant) on this project.

## Project Context Summary

### What This App Does
A collaborative mobile/desktop app for choir members to practice their vocal parts. Users organize into choirs, share concerts and songs with multiple voice tracks, and maintain personal practice metadata (section markers, playback positions).

### Key Architectural Decisions

**Why Choir-Based Architecture?**
- Initially designed as single-user, evolved to multi-user collaborative model
- Choirs are user groups with an owner who manages membership
- Content (concerts, songs, audio) is shared among choir members
- Personal metadata (sections, playback positions) stays private per-user

**Why Supabase + PostgreSQL instead of Firebase?**
- **Cost concerns**: More predictable pricing, lower at scale
- **Vendor lock-in concerns**: Open source, can self-host
- **Relational model**: Foreign keys, complex queries, data integrity
- **Row Level Security**: Database-level access control perfect for choir permissions

**Why Riverpod for state management?**
- Compile-time safety (fewer runtime crashes)
- Great for async data (Supabase queries)
- Easy testing
- Modern Flutter best practices

**Why Flutter?**
- Cross-platform: Android (primary), iOS, Web
- Android Auto support via native integration
- Good audio support (just_audio package)

### Important Requirements

**Concert Organization:**
- Concerts have dates and are automatically sorted (upcoming first, then past)
- No custom manual ordering - date-based only
- Users see all concerts from all their choirs

**Audio & Sharing:**
- Audio files are shared among choir members (uploaded once, accessible to all)
- Any choir member can add/edit concerts and songs
- Only choir owner can manage membership

**Personal Data:**
- Section markers are private per-user but follow the song everywhere
- Playback positions are saved per user per song
- Last accessed concert is tracked per user

**Removed Features:**
- Practice session tracking/statistics - won't be implemented
- Adjustable playback speed - won't be implemented
- Pitch adjustment - won't be implemented

## Project Structure

```
choir-app/
├── REQUIREMENTS.md      # Detailed feature requirements and workflows
├── ARCHITECTURE.md      # Technical design, database schema, data models
├── TODO.md             # Development tasks organized by phase
├── DOCKER.md           # Docker setup for builds and Supabase
├── README.md           # Project overview
├── Dockerfile.build    # Flutter build container
├── docker-compose.supabase.yml  # Self-hosted Supabase stack
└── lib/                # Flutter source (to be created)
```

## Working with Claude on This Project

### Starting a New Session

When starting a new session with Claude, provide context:

```
I'm working on the choir practice app. Please read REQUIREMENTS.md
and ARCHITECTURE.md to understand the project context.
```

Or reference specific sections:
```
Looking at the database schema in ARCHITECTURE.md, I need help
implementing the RLS policies for concerts.
```

### Useful Prompts for This Project

**Architecture Questions:**
```
Why did we choose [technology/pattern] over [alternative]?
How does [feature] work in our architecture?
What's the data flow for [user workflow]?
```

**Implementation Help:**
```
Implement the [usecase] following the clean architecture in ARCHITECTURE.md
Create the Riverpod provider for [feature]
Write the RLS policy for [table] according to our security requirements
```

**Database Work:**
```
Generate the SQL migration for [feature] following our schema in ARCHITECTURE.md
Create the Supabase query for [workflow] from REQUIREMENTS.md
```

**Debugging:**
```
I'm getting [error] when [doing X]. Our architecture uses [pattern],
what could be wrong?
```

### What Claude Knows About This Project

Claude has full context of:
- ✅ All requirements and user workflows (REQUIREMENTS.md)
- ✅ Complete technical architecture (ARCHITECTURE.md)
- ✅ Database schema and RLS policies
- ✅ Development phases and tasks (TODO.md)
- ✅ Docker setup for builds and deployment
- ✅ Technology choices and reasoning
- ✅ Data models and relationships
- ✅ Security requirements

### Key Things to Remember When Asking Claude

1. **Reference the docs**: Claude can read all markdown files, so reference them
   - "According to ARCHITECTURE.md, we use..."
   - "REQUIREMENTS.md says users should be able to..."

2. **Be specific about context**:
   - Bad: "How do I query songs?"
   - Good: "How do I query songs for a specific concert using our PostgreSQL schema?"

3. **Mention constraints**:
   - "Following our clean architecture pattern..."
   - "Using Riverpod for state management..."
   - "Respecting the RLS policies defined in ARCHITECTURE.md..."

4. **Ask about decisions**:
   - "Why did we choose X over Y?" (if reasoning isn't clear)
   - Claude can explain the trade-offs

5. **Request updates to docs**:
   - "Update TODO.md to mark [task] as complete"
   - "Add this decision to ARCHITECTURE.md"

## Development Workflow with Claude

### Phase 1: Planning
```
I want to implement [feature]. Can you:
1. Break it down into subtasks
2. Update TODO.md with these tasks
3. Identify which files need to be created/modified
```

### Phase 2: Implementation
```
Implement [specific task] from TODO.md following our architecture.
Make sure to:
- Follow the data models in ARCHITECTURE.md
- Use Riverpod providers
- Handle errors appropriately
- **ALWAYS write comprehensive tests** (unit, widget, and/or integration tests)
```

**IMPORTANT: Testing is Mandatory**
- Every feature implementation MUST include tests
- Write tests for all new code (domain entities, repositories, providers, widgets)
- Tests should cover happy paths, edge cases, and error scenarios
- Aim for high test coverage to ensure code quality and prevent regressions

### Phase 3: Review
```
Review this implementation of [feature] against REQUIREMENTS.md.
Does it meet all the requirements? Any security concerns with RLS?
```

### Phase 4: Documentation
```
I've implemented [feature]. Update:
- TODO.md to mark tasks complete
- Add any new architecture decisions to ARCHITECTURE.md if needed
```

## Common Patterns in This Project

### Clean Architecture Layers
```
Presentation (UI) → Domain (Use Cases) → Data (Repositories/Data Sources)
```

Ask Claude to follow this when implementing features.

### Riverpod Provider Pattern
```dart
// Read-only data
final concertsProvider = FutureProvider<List<Concert>>(...);

// Mutable state
final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(...);
```

### Supabase Query Pattern
```dart
final response = await supabase
  .from('table')
  .select('*, related_table!inner(*)')
  .eq('field', value);
```

### RLS Policy Pattern
All tables use Row Level Security. Users can only access:
- Their own private data (sections, playback_states)
- Data from choirs they're members of (choirs, concerts, songs)

## Testing with Claude

**⚠️ Tests Are NOT Optional**
Every implementation MUST include tests. Do not consider a feature "complete" without comprehensive test coverage.

**Test Types to Include:**

**Unit Tests:**
```
Write unit tests for [use case] following Flutter testing best practices.
Include edge cases from REQUIREMENTS.md.
Test all domain entities, use cases, and repository implementations.
```

**Widget Tests:**
```
Write widget tests for all UI components.
Test user interactions, state changes, and rendering.
Verify proper display of data in different states (loading, error, success, empty).
```

**Integration Tests:**
```
Write integration tests for [user workflow] from REQUIREMENTS.md.
Test the complete flow from UI to Supabase.
```

**RLS Testing:**
```
Write tests to verify RLS policies for [table].
Ensure users can't access data outside their choirs.
```

**Test Coverage Goals:**
- Domain layer: 100% (entities, use cases)
- Data layer: 90%+ (repositories, models)
- Presentation layer: 80%+ (widgets, providers)

## Pre-Commit Validation (MANDATORY)

**⚠️ CRITICAL: Always validate before committing**

Before any commit, Claude MUST run these commands to verify the code is correct:

### 1. Run Flutter Analyze
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder sh -c 'flutter pub get && flutter analyze'
```
**Purpose:** Catch linting errors, type errors, and code quality issues
**Must Pass:** Zero issues found

### 2. Run Flutter Tests
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder sh -c 'flutter pub get && flutter test'
```
**Purpose:** Verify all tests pass with the changes
**Must Pass:** All tests passing (or only known skipped tests)

### 3. Only Then Commit
If both analyze and test pass, then commit:
```bash
git add <files>
git commit -m "message"
git push
```

**Why This Matters:**
- CI runs these same checks - catching issues locally saves time
- Multiple fix commits clutter the history
- Shows proper software engineering discipline
- Prevents breaking the build for other developers

**Examples of Issues This Catches:**
- Type errors (e.g., passing String to bool parameter)
- Unused imports
- Missing const keywords
- Compilation errors
- Broken tests from code changes

## Troubleshooting with Claude

**When stuck:**
```
I'm trying to [do X] but getting [error Y].
Our setup uses [tech stack from ARCHITECTURE.md].
What could be wrong?
```

**Architecture questions:**
```
How should [feature] fit into our clean architecture?
Which layer should handle [responsibility]?
```

**Database questions:**
```
What's the correct SQL query to [do X] given our schema in ARCHITECTURE.md?
Do I need a new index for this query?
```

## Updating Documentation

Always ask Claude to update docs when:
- Completing tasks: `Update TODO.md to mark [tasks] as complete`
- Making architectural decisions: `Document this decision in ARCHITECTURE.md`
- Adding features: `Update REQUIREMENTS.md if this changes user workflows`
- Changing tech: `Update ARCHITECTURE.md with the new approach`

## Git Workflow with Claude

### When Claude Should Auto-Commit

Claude should **automatically commit** after completing these types of changes (without being asked):
- Documentation updates (README, REQUIREMENTS, ARCHITECTURE, TODO, etc.)
- Project naming changes
- Configuration file changes
- Completing discrete features or tasks
- Refactoring that doesn't change functionality

The user shouldn't need to ask for commits on routine changes - just do it!

### Creating Commits

Claude can help with commits:
```
Create a commit for the changes we just made to [feature].
Use conventional commit format.
```

Claude includes co-author attribution by default:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## What Claude Can't Do (Yet)

- Run the Flutter app (can write code, can't execute)
- Test on real devices
- Deploy to app stores
- Set up actual Supabase projects (can provide SQL and config)
- Sign Android/iOS builds

For these, you'll need to follow the instructions Claude provides.

## Project-Specific Conventions

### File Naming
- Features: `feature_name.dart`
- Providers: `feature_name_provider.dart`
- Models: `feature_name_model.dart`
- Tests: `feature_name_test.dart`

### Code Style
- Follow Flutter style guide
- Use meaningful variable names
- Document complex logic
- Keep functions small and focused

### Database Naming
- Tables: plural, snake_case (`choir_members`)
- Columns: snake_case (`created_at`)
- Foreign keys: `table_id` (`choir_id`)

### Git Commits
- Use conventional commits
- Reference issue numbers if applicable
- Keep commits atomic (one logical change)

## Tips for Effective Collaboration

1. **Start broad, then narrow**: Ask architectural questions before implementation details
2. **Validate against docs**: Ask Claude to verify implementations against REQUIREMENTS.md
3. **Iterate**: Don't expect perfect code first try, refine iteratively
4. **Update docs**: Keep documentation in sync with code changes
5. **Ask "why"**: Understanding decisions helps maintain the project

## Quick Reference

- **Requirements**: See REQUIREMENTS.md
- **Architecture**: See ARCHITECTURE.md
- **Tasks**: See TODO.md
- **Docker**: See DOCKER.md
- **Database Schema**: ARCHITECTURE.md → Database Schema section
- **Tech Stack**: ARCHITECTURE.md → Technology Stack section
- **User Workflows**: REQUIREMENTS.md → User Workflows section

## Example Session

```
You: I want to implement the "create choir" feature

Claude: I'll help implement choir creation. Looking at REQUIREMENTS.md,
users should be able to create a choir and become its owner. According
to ARCHITECTURE.md, we're using clean architecture. Let me create:
1. Domain entity (Choir)
2. Use case (CreateChoir)
3. Repository interface
4. Riverpod provider
5. UI screen

Should I proceed?

You: Yes, and update TODO.md when done

Claude: [implements feature and updates docs]
```

## Conclusion

This project has comprehensive documentation. Claude can be most helpful when:
- You reference the existing docs
- You're specific about what you need
- You ask Claude to maintain the documentation
- You validate implementations against requirements

The architecture is well-defined, so focus on implementation and testing. Claude can help write code that follows the established patterns and keep documentation up to date.

Happy coding! 🎵
