# Cecko — a beginner C++ IDE for macOS (design)

Date: 2026-11-12 · Status: draft for approval · Working name: **Cecko** (final name is chosen when the project is scaffolded)

## 1. Intent

A father is building a small, beautiful C++ editor for his son, a first-year high-school computer-science student who is just starting to learn C++ on a MacBook Air (macOS 27 "Golden Gate"). The teacher and most classmates use Code::Blocks on Windows, but students may use any IDE. Classmates with a Mac should be able to download the app from a GitHub Pages website.

**What success looks like for the students:** it is simple (write code, see syntax highlighting, press Run, the program runs and you can type input), it looks great, and the themes — especially *Hacker* — make them feel like IT experts. **For the author:** the pride of having built his son's own learning IDE.

A student who opens the app for the first time must be able to run their first program within a minute, without reading any documentation.

## 2. Goals, non-goals, anti-goals

**Goals**
- One-window editor for C++ source files with syntax highlighting.
- A Run button that saves, compiles and runs the open file, with an interactive console (stdout + stdin) inside the window.
- Compile errors shown on the offending line with the compiler's original (English) message.
- A file explorer showing the chosen root folder.
- Four visual themes, a modern native macOS look (Liquid Glass).
- Signed, notarized DMG downloadable from a GitHub Pages site.

