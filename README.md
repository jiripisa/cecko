# Cecko

A simple C++ editor for students: write code, press Run, done.

Cecko is a small C++ IDE for beginners: an explorer for one folder, an
editor with syntax highlighting, a Run button and a console that behaves like
Terminal. Compile errors show up on their line. Four themes: Glass, Hacker,
Synthwave and Cyberpunk. It uses the system clang (Xcode Command Line Tools).

Native macOS app (SwiftUI, macOS 27 or later), built with Swift Package
Manager and shell scripts; no Xcode project.

Website and manual: https://jiripisa.github.io/cecko/

## Build and run

You need the Xcode command line tools.

```
./run.sh            # debug build, runs in the terminal with logs (Ctrl+C quits)
./run.sh release    # optimized build, opens the app
swift test          # tests
./build.sh dist     # signed, notarized DMG (needs a Developer ID, see development_workflow.md)
```

Details: [development_workflow.md](development_workflow.md).

## License

MIT License, see [LICENSE](LICENSE).
