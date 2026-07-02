# Amending an earlier commit in a feature branch (interactive rebase edit)

Used when the user wants a fix folded into the commit that logically owns it,
rather than appended as a new "fix X" commit on top — e.g. "the seed script
commit should already do this" or "don't add a fixup commit, put it where it
belongs".

## Procedure

1. Make the code change on top of the branch tip first (or draft it there),
   verify it with the project's lint/type-check, then capture it as a patch so
   it can be replayed onto the target commit:
   `git diff > /tmp/fix.patch`
   `git checkout -- <file>` (revert the working-tree copy before rebasing)
2. Identify the target commit and start an interactive rebase against the
   merge-base (or any ancestor before the target commit):
   `git rebase -i <base>`
3. Mark the target commit `edit` (not `pick`) and save. Git will stop with
   `Stopped at <sha>... <message>` and HEAD detached at that commit.
4. Apply the saved patch, stage, and amend:
   `git apply /tmp/fix.patch`
   `git add <file>`
   `git commit --amend --no-edit`
5. **Pitfall — pre-commit hooks can reformat the file during the amend.** If
   the repo runs `black`/`prettier`/etc. via pre-commit, the amend may report
   the hook "Failed" because it rewrote the file in place. This is not a real
   failure: `git status --short` will show the file modified again — just
   `git add <file>` and re-run `git commit --amend --no-edit`. Confirm the
   second attempt shows all hooks "Passed" before continuing.
6. `git rebase --continue`. If no other commit touches the same file, the
   remaining commits replay with zero conflicts.
7. Verify: `git log --oneline <base>..HEAD` to confirm commit count/messages
   are otherwise unchanged, and `git diff <old-tip-sha> HEAD -- <file>` to
   confirm the net diff still matches what you intended (commit hashes from
   the amended commit onward will all change — that's expected and fine for a
   local, not-yet-pushed branch).
8. Re-run the project's full lint/type-check on the changed file one more time
   post-rebase, not just after the amend step, to be sure nothing regressed
   during replay.
9. Do not push. Report to the user that the branch has diverged from its
   remote tracking branch and ask before any `push --force-with-lease`.
