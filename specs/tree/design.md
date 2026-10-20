# Design: tree

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser (`win.switches`), handles `/?` and `--version`, and
calls `commands.tree.run_tree(path, files, ascii)`. `run_tree` checks the
path, builds the lines with the pure-ish `tree_lines` and prints them.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses 0 and 1 |
| `source/cli/args.loup` | `Options`, `tree_switches()`, `parse_args`, `msg_too_many` |
| `source/cli/usage.loup` | `usage()` (the `/?` summary), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/tree.loup` | `branch`, `continuation`, `read_folder`, `draw`, `tree_lines`, `subfolder_count`, `root_label`, `run_tree` |
| `source/win/` | the shared Windows code: switches, wildcards (`sort_names`, `symlinks_under`), paths, messages |

### Arguments

`tree_switches()` declares the flags `/F` and `/A`. Every operand is a path
(an undeclared `/X` too, by the series convention); a second one is
`Too many parameters - ARG`. `Options` is built only in `args.loup`
(`make_options`), and `app.loup` passes its fields on as plain values.

### Drawing

`draw(dir, prefix, ...)` is the recursion, with the prefix as its only
state:

1. `read_folder` lists `dir` once, sorts the names with `sort_names`
   (NTFS order) and splits them into subfolders and, for `/F`, files
   (`isDir`/`isFile` follow links; entries that are neither are dropped).
2. With `/F`, each file is printed behind `prefix + continuation(has
   subfolders)`, then that prefix alone.
3. Each subfolder gets `prefix + branch(last)` + its name, then
   `draw(child, prefix + continuation(!last))`, unless the child is a
   symbolic link.

`branch(last, ascii)` is `├───`/`└───` (`+---`/`\---`), and
`continuation(more, ascii)` is `│   ` (`|   `) or four spaces. The lines go
into one list (an `edits` parameter); `run_tree` prints them with one
`join`.

### Symbolic links

Loup 1.26.0 has no `lstat()`, so `tree_lines` calls the shared
`symlinks_under(root)` once: one `find -H ROOT -type l -print0`, giving the
paths of every link as `draw` builds them with `join_path`. A subfolder in
that set is drawn but not entered. `-H` follows the root itself when it is
a link. As a last guard (no `find` on the system, bind-mount loops),
`draw` does not descend more than `MAX_DEPTH` (64) levels.

### Output

`run_tree` prints `Folder PATH listing`, checks `isDir(root)` (`.` when no
path is given), prints the root line (`root_label`: the path as typed, with
`\`), the lines, and `No subfolders exist` plus a blank line when
`subfolder_count(root)` is 0.

## Differences from the original

- The header is the single line `Folder PATH listing`: a Linux file system
  has no volume label or Windows serial number to print.
- The root line is the path as typed with `\` separators (`.` for the
  current directory), not the full upper-case path with a drive letter:
  Linux names are case-sensitive.
- Symbolic links to folders are shown but never entered, and the drawing
  stops descending 64 levels down (a guard against loops).
- Hidden is not an attribute on Linux: dot-files and dot-folders are listed.
- Error messages are modeled on tree's (`Invalid path - X`, `Too many
  parameters - X`) and go to standard error; ERRORLEVEL 1 for them is this
  project's choice.
- Lines are UTF-8; `/A` gives plain ASCII.
- `/?` prints this project's own short summary, not Microsoft's help text.
- `--help` and `--version` (alone) are series conventions.

## Error handling

`parse_args` rejects a second path before anything is printed. An invalid
path is reported after the header. An unexpected exception is printed with
status 1. An unreadable folder lists as empty (native `listDir` returns
`[]`).

## Performance

Natively every intermediate string stays allocated, so the cost per entry
matters: `/usr/share/doc` (17,000 entries, 1,400 links) takes 0.2 s and
28 MB, `/usr/lib` (80,000 entries) about 0.5 s and 100 MB. The shared
`sort_names` used to upper-case inside its comparator (910 MB for
`/usr/share/doc`); it now sorts precomputed keys.

## Testing

- `tests/args_test.loup`: switches in every form, paths, `--`, help,
  version, too many parameters.
- `tests/tree_test.loup`: glyphs, labels, messages, `tree_lines` with and
  without `/F` and `/A` on a tree under `build/tmp/`, and a link loop.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: the native binary on a fixture with NTFS-order names, a
  dot-folder, a non-ASCII name, a link loop, a second link into a folder, a
  file link and a dangling link; every switch form, path forms, no
  subfolders, a 3,000-file folder, and every error. Each run is limited to
  20 seconds.