**Non-goals (v1)**
- Debugger, code completion / IntelliSense, multiple editor tabs, project files or build-system configuration, plugins, git integration.
- Windows/Linux versions, Mac App Store.
- Translating or explaining compiler errors (the original English message is enough — user's decision).
- Multi-file programs (see §6 "Future").

**Anti-goals** — the app fails even if it technically works when:
- a beginner has to configure anything (compiler paths, flags, project settings) before the first Run;
- a program behaves differently than in a real terminal (e.g. a prompt without a newline does not appear before the program waits for input);
- code from the teacher's Windows/Code::Blocks setup fails for Mac-specific reasons the student cannot understand.

## 3. Constraints

- **Platform:** macOS 27 Golden Gate only (user's decision). Use the newest native UI components, Liquid Glass included, without compatibility fallbacks for older macOS.
- **Stack:** native Swift + SwiftUI app, built with the `new-macos-app` skill pipeline: Swift Package Manager (no Xcode project), `build.sh` / `run.sh`, Developer ID signed and notarized DMG, GitHub repo, GitHub Pages website with a manual. Repo visibility, license, website languages and Sparkle auto-update are asked by that skill when scaffolding.
- **Distribution outside the App Store**, so the app is not sandboxed (it must run the system compiler and the student's programs and read any folder the user picks).
- **Compiler:** the commonly available system compiler — Apple clang from Xcode or the Command Line Tools. No bundled compiler.
- **App language:** Czech and English, following the macOS system language (user's decision). Code, identifiers and repo files are English.

## 4. What was decided (by the user)

1. Simple editor with C++ syntax highlighting; **Run** button; **Explorer** on the side.
2. Explorer shows the **root folder**. The root folder is chosen on first launch, by opening the app from a terminal in a directory, or via a menu item *Change Root Folder…*. On later launches the last root folder opens.
3. Program I/O happens in a **console panel at the bottom of the window** (user accepted the layout mockup; either an external terminal or a built-in console was acceptable to them).
4. On a compile error: the **error line is highlighted** and the **original English compiler message** is shown nicely next to it.
5. **Themes:** all four proposed themes are in (see §5.5). Hacker matters most to the user.
6. On launch, **verify that a compiler is available**; if not, show how to install it.
7. **Single-file programs** for now (one `.cpp` with `main`); multi-file may come soon.
8. Download page on **GitHub Pages** for classmates.
9. UI language follows macOS: **Czech and English**.

The behaviour described in §5 was played back to the user and approved ("sedí to"); items marked *(my call)* were proposed by Claude and accepted as part of that playback.

## 5. Behaviour

### 5.1 Window layout
```
┌──────────────────────────────────────────────────────┐
│ ● ● ●            soucet.cpp                 ▶ Run    │  toolbar
├────────────┬─────────────────────────────────────────┤
│ EXPLORER   │  1  #include <iostream>                 │
│ ▾ ukoly    │  2  using namespace std;                │
│   domaci/  │  …                                      │  editor
│   soucet.. │  7  cin >> a >> b   ⟵ expected ';' …    │
│   prumer.. ├─────────────────────────────────────────┤
│            │  CONSOLE                                │
│            │  Zadej dve cisla: 5 7                   │  console
│            │  Soucet je 12                           │
│            │  ✓ Program finished                     │
└────────────┴─────────────────────────────────────────┘
```
Explorer sidebar on the left, editor in the middle, console at the bottom, Run in the toolbar. The mockup the user approved is `2026-11-12-cecko-mockup.html` next to this file (an HTML fragment from the brainstorming companion; open it in a browser). Its top half shows the layout in Glass (running and error states), the bottom half the four themes.

### 5.2 Root folder
- First launch with no stored folder → a welcome screen asks the user to choose a folder.
- *Change Root Folder…* in the menu.
- Command-line launcher, e.g. `cecko .` or `cecko ~/ukoly`, opens the app with that folder as root *(my call: the app offers to install the command; how it is installed is the builder's choice, but it must not require the student to edit shell config by hand)*.
- The last root folder is remembered and reopened. If it no longer exists, fall back to the welcome screen.
- **Opening a file from outside the root** (Finder "Open With", drag onto the Dock icon or the window) *(my call)*: the file's folder becomes the root folder and the file opens. The app declares C/C++ files as an *alternate* handler, so it appears in "Open With" but never takes over the default app for `.cpp` files. Dropping a folder makes it the root.

### 5.3 Explorer *(my call)*
- Tree of files and subfolders of the root folder; refreshes automatically when files change on disk.
- Create file, create folder, rename, delete (to Trash).
- A new `.cpp` file starts with a minimal skeleton (`#include <iostream>`, `using namespace std;`, `int main() { … return 0; }`).
- Selecting a file opens it in the editor (one open file at a time).

### 5.4 Editor *(my call)*
- C++ syntax highlighting (keywords, types, strings, chars, numbers, comments, preprocessor), line numbers.
- Auto-indent, auto-closing brackets and quotes, find & replace (⌘F).
- No manual saving: autosave on every Run and continuously while typing (debounced). Undo works as usual.
- Opens and edits any text file in the root folder; highlighting only for C/C++ files (`.cpp`, `.cc`, `.cxx`, `.c`, `.h`, `.hpp`).
- **File encoding:** detect UTF-8 vs. Windows-1250 (Czech Code::Blocks default) on open so Czech diacritics display correctly, and save back in the encoding the file had *(my call)*.

### 5.5 Themes
All four are in v1; **Glass** is the default. The theme can be switched from the menu / toolbar and is remembered.

| Theme | Look | Flavour |
|---|---|---|
| **Glass** | Light, clean macOS look with Liquid Glass and translucent panels; Xcode-like syntax colours | default |
| **Hacker** | Black background, green phosphor monospace text with glow, subtle CRT scanlines | toolbar title like `root@cecko:~/ukoly/hadani.cpp`, `[ RUN ]`, success line `ACCESS GRANTED_` |
| **Synthwave** | 80s retro: deep purple dusk gradient, neon pink and cyan, glowing Run button | — |
| **Cyberpunk** | Black with sharp yellow and cyan, cut corners, sci-fi HUD feel | `// MISSION COMPLETE` |

A theme styles the whole window: sidebar, editor, syntax colours, console, Run button and error highlight. The flavour texts are part of the theme's character and stay English in both languages *(my call)*.

**How themes are built** *(my call, settled after the builder check)*:
- All themes keep the same native window structure: the system window frame, the unified toolbar and a split view with the sidebar. No custom title bar.
- **Glass** uses the native Liquid Glass materials and the system sidebar look, and **follows the system Light/Dark appearance** with an Xcode-like light and dark syntax palette.
- **Hacker, Synthwave, Cyberpunk** force the dark appearance and paint their own backgrounds over the sidebar, editor and console (the system sidebar material is hidden), use their own fonts/colours and their own Run button style. Effects (Hacker scanlines and glow, Synthwave gradient, Cyberpunk cut corners) apply to the content areas — sidebar, editor, console — not to the system toolbar, which stays native and only gets the theme's accent colour.
- The welcome screen and the "compiler missing" screen use the active theme too.

### 5.6 Run (⌘R)
1. Save the open file.
2. Compile it with the system clang++ into a temporary location (not into the student's folder) *(my call)*. Language standard: a modern C++ standard (C++20 or similar) chosen by the builder; warnings are shown but do not block running.
3. On success, run the program in the console. While running, **Run turns into Stop**; Stop kills the program (infinite loops are common for beginners).
4. The program must behave as in a real terminal: output appears immediately, a prompt without a newline is visible before input is requested, `printf`/`scanf` work too. Console input is typed directly into the console panel.
5. When the program ends, show a clear status line: finished normally, finished with a non-zero exit code, or crashed (e.g. "Program crashed: segmentation fault") — in the app's language.
6. Running Run again while a program runs stops the old one first.
7. Only C/C++ source files can be run; for other files Run is disabled.

### 5.7 Compile errors
- Highlight each error line in the editor and show the compiler's original English message next to it (inline bubble).
- The console shows a summary ("Compilation failed, 1 error") and the list of errors; clicking an error jumps to its line.
- Warnings are shown the same way in a softer (warning) colour.

### 5.8 Windows / Code::Blocks compatibility *(my call)*
Code from the teacher and classmates must run unchanged where reasonable:
- `#include <bits/stdc++.h>` (GCC-only header, missing in clang) works — the app supplies a compatible header automatically.
- Windows-1250 encoded files display and save correctly (§5.4).
- Other Windows-only things (`system("pause")`, `<conio.h>`, `<windows.h>`) are out of scope for v1; the builder may add cheap shims if they are trivial, but nothing is promised.

### 5.9 Compiler check
- On launch, check that the system C++ compiler is available.
- If it is missing, show a friendly screen with a short explanation and a button that starts Apple's Command Line Tools installer (`xcode-select --install`), plus a "Check again" button. The editor is still usable meanwhile; Run is disabled with an explanation.

## 6. Future (design for it, don't build it)
- **"Folder = one program" mode:** Run compiles all `.cpp` files of the folder together. v1 should keep the compile step behind an abstraction (input = list of sources) so this mode is an addition, not a rewrite.

## 7. Left to the builder
- Text engine for the editor (e.g. `NSTextView` wrapped for SwiftUI vs. SwiftUI's own rich-text editing) and the highlighting approach (a hand-written C++ tokenizer is enough; avoid heavy dependencies).
- How the console is implemented (a pseudo-terminal is the expected way to satisfy §5.6/4).
- Exact C++ standard flag and warning flags.
- How the command-line launcher is installed (§5.2).
- Keyboard shortcuts beyond ⌘R and ⌘F, menu structure, sizes and spacing.
- Test strategy details, following the `new-macos-app` skeleton (tokenizer, diagnostics parsing, encoding detection and the compile/run pipeline are the obvious unit-test targets).

## 8. Open items for the scaffolding step
Asked by the `new-macos-app` skill, not decided yet: final app name and bundle ID, repo visibility, license, website languages (EN + CS is the natural fit), Sparkle auto-update, project location.
