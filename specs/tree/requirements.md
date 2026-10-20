# Requirements: tree

## Introduction

`tree` is the Windows command that draws the folder structure of a path,
optionally with the files in each folder. This repository recreates it in
Loup for Linux, with its switches, layout, messages and the Windows
conventions from the shared code in `source/win/` (master copy:
loup-cmd-type).

## Requirements

### Requirement 1: Drawing

**User Story:** As a cmd user, I want to see the folders below a path as a
tree.

#### Acceptance Criteria

1. THE program SHALL print `Folder PATH listing`, then the root line: `.`
   for the current directory, or the path as given with `\` separators.
2. FOR each folder, THE program SHALL print one line per subfolder, sorted
   as an NTFS listing sorts names: `├───name` for every subfolder but the
   last and `└───name` for the last, each followed by that subfolder's own
   lines (depth first).
3. THE lines below a subfolder SHALL start with the parent's prefix plus
   `│   ` when more subfolders follow it at that level, or four spaces when
   it is the last.
4. WHEN `/F` is given, THE program SHALL print a folder's files (sorted)
   before its subfolders, each behind the prefix plus `│   ` (if the folder
   has subfolders) or four spaces, followed by one line holding only that
   prefix.
5. WHEN `/A` is given, THE program SHALL draw `+---`, `\---` and `|` instead
   of `├───`, `└───` and `│`.
6. WHEN the root has no subfolders, THE program SHALL end with
   `No subfolders exist` and a blank line.
7. THE program SHALL show hidden (dot) entries like any other, and leave out
   entries that are neither files nor folders (dangling links).

### Requirement 2: Symbolic links

**User Story:** As a user with linked folders, I want tree to finish.

#### Acceptance Criteria

1. THE program SHALL show a symbolic link to a folder as a folder, and
   SHALL NOT descend into it, so that link loops cannot make it run for ever.
2. WHEN the path given is itself a link to a folder, THE program SHALL list
   that folder.
3. WITH `/F`, THE program SHALL list links to files as files.

### Requirement 3: Arguments and errors

**User Story:** As a cmd user, I want tree's command line.

#### Acceptance Criteria

1. THE program SHALL accept `/F` and `/A` with `/` or `-`, in any case, in
   any position, also as `/F/A`; `--` ends switch parsing; any other
   argument (including an undeclared `/X`) is the path, with `\` or `/`.
2. WHEN `/?` (or `-?`, `--help` alone) is given, THE program SHALL print a
   short summary of the syntax and switches and exit with status 0;
   `--version` alone SHALL print `tree (loup-cmd-tree) 0.1.0`.
3. WHEN more than one path is given, THE program SHALL print `Too many
   parameters - ARG` (the second path) on standard error and exit with
   status 1.
4. WHEN the path is not a folder, THE program SHALL print the header,
   `Invalid path - PATH` on standard error, `No subfolders exist` and a
   blank line, and exit with status 1.
5. OTHERWISE THE program SHALL exit with status 0.
