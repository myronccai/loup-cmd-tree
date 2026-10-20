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

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.
- `find` (to recognize symbolic links; see below).

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

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

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
