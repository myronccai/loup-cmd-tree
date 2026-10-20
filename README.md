# loup-cmd-tree

The Windows `tree` command recreated in [Loup](https://code-craft.ai/references/loup):
draw the folder structure of a path, optionally with the files of each
folder, in box-drawing or ASCII characters, with tree's layout and
switches, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It shows recursion
with prefix bookkeeping and Unicode versus ASCII rendering. It uses the
shared Windows code in [`source/win/`](source/win/) (switch parser,
wildcard and directory helpers, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.
- `find` (to recognize symbolic links; see below).

## Usage

```sh
make build                    # native binary: build/tree
make ci                       # check, unit tests, build, end-to-end tests
make run ARGS="/F source"     # run from source with loup run
```

Run in this repository:

```text
$ build/tree source
Folder PATH listing
source
├───cli
├───commands
└───win
$ build/tree /F /A source
Folder PATH listing
source
|   appinfo.loup
|   main.loup
|   
+---cli
|       app.loup
|       args.loup
|       usage.loup
|       
+---commands
|       tree.loup
|       
\---win
        messages.loup
        paths.loup
        switches.loup
        wildcard.loup
        
```

In a folder where `src/parent` is a symbolic link to `..` (shown, not
entered):

```text
$ build/tree /F
Folder PATH listing
.
│   README.md
│   
├───docs
│       guide.md
│       
└───src
    │   main.loup
    │   
    └───parent
$ build/tree docs
Folder PATH listing
docs
No subfolders exist

$ build/tree nosuch; echo "ERRORLEVEL $?"
Folder PATH listing
Invalid path - nosuch
No subfolders exist

ERRORLEVEL 1
$ build/tree docs src; echo "ERRORLEVEL $?"
Too many parameters - src
ERRORLEVEL 1
$ build/tree --version
tree (loup-cmd-tree) 0.1.0
```

```text
TREE [path] [/F] [/A]
```

| Argument or switch | Effect |
|---|---|
| `path` | the folder to start from (default: the current directory); `\` or `/` |
| `/F` | also list the files of each folder, before its subfolders |
| `/A` | draw with `+---`, `\---` and `\|` instead of `├───`, `└───` and `│` |
| `/?` | a summary of the syntax and switches |

Switches start with `/` or `-`, in any case, and may come before or after
the path (`/F/A` works too); `--` ends switch parsing. Any other argument
is the path, including a `/X` that is not one of tree's switches, so
`tree /usr/share` works.

Each level is drawn behind its parent's prefix: `│   ` while more
subfolders follow at that level, four spaces after the last one. With
`/F`, a folder's files come first, followed by a line holding only the
prefix (it ends in spaces). Names are sorted as an NTFS listing sorts them
(case-insensitively, `.hidden` < `Alpha` < `b` < `_x`).

Exit status (ERRORLEVEL): `0` for a listing, `1` for an invalid path or too
many parameters.

## Differences from the original

- The header is the single line `Folder PATH listing`: a Linux file system
  has no volume label or Windows volume serial number.
- The root line is the path as typed, with `\` separators (`.` for the
  current directory), not the full upper-case path with a drive letter:
  Linux names are case-sensitive.
- Symbolic links to folders are shown as folders but never entered, since
  they can form loops. Loup 1.26.0 has no `lstat()`, so the links under the
  root are found with one `find -H ROOT -type l` call. The path given may
  itself be a link. As a last guard, the drawing stops descending 64
  levels below the root.
- Linux has no hidden attribute: dot-files and dot-folders are listed.
  Dangling links are left out.
- `Invalid path - X` and `Too many parameters - X` go to standard error;
  ERRORLEVEL 1 for them is this project's choice.
- The output is UTF-8; `/A` gives plain ASCII.
- `/?` prints this project's own short summary of the syntax and switches,
  not Microsoft's help text.
- `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup                # entry point
source/appinfo.loup             # name, version, exit statuses 0/1
source/cli/args.loup            # /F, /A, the path and usage errors via win.switches
source/cli/usage.loup           # /? and --version text
source/cli/app.loup             # run(): parse, run, exit status
source/commands/tree.loup       # glyphs, the recursive drawing, links, output
source/win/                     # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup               # unit tests (make test)
tests/e2e.sh                    # end-to-end tests of build/tree (make e2e)
specs/tree/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
