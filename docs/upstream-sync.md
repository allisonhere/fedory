# Keeping Fedory aligned with Omarchy

Fedory ports Omarchy behavior deliberately; it never merges the upstream tree
directly. Omarchy targets Arch, while Fedory owns Fedora packaging, privilege
boundaries, installation, migrations, and a Fedora-tested runtime.

## Tracking files

- `UPSTREAM_VERSION` records the lower commit used by change reports. Advancing
  it means every upstream path through that commit was reviewed. It does not
  claim feature parity.
- `upstream/path-map.tsv` classifies upstream paths as direct port candidates,
  Fedora rewrites, manual review, or intentionally ignored metadata.
- `upstream/reviews/` records each completed checkpoint review, including
  deliberate Fedory deviations that should survive future upstream diffs.
- `fedory-dev-upstream-audit` fetches Omarchy into a bare cache and produces a
  Markdown report from the checkpoint to Omarchy's current default branch.
- `.github/workflows/upstream-watch.yml` runs the audit weekly and maintains one
  tracking issue while unreviewed changes exist.

Omarchy changed its default branch from `master` to `quattro`. The audit asks
the remote for its symbolic `HEAD`, so another branch change does not silently
stop monitoring.

## Review workflow

Run the audit and keep its report with the sync branch:

```bash
git remote add upstream https://github.com/basecamp/omarchy.git
git fetch upstream --tags
git switch -c sync/omarchy-$(date +%Y%m%d)
fedory dev upstream audit --output /tmp/omarchy-upstream.md
```

For each reported path:

1. Read the upstream commits that produced the change.
2. Decide whether the behavior belongs in Fedory.
3. Translate package operations through `packaging/package-map.tsv`.
4. Preserve Fedory's `$FEDORY_PATH`, `pkexec`, command metadata, shell IPC, and
   installer contracts.
5. Add a migration if an existing user must receive the change.
6. Record intentional deviations in a source comment, commit message, or the
   path policy.

Finish with:

```bash
./test/all
git diff --check
```

Then run `bootstrap.sh` against a fresh Fedora VM and visually verify shell
changes. Only after every reported path is resolved should `ref`, `commit`, and
`reviewed_at` in `UPSTREAM_VERSION` move to the reviewed target.

## Automation behavior

The scheduled workflow is report-only. It can create, update, or close the
fixed-title tracking issue, but it cannot edit Fedory files, advance the pin,
or merge upstream code. This keeps an upstream compromise or Arch-specific
change from becoming an automatic Fedora update.
