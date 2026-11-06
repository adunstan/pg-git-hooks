# pg-git-hooks

Git hooks I use in PostgreSQL source trees.

## Hooks

- `pre-commit` - on master, checks the staged changes before committing:
  - catalog headers changed without a `catversion.h` bump
  - a `typedef` added to a `.c`/`.h` file without updating
    `src/tools/pgindent/typedefs.list`
  - changed `.c`/`.h` files that are not pgindent clean
- `pre-applypatch` - runs `pre-commit`, so `git am` gets the same checks.
- `post-commit` - cherry-pick bypasses `pre-commit`, so this runs the same
  checks against the new commit while a cherry-pick is in progress.  It
  can't refuse the commit, but it tells you what to amend.
- `pg-hook-lib.sh` - the checks themselves, sourced by `pre-commit` and
  `post-commit`.  It is not a hook.
- `pre-push` - lists the commits about to be pushed and asks for
  confirmation.  Remotes listed (space separated) in the
  `hooks.pushNoConfirm` git config setting are pushed to without asking,
  e.g. `git config hooks.pushNoConfirm "myfork scratch"`.

The commit checks only apply on the master branch.

## Environment

- `PGTYPEDEFCHECK=no` skips the typedefs.list check.
- `PGAUTOINDENT=yes` runs pgindent on the changed files when the indent
  check fails in `pre-commit`.  You then need to rerun `git commit`.

A failing `pre-commit` can be overridden with `git commit --no-verify`.

## Installing

pgindent needs `pg_bsd_indent` and the right version of `perltidy`; see
`src/tools/pgindent/README` in the PostgreSQL tree.

Either point git at a checkout of this repo:

    git -C /path/to/postgresql config core.hooksPath /path/to/pg-git-hooks

or copy (or symlink) the files into the tree's `.git/hooks`.  If you
symlink, symlink `pg-hook-lib.sh` too, since the hooks look for it in
the same directory they are run from.
