# Changelog

## 0.1.1 — 2026-11-12

- Files from Windows with unusual bytes keep every byte when saved.
- Linker warnings no longer count as compile errors.
- `.c` files are compiled as C, so valid C code that isn't valid C++ runs.
- Several messages on one line show as one bubble with "+N"; long messages are shortened to fit.
- Moving the open file to the Trash keeps your last edits.
- After a program ends, typing goes back to the editor.
- No focus ring around the theme and Run buttons.
- New app icon.

## 0.1.0 — 2026-11-12

- Editor for C++ files with syntax highlighting, line numbers, auto-indent and bracket pairing; find and replace with ⌘F.
- Explorer showing the chosen root folder; new file (with a `main` skeleton), new folder, rename, move to Trash; changes on disk appear on their own.
- Run (⌘R) saves, compiles with the system clang and runs the program in a built-in console that behaves like Terminal; input is typed into the console, ⌃D ends it, Stop (⌘.) ends the program.
- Compile errors highlight their line with the compiler's message next to it; console messages jump to their line.
- Four themes: Glass (default, Liquid Glass, follows Light/Dark), Hacker, Synthwave and Cyberpunk.
- Files from Code::Blocks on Windows: Windows-1250 encoding kept, `#include <bits/stdc++.h>` works.
- Opening `.cpp` files or folders from Finder or the Dock; the `cecko` command for Terminal.
- Checks for the C++ compiler at launch and shows how to install it.
- Czech and English, following the macOS language.
