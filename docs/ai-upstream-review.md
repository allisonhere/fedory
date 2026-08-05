# AI playbook for Omarchy review issues

This document tells an AI coding agent how to handle the generated
`[Upstream] Omarchy changes require review` issue. The issue is a signal to
investigate, not a request to merge Omarchy or copy every reported file.
Fedory ports useful behavior deliberately while retaining Fedora packaging,
security, installation, migration, and runtime contracts.

Read [`upstream-sync.md`](upstream-sync.md), [`scope.md`](scope.md), and the
repository [`AGENTS.md`](../AGENTS.md) before changing files.

## Safety invariant

Do not advance `UPSTREAM_VERSION` until every upstream commit and changed path
through the selected target commit has one of these recorded outcomes:

- ported with Fedory-specific tests;
- already implemented in Fedory;
- intentionally omitted with a reason; or
- superseded or reverted by a later commit inside the reviewed range.

The classifications in `upstream/path-map.tsv` are routing guidance, not
approval to copy a file. A `port` entry can still depend on Arch paths or
Omarchy assumptions, and an `ignore` entry must still be checked for behavior
that affects distributed Fedory code.

## Establish the review range

1. Inspect `git status --short --branch`, the current branch, recent commits,
   and any existing sync work. Preserve unrelated changes and do not overwrite
   another contributor's work.
2. Read the current issue body, but reproduce it locally. The weekly workflow
   may have updated the issue after work began.
3. Run the audit with enough room to show every changed path and save the
   report as a work artifact:

   ```bash
   fedory dev upstream audit \
     --max-files 10000 \
     --output /tmp/omarchy-upstream.md
   ```

4. Record the exact base and target commit hashes from the report. Use that
   target for the whole review instead of chasing a moving default branch. New
   upstream commits belong to the next review unless the maintainer explicitly
   expands the range.
5. If the checkpoint is not an ancestor of the target, stop checkpoint work
   until the branch transition or rewritten history is understood. Never hide
   that warning by replacing the base with a convenient commit.

Create a dedicated branch such as `sync/omarchy-YYYYMMDD` from the current
Fedory default branch unless an appropriate sync branch already exists.

## Review commits and paths

Read the upstream commit sequence as well as the final diff. Commit messages
explain intent, while the final diff reveals follow-up fixes, reversions, and
renames. Group related commits by behavior, then account for every path in the
audit report.

For each behavior:

1. Find the corresponding Fedory implementation before writing code. Names and
   directory layouts often differ.
2. Decide whether the behavior is useful and compatible with Fedory's scope.
3. Port the smallest complete behavior, including its error handling and
   existing-user upgrade path. Do not mechanically translate syntax or copy an
   intermediate upstream state that is reverted later in the range.
4. Apply Fedory contracts:
   - translate packages through `packaging/package-map.tsv`;
   - use `fedory-` command names and keep command metadata valid;
   - use `$FEDORY_PATH`, `pkexec`, helper commands, and installer boundaries as
     described in `AGENTS.md`;
   - preserve the Fedory shell plugin and IPC contracts;
   - add a migration when existing users need the change; and
   - review licenses and provenance before importing code or binary assets.
5. Add focused automated tests for observable behavior. Translate upstream
   tests into Fedory tests instead of copying assumptions about Arch, Omarchy
   paths, or unavailable test infrastructure.
6. Record omissions and deliberate differences immediately. Use a concise
   source comment when future code readers need the context and include the
   decision in the checkpoint review document.

Keep an explicit ledger while working. It should map upstream commits or
behavior groups to their Fedory resolution and make omissions as visible as
ports. The completed ledger belongs in
`upstream/reviews/YYYY-MM-DD-<target-short-hash>.md`.

## Implementation discipline

Use atomic commits for coherent behaviors. Do not mix checkpoint bookkeeping
with unrelated fixes, and do not make broad cleanup changes merely because the
upstream diff exposed nearby code.

When an upstream change reveals a pre-existing Fedory defect, distinguish it
in the review record. Fix it in a separate atomic commit when practical so the
port and the local repair remain independently reviewable.

An AI agent must not:

- merge or rebase the Omarchy tree into Fedory;
- assume an upstream package name, service path, privilege model, or user
  directory is valid on Fedora;
- invent a Fedora equivalent without checking the package map and repository;
- mark a path resolved merely because the final file diff looks irrelevant;
- weaken SELinux or other security boundaries to make a test pass;
- claim graphical or fresh-install verification from static inspection; or
- close the tracking issue manually while the checkpoint still reports drift.

## Verification

Run focused tests throughout the port. Before advancing the checkpoint, run:

```bash
./test/all
git diff --check
```

Also perform the validation required by the changed behavior:

- run `qmllint` or other structural checks for QML when available;
- restart the running Fedory shell and inspect the real UI for shell changes;
- verify visual changes with reference and candidate screenshots;
- exercise migrations from an appropriate pre-change state; and
- run `bootstrap.sh` on a fresh Fedora VM for installer, package, system
  service, boot, or other machine-level changes.

If the environment cannot provide a Fedora VM or graphical session, state that
clearly in the review document and handoff. Automated tests are not a substitute
for required visual or installation verification. Leave the work unclaimed in
that dimension rather than describing it as complete.

## Complete the checkpoint

After all reported commits and paths are resolved and the required validation
has passed:

1. Write or finish the review ledger under `upstream/reviews/`.
2. Update `ref`, `commit`, and `reviewed_at` in `UPSTREAM_VERSION` to the exact
   reviewed target. The pin means the range was reviewed; it does not mean
   every Omarchy feature was adopted.
3. Rerun the audit against that exact target and confirm it reports zero
   changed paths:

   ```bash
   fedory dev upstream audit \
     --target <reviewed-commit> \
     --output /tmp/omarchy-upstream-final.md
   ```

4. Rerun `./test/all` and `git diff --check` after the bookkeeping changes.
5. Summarize the reviewed range, ports, omissions, tests, real-system checks,
   and any unverified risks for the maintainer.

The weekly workflow owns the generated issue lifecycle. Once the reviewed
checkpoint reaches Omarchy's current default branch, its next successful run
comments on and closes the issue. If Omarchy has moved again, the issue should
remain open and report the new range; that does not invalidate the completed
checkpoint.
