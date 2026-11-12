import AppKit
import SwiftUI
import CeckoCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text(CeckoCore.greeting(appName: "Cecko"))
                .font(.title)
            Text("A simple, good-looking C++ editor for students: write code, press Run, done.")
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 640, minHeight: 400)
    }
}
