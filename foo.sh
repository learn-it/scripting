#!/bin/bash

main()
{
    b0="$(basename $0)"
    get_options "$@"
    echo "Rest args: ${rest_args[@]}"
}

help()
{
    local script=$(readlink -ne "$0")
    cat <<-EOF
		Usage: $b0 [options] [-- "wrapped options"]

		Write your description here. An example of BASH script starter.
		Remove FIXME comments and apply your editing.

		Options:
EOF
    # Get text between HELP BEGIN and HELP END markers in this script
    # (located in get_options()) and convert it to options help text
    sed -rne '
        /^\s*# HELP BEGIN/,/^\s*# HELP END/ {
            /\) #/ {
                s/^\s\s\s\s//
                s/\) #/\t/
                s/$/;/
                /--help\s/ s/;/./
                p
            }
        }' $script | $fixup_non_col_W |
    # -W cannot correctly word-wrap so we have to insert spaces in source text :(
    column -t -o ' ' -s $'\t' $(col_W 2) -c 80

    echo $'\n'$warn_text
}

fixup_non_col_W()
{
    sed -re 's/ +/ /g'
}

check_col_W()
{
    if echo yes|column -t -W1 &>/dev/null; then
        col_W_supported=true
        fixup_non_col_W=cat
    else
        col_W_supported=false
        fixup_non_col_W=fixup_non_col_W
    fi
}

col_W()
{
    $col_W_supported &&
        echo "-W ${1}" ||
        echo $'\n''(Ancient OS does not support "column -W", cannot properly format)'$'\n' >&2
}

concat()
{
    local old_ifs="$IFS"
    IFS=""
    echo "${*}"
    IFS="$old_ifs"
}

# FIXME: choose one of them:
# verbose_run() { set -x; eval "$@"; { set +x; } 2>/dev/null; }
verbose_run() { log "Executing: $@" >&10; eval "$@"; }

# FIXME: these are not directly used, just keep what is needed
verbose_pipe()
{
    verbose_buf=`cat`
    cat <<< "$verbose_buf"
    cat <<< "$verbose_buf" | sed 's/^/ > /' >&10
}

# push_back array_name value1 [value2] ...
push_back()
{
    arr=$1; shift
    for val in "$@"
    do
        eval $arr[\${#$arr[@]}]=\$val
    done
}

die()
{
    local ret=1
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        ret=$1
        shift
    fi
    [ -n "$1" ] && echo "$1" >&2;
    exit $ret
}

get_options()
{
    check_col_W
    local optstring_long=$(concat \
        foo,bar:,baz::, \
        verbose,dry-run,help)
    local optstring_short="fb:z::vnh"

    # 'local' cannot work here: || will not receive the exit status of backticks
    opts=$(getopt -o "${optstring_short}" --long "${optstring_long}" --name "$b0" -- "$@") ||
        exit $?
    eval set -- "$opts"

    unset foo
    unset bar
    unset baz
    unset verbose_on
    unset verbose_off
    unset verbose
    unset dryrun
    unset rest_args

    # HELP BEGIN
    while true
    do
        case "$1" in
            # FIXME: document your options by replacing the comments below:
            -f|--foo) # Database where stat tables are created                     (env MARIADB_COLLECT_DB)
                foo=true
                echo "Foo!"
                shift;;
            -b|--bar) # Collection duration N minutes (defaults to 1 hour)
                bar=$2
                echo "Bar: ${bar}"
                shift 2;;
            -z|--baz) # Collection interval N minutes (defaults to 5 minutes)
                baz=${2:-default!}
                echo "Baz: ${baz}"
                shift 2;;
            -v|--verbose) # Verbose output
                verbose_on="set -x"
                verbose_off="{ set +x; } 2>/dev/null"
                verbose=verbose_run
                shift;;
            -n|--dry-run) # Skip disk write, only display output
                dryrun=echo
                shift;;
            -h|--help) # Display this help
                help; exit;;
            --) shift; break;;
        esac
    done
    # HELP END
    push_back rest_args "$@"
}

main "$@"
