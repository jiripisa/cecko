import Foundation
import Testing
@testable import CeckoCore

@Suite("ThemeData")
struct ThemeDataTests {

    @Test("All four themes exist, Glass first")
    func everyThemeExists() {
        #expect(ThemeID.allCases == [.glass, .hacker, .synthwave, .cyberpunk])
        for id in ThemeID.allCases { #expect(ThemeData.named(id).id == id) }
    }

    @Test("Hex colours parse to components")
    func hexParsing() {
        let c = RGBA(hex: "#33ff66")
        #expect(abs(c.r - 0.2) < 0.001)
        #expect(c.g == 1)
        #expect(abs(c.b - 0.4) < 0.001)
        #expect(c.a == 1)
        #expect(RGBA(hex: "FF003C", alpha: 0.18).a == 0.18)
    }

    @Test("Window titles carry the theme's flavour")
    func windowTitles() {
        #expect(ThemeData.named(.hacker).windowTitle(for: "ukoly/hadani.cpp") == "root@cecko:~/ukoly/hadani.cpp")
        #expect(ThemeData.named(.cyberpunk).windowTitle(for: "ukoly/hadani.cpp") == "// HADANI.CPP")
        #expect(ThemeData.named(.glass).windowTitle(for: "ukoly/hadani.cpp") == "hadani.cpp")
        #expect(ThemeData.named(.synthwave).windowTitle(for: "hadani.cpp") == "hadani.cpp")
    }

    @Test("Glass follows the system appearance, the others are dark")
    func glassFollowsSystem() {
        #expect(ThemeData.named(.glass).isDark == nil)
        #expect(ThemeData.named(.glass).appearance(dark: false).colors.editorBackground
                != ThemeData.named(.glass).appearance(dark: true).colors.editorBackground)
        for id in [ThemeID.hacker, .synthwave, .cyberpunk] {
            #expect(ThemeData.named(id).isDark == true)
        }
    }

    @Test("Flavour texts")
    func flavourTexts() {
        #expect(ThemeData.named(.hacker).successMessage == "ACCESS GRANTED_")
        #expect(ThemeData.named(.cyberpunk).successMessage == "// MISSION COMPLETE")
        #expect(ThemeData.named(.glass).successMessage == nil)
        #expect(ThemeData.named(.hacker).runLabel == "[ RUN ]")
        #expect(ThemeData.named(.glass).runLabel == "Run")
        #expect(ThemeData.named(.hacker).usesMonospacedUI)
    }
}

@Suite("CommandLineLauncher")
struct CommandLineLauncherTests {

    @Test("The launcher opens an absolute path in the app and is valid shell")
    func launcherScriptOpensAbsolutePath() throws {
        let script = CommandLineLauncher.script(bundleIdentifier: "io.jp4.cecko")
        #expect(script.hasPrefix("#!/bin/sh\n"))
        #expect(script.contains("open -b io.jp4.cecko"))

        let dir = TempDir()
        let file = dir.file("cecko", script)
        let check = Process()
        check.executableURL = URL(fileURLWithPath: "/bin/sh")
        check.arguments = ["-n", file.path]
        try check.run()
        check.waitUntilExit()
        #expect(check.terminationStatus == 0)
    }

    @Test("The launcher refuses a path that does not exist")
    func launcherRejectsMissingPath() throws {
        let dir = TempDir()
        let file = dir.file("cecko", CommandLineLauncher.script(bundleIdentifier: "io.jp4.cecko"))
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [file.path, dir.url.appendingPathComponent("neni-tu").path]
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        #expect(p.terminationStatus == 1)
    }
}
