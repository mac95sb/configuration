# Auditing a branch for out-of-scope changes

Used when a user asks to "clean up git history" / "make sure this branch only has
fixes related to X" and no obvious junk commits are visible from `git log --oneline`.

## Procedure

1. Find the merge-base against the relevant integration branch:
   `git merge-base origin/main HEAD` (or `master`).
2. List every commit and every touched file in the range:
   `git log --stat <base>..HEAD | cat`
   `git diff --stat <base>..HEAD | cat`
3. For each file that isn't obviously in-scope (config/docs/tooling files the task
   describes), inspect the actual hunk with `git show <commit> -- <file> | cat` and
   ask: is this a required dependency of the in-scope work, or an unrelated drive-by?
4. When a file looks borderline (e.g. `# type: ignore` comments added to files outside
   the task's stated area), prove causality instead of guessing:
   - Copy the file's content from the target/base branch into place
     (`git show origin/main:<path> > /tmp/x.py; cp /tmp/x.py <path>`).
   - Rerun the relevant checker (mypy/eslint/tests) and see if new errors appear.
   - If errors appear, the change is a genuine dependency of the feature (e.g. new
     type-check task in the branch surfaces pre-existing type errors that must be
     silenced) — keep it in scope. If no errors appear, it's unrelated and should be
     flagged/dropped.
   - Immediately restore the working-tree file back to HEAD's version afterward and
     confirm `git status --short` is clean before concluding. Do this for every probe;
     don't leave temporary swaps sitting in the tree.
5. Check for incidental noise separately from feature diffs: stray blank-line-only
   edits, formatting-only changes, or reverted swaps you made while investigating.
   Revert any of your own probing edits immediately (`git checkout HEAD -- <file>`).
6. Also check whether errors "introduced" by the branch already exist unmodified on
   the target branch (diff the file against origin/main) — if the file is identical,
   the errors are pre-existing project debt, not something this branch caused.
7. Conclude explicitly: either name the specific out-of-scope commits/hunks to remove
   (and only then propose an interactive rebase/filter), or state plainly that the
   history is already scoped correctly. Don't rewrite history when the answer is
   "already clean" — that risks losing verified-clean commits for no reason.
