# Commit Surgery Checklist

Use this for history rewriting / commit surgery: multi-pass staged/rebased histories where the final commit topology needs clean, logically-scoped boundaries.

## Preparation

1. Confirm the base is correct and the rewrite is explicitly approved.
2. Verify unrelated commits are *actually* unrelated: inspect each file against the feature scope.
3. For repos with pre-commit hooks, expect them to touch staged files — verify with final `git status` rather than trusting the commit output alone.

## Safe sequencing

```sh
BASE=<merge-base-or-good-known-commit>

# Start from clean state on the feature base
git reset --soft "$BASE"

# See what you have
git status --short
git diff --name-only
git diff --cached --name-only

# Stage only the first commit's files, unstage the rest
git restore --staged -- <paths-that-belong-in-other-commits>

# Verify staged pathspec before committing
git diff --cached --name-only
# -> should match exactly the commit you intend to produce
git commit -m "..."

# Repeat for each commit
```

## Pre-commit-hook gotcha

Git hooks see staged files + dirty tracked files. A hook can rewrite a dirty file you intentionally left unstaged:

- If you rerun the same `git commit` after the hook fixed your stale staged edits, that dirty file may now appear as `MM`.
- Inspect `git status --short` after every failed/retried commit:
  - `A` / `M` in the first column are staged changes ready to commit.
  - `M` in the second column is worktree-only and should stay unstaged unless you explicitly want it in this commit.
- If a file belongs in this commit but got rewritten by the hook outside the index, re-stage it with `git add <path>` and retry.

## Dropping unrelated files from history

When you discover files from an unrelated scope in the feature branch (e.g. `# type: ignore` patches, unrelated billing utility edits):

```sh
# Compare to the base and identify the offending files
git diff --name-only <base>..HEAD

# For files that should not be in this branch, remove them from HEAD
# but keep the working-tree version from the current branch tip
git restore --source <base> --staged --worktree -- <unrelated-file>

# Re-stage the corrected set and continue commit surgery
git add -- <files-that-belong>
git commit --amend   # or repeat the staged-commit loop from scratch
```

- Do not `git checkout -- <file>` unless you are sure the working-tree version is also backed by history you want to keep.
- Always verify with `git diff <base>..HEAD -- <file>` that the dropped file is truly gone from the branch before pushing.

## Final verification

1. `git status` shows clean working tree.
2. `git log --oneline --stat -- <feature-files>` shows only in-scope files.
3. `git branch --show-current` and `git remote -v` confirm you are on the intended branch targeting the expected remote.
4. Inspect ahead/behind before any push:
   ```sh
   git rev-list --left-right --count HEAD...origin/$(git branch --show-current)
   ```
   If the branch has diverged, do not push without explicit approval; report the divergence and that `git push --force-with-lease` will be required.
