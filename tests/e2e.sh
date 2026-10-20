#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP,
# which has a symbolic link loop: every run is limited to 20 seconds, so a
# regression fails instead of hanging.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from /dev/null and compares
# standard output with EXPECTED_FILE. If $WANT_ERR is set, standard error
# must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    timeout 20 "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$want_file" "$TMP/out" | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# lines LINE...: the lines, each followed by a newline. Lines that end in
# spaces (the line after a folder's files) are written out in quotes.
lines() { printf '%s\n' "$@"; }

# ascii: the same drawing with /A's characters.
ascii() { sed 's/├───/+---/g; s/└───/\\---/g; s/│/|/g'; }

nl=$'\n'
head_line='Folder PATH listing'
none='No subfolders exist'

# The fixture tree: files and folders that sort NTFS-style (`.hidden` <
# `Alpha.md` < `C.TXT` < `_x`), a non-ASCII name, and symbolic links: a
# loop (src/up -> ..), a second way into docs, a link to a file and a
# dangling link.
W="$TMP/w"
mkdir -p "$W/docs/img" "$W/src/win" "$W/empty" "$W/.hidden" "$W/café"
for f in notes.txt Alpha.md C.TXT _x docs/guide.md docs/img/logo.png src/main.loup \
    src/win/paths.loup café/menu.txt; do
    printf 'x\n' > "$W/$f"
done
ln -s .. "$W/src/up"
ln -s docs "$W/also"
ln -s docs/guide.md "$W/link.md"
ln -s nowhere "$W/dangling"
cd "$W"
# $W as tree prints it: \tmp\tmp.XXXX\w
WD=${W//\//\\}

# Help and version.
help_first='Draw the folders below a directory as a tree.'
"$BIN" '/?' < /dev/null > "$TMP/help" 2>&1
if [ "$(head -1 "$TMP/help")" = "$help_first" ] && [ "$(wc -l < "$TMP/help")" -eq 9 ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL: /? help"
fi
cp "$TMP/help" "$TMP/help_want"
check_file "-? with a path"       0 "$TMP/help_want" docs -?
check_file "--help"               0 "$TMP/help_want" --help
check      "--version"            0 $'tree (loup-cmd-tree) 0.1.0\n' --version

# Folders only. Links to directories are folders, never entered (src/up
# would loop; also shows nothing of docs).
folders=$(lines \
    "├───.hidden" \
    "├───also" \
    "├───café" \
    "├───docs" \
    "│   └───img" \
    "├───empty" \
    "└───src" \
    "    ├───up" \
    "    └───win")
check_both "default"              0 "$(lines "$head_line" ".")$nl$folders$nl" ''
check_both "/A"                   0 "$(lines "$head_line" ".")$nl$(ascii <<< "$folders")$nl" '' /A
check_both "-a, lower case"       0 "$(lines "$head_line" ".")$nl$(ascii <<< "$folders")$nl" '' -a

# /F: a folder's files first, then a line with only the prefix.
with_files=$(lines \
    "│   Alpha.md" \
    "│   C.TXT" \
    "│   link.md" \
    "│   notes.txt" \
    "│   _x" \
    "│   " \
    "├───.hidden" \
    "├───also" \
    "├───café" \
    "│       menu.txt" \
    "│       " \
    "├───docs" \
    "│   │   guide.md" \
    "│   │   " \
    "│   └───img" \
    "│           logo.png" \
    "│           " \
    "├───empty" \
    "└───src" \
    "    │   main.loup" \
    "    │   " \
    "    ├───up" \
    "    └───win" \
    "            paths.loup" \
    "            ")
check_both "/F"                   0 "$(lines "$head_line" ".")$nl$with_files$nl" '' /F
check_both "/F /A"                0 "$(lines "$head_line" ".")$nl$(ascii <<< "$with_files")$nl" '' /F /A
check_both "/a/f"                 0 "$(lines "$head_line" ".")$nl$(ascii <<< "$with_files")$nl" '' /a/f

# A path: shown as given, with backslashes.
src=$(lines "├───up" "└───win")
check_both "relative path"        0 "$(lines "$head_line" "src")$nl$src$nl" '' src
check_both "trailing separator"   0 "$(lines "$head_line" 'src\')$nl$src$nl" '' 'src\'
check_both "backslashes"          0 "$(lines "$head_line" 'docs\img' "$none")$nl$nl" '' 'docs\img'
check_both "absolute path"        0 "$(lines "$head_line" "$WD\\src")$nl$src$nl" '' "$W/src"
check_both "path after --"        0 "$(lines "$head_line" "src")$nl$src$nl" '' -- src
check_both "through the link"     0 "$(lines "$head_line" 'src\up\docs' "└───img")$nl" '' 'src\up\docs'
check_both "link as the start"    0 "$(lines "$head_line" "also" "└───img")$nl" '' also

# No subfolders: the files (with /F), then the message and a blank line.
check_both "empty folder"         0 "$(lines "$head_line" "empty" "$none")$nl$nl" '' empty
check_both "files, no subfolders" 0 "$(lines "$head_line" 'src\win' "    paths.loup" "    " "$none")$nl$nl" '' /F 'src\win'

# A big folder (3,000 files): sorted, and done within the time limit.
mkdir "$TMP/big"
(cd "$TMP/big" && for i in $(seq 1 3000); do : > "f$i.txt"; done && mkdir sub)
timeout 20 "$BIN" /F "$TMP/big" < /dev/null > "$TMP/bigout" 2>&1
big_status=$?
if [ "$big_status" -eq 0 ] && [ "$(wc -l < "$TMP/bigout")" -eq 3004 ] \
    && [ "$(sed -n 3p "$TMP/bigout")" = "│   f1.txt" ] \
    && [ "$(sed -n 4p "$TMP/bigout")" = "│   f10.txt" ] \
    && [ "$(tail -1 "$TMP/bigout")" = "└───sub" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL: big folder (exit $big_status)"; head -5 "$TMP/bigout"
fi

# A last guard against loops: 64 levels are entered, so a chain of 70
# nested folders shows 65 of them.
deep="$TMP/deep"
mkdir -p "$deep/$(printf 'd/%.0s' $(seq 1 70))"
timeout 20 "$BIN" "$deep" < /dev/null > "$TMP/deepout" 2>&1
if [ "$(wc -l < "$TMP/deepout")" -eq 67 ] && [ "$(tail -1 "$TMP/deepout" | tr -d ' ')" = "└───d" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL: depth guard ($(wc -l < "$TMP/deepout") lines)"
fi

# Errors (ERRORLEVEL 1).
invalid="$(lines "$head_line" "$none")$nl$nl"
check_both "missing folder"       1 "$invalid" $'Invalid path - nosuch\n' nosuch
check_both "missing, backslashes" 1 "$invalid" $'Invalid path - no\\such\n' 'no/such'
check_both "a file"               1 "$invalid" $'Invalid path - notes.txt\n' /F notes.txt
check_both "undeclared /X"        1 "$invalid" $'Invalid path - \\X\n' /X
check_both "dangling link"        1 "$invalid" $'Invalid path - dangling\n' dangling
check_both "too many parameters"  1 '' $'Too many parameters - src\n' docs src

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
