import CeckoCore
import Foundation
import Observation

/// The file open in the editor. There is no manual saving: edits are written
/// back a second after typing stops, and immediately before Run.
@MainActor
@Observable
final class EditorDocument {

    let url: URL
    private(set) var encoding: SourceEncoding
    /// Bumped when the text is replaced from disk, so the editor reloads it.
    private(set) var reloadToken = 0
    private(set) var saveError: String?

    var text: String {
        didSet {
            guard text != oldValue else { return }
            scheduleAutosave()
        }
    }

    @ObservationIgnored private var savedText: String
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?

    var isDirty: Bool { text != savedText }
    var isRunnable: Bool { FileOperations.isRunnable(url) }
    var isHighlighted: Bool { FileOperations.isHighlighted(url) }

    /// Returns nil for files that are not text (binary data, unreadable).
    init?(url: URL) {
        guard let data = try? Data(contentsOf: url), !data.contains(0) else { return nil }
        let decoded = SourceCodec.decode(data)
        self.url = url
        self.encoding = decoded.encoding
        self.text = decoded.text
        self.savedText = decoded.text
    }

    func saveNow() {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard isDirty else { return }
        do {
            try SourceCodec.encode(text, as: encoding).write(to: url, options: .atomic)
            savedText = text
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// Picks up a change made on disk by another program, unless the student
    /// has unsaved edits (then their version wins at the next save).
    func reloadIfChangedOnDisk() {
        guard !isDirty, let data = try? Data(contentsOf: url), !data.contains(0) else { return }
        let decoded = SourceCodec.decode(data)
        guard decoded.text != savedText else { return }
        encoding = decoded.encoding
        savedText = decoded.text
        text = decoded.text
        reloadToken += 1
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }
}
