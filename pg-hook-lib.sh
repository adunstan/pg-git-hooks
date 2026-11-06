# pg-hook-lib.sh
#
# Checks shared by the pre-commit and post-commit hooks, which source this
# file.  It is not itself a hook: git only runs files named after hooks.
#
# The sourcing hook must set "mode" first:
#	staged - check the index (pre-commit, and git am via pre-applypatch)
#	head   - check the HEAD commit (post-commit, for commands such as
#			 cherry-pick that bypass pre-commit)
#
# Environment:
#	PGTYPEDEFCHECK=no	skip the typedefs.list check
#	PGAUTOINDENT=yes	in staged mode, run pgindent when the check fails

: ${PGAUTOINDENT:=no}
: ${PGTYPEDEFCHECK:=yes}

branch=$(git rev-parse --abbrev-ref HEAD)

if [ "$mode" = staged ]
then
	diffrange=--cached
	what="Commit on master"
else
	diffrange="HEAD^ HEAD"
	what="Commit $(git rev-parse --short HEAD) on master"
fi

files=$(git diff $diffrange --name-only --diff-filter=ACMR)
status=0

# Report a failed check: the first argument completes "$what", the rest
# are hint lines.
fail()
{
	echo "$what $1" >&2
	shift
	if [ $# -gt 0 ]
	then
		printf '%s\n' "$@" >&2
	fi
	status=1
}

check_catalog_version()
{
	case "$files" in
		*src/include/catalog/catversion.h*)
			return 0
			;;
		*src/include/catalog/*)
			;;
		*)
			return 0
			;;
	esac

	fail 'alters catalog but catversion not bumped'
}

check_typedef()
{
	test "$PGTYPEDEFCHECK" = yes || return 0

	echo "$files" | grep -qx 'src/tools/pgindent/typedefs.list' && return 0

	git diff $diffrange --name-only --diff-filter=ACMR -Stypedef |
		grep -q '[.][ch]$' || return 0

	fail 'contains a typedef but typedefs.list not changed' \
		'(PGTYPEDEFCHECK=no skips this check)'
}

check_indent()
{
	# pgindent ignores anything that isn't a .c or .h file, but make sure
	# there is at least one
	echo "$files" | grep -q '[.][ch]$' || return 0

	src/tools/pgindent/pgindent --check $files && return 0

	if [ "$mode" = head ]
	then
		fail 'needs a pgindent run, e.g:' \
			'src/tools/pgindent/pgindent --commit=HEAD' \
			'then git commit --amend'
	elif [ "$PGAUTOINDENT" = yes ]
	then
		fail 'needs a pgindent run' 'Running pgindent on changed files'
		src/tools/pgindent/pgindent $files
		echo 'You need to rerun git commit to pick up pgindent changes' >&2
	else
		fail 'needs a pgindent run, e.g:' \
			"$(echo src/tools/pgindent/pgindent $files)"
	fi
}

# Run all checks, reporting every failure rather than just the first.
pg_run_checks()
{
	test "$branch" = master || return 0
	test -n "$files" || return 0

	check_catalog_version
	check_typedef
	check_indent

	if [ $status -ne 0 ] && [ "$mode" = staged ]
	then
		echo 'The commit can be forced with git commit --no-verify' >&2
	fi

	return $status
}
