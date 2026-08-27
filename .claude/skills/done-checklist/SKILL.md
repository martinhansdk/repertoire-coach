---
name: done-checklist
description: Ensures all work is properly completed before declaring a task done. Use when finishing a task, completing implementation, about to say "done" or "complete", or when the user asks to verify completion. Triggers on phrases like "I've finished", "implementation complete", "all done", "that's it", or when wrapping up work.
---

# Done Checklist

Before declaring any task complete, you MUST verify each item on this checklist. Do not skip items - go through them explicitly.

## Mandatory Checklist

### 0. Completeness
Are you truly done?
- [ ] Did you complete all the work that was agreed?
- [ ] Did you clean up debug statements that are no longer needed?
- [ ] If this was a bug fix, did any of the attempts you made along the way turn out to be misguided? Should they be reverted?
- [ ] Did you use the ErrorReporter where the code catches an exception or another error?

### 1. Validation Passes
Run validation and confirm it passes:

- [ ] `MCP flutter analyze` passes with no errors
- [ ] `MCP flutter test` passes with no failures

If validation fails, FIX the issues before proceeding.

### 2. Tests Written
For any new or modified code:
- [ ] Unit tests exist for new functions/classes
- [ ] Tests cover happy path AND edge cases
- [ ] Tests follow project patterns (check existing tests in `test/`)

If tests are missing, WRITE them before proceeding.

**Reminder**: Run `scripts/mocks.sh` if you added new mock annotations.

### 3. Documentation Updated
Check if any of these need updates:
- [ ] `TODO.md` - Mark completed tasks, add new tasks discovered
- [ ] `ARCHITECTURE.md` - Update if architectural decisions were made
- [ ] `REQUIREMENTS.md` - Update if requirements changed
- [ ] Code comments - Add for complex logic

If documentation is stale, UPDATE it before proceeding.

### 4. Tool & Script Reflection
**IMPORTANT**: Review the tools and scripts you used during this session:

#### MCP Tools (Flutter, Supabase, GitHub, Playwright)
- [ ] Did any MCP tool calls fail or return unexpected results?
- [ ] Did you work around an MCP tool limitation by using Bash instead?
- [ ] Is there a missing MCP tool that would have been useful?
- [ ] Does the MCP server need bug fixes or new features?

If issues found: Create a task in TODO.md or fix the MCP server directly (e.g., `flutter-mcp-server/`).

#### Scripts (`scripts/` directory)
- [ ] Did any script fail or behave unexpectedly?
- [ ] Did you compose manual commands instead of using a script?
- [ ] Is there a missing script that would be useful?
- [ ] Do existing scripts need improvements?

If issues found: Fix the script or create a new one.

#### CLAUDE.md Accuracy
- [ ] Are the instructions in CLAUDE.md still accurate?
- [ ] Did you discover new patterns or conventions not documented?
- [ ] Are there outdated instructions that caused confusion?

If issues found: Update CLAUDE.md.

### 5. Code Committed, Pushed, and CI Green
For completed work:
- [ ] All relevant files are staged
- [ ] Commit message follows conventional commits format
- [ ] Commit includes `Co-Authored-By: Claude <noreply@anthropic.com>`
- [ ] Changes are pushed to remote
- [ ] **CI watched to completion** and any failures fixed — pushing is not
      the finish line. Local validation does not cover what CI does:
      iOS/Android/web builds and the Sync integration workflow (real
      Supabase stack) run only there. Use `gh run list --branch <branch>`
      then poll `gh run view <id> --json status,conclusion`.

```bash
git add <files>
git commit -m "$(cat <<'EOF'
type(scope): description

Body explaining what and why.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

### 6. Environment cleaned up
- [ ] Check your background tasks. Are any still running that are no longer relevant and should be killed?
- [ ] Did you delete now-obsolete old log files, screen shots or similar from the project directory?

## How to Use This Checklist

When finishing work, explicitly state:

```
## Completion Checklist

0. **Completeness*: ✅ I am truly done.
1. **Validation**: ✅ Validation passed
2. **Tests**: ✅ Added tests in `test/path/to/test.dart`
3. **Documentation**: ✅ Updated TODO.md to mark task complete
4. **Tool Reflection**:
   - ✅ MCP tools worked correctly
   - ⚠️ `scripts/mocks.sh` - added to TODO: improve error messages
   - ✅ CLAUDE.md is current
5. **Committed & Pushed**: ✅ Pushed "feat(sync): add data sync service"; CI green (build + sync-integration)
6. **Environment cleaned up**: ✅ obsolete temporary files were deleted, no stale tasks running.
All done!
```

## Tool Reflection Examples

### Example: MCP Tool Issue
During the session, you used `mcp__flutter__flutter_test` but it didn't return failure details clearly:
```
**Tool Reflection**:
- ⚠️ Flutter MCP `get_test_results` returned "No test results found" even after running tests
- Action: Added TODO to fix test result caching in flutter-mcp-server
```

### Example: Script Workaround
You ran a raw docker command instead of using a script:
```
**Tool Reflection**:
- ⚠️ Used `docker run ... flutter pub run build_runner` directly
- Action: There's already `scripts/mocks.sh` for this - I should have used it
- Note: CLAUDE.md doesn't mention mocks.sh - updated CLAUDE.md
```

### Example: Missing Script
You had to compose a complex command that could be reusable:
```
**Tool Reflection**:
- ⚠️ Manually ran multi-step deployment commands
- Action: Created `scripts/deploy-web.sh` to automate this workflow
```

## Common Mistakes to Avoid

1. **Saying "done" before running validation** - Always run `scripts/validate.sh`
2. **Skipping tests** - Every feature needs tests, no exceptions
3. **Forgetting TODO.md** - If you completed a task from TODO.md, mark it done
4. **Ignoring tool failures** - If a tool/script failed, note it for fixing
5. **Working around broken tools** - Fix the tool, don't just work around it
6. **Not pushing** - Always push completed work
7. **Declaring done at push** - Wait for CI; it catches what local validation cannot

## When to Skip Items

- **Tests**: Only skip if the change is documentation-only or config-only
- **Documentation**: Only skip if no architectural/requirement changes
- **Tool Reflection**: Never skip - always reflect on tools used
- **Commit/Push**: Only skip if user explicitly said "don't commit"

## Final Reminder

If ANY checklist item fails or is incomplete, you are NOT done. Fix it first, then declare completion.
