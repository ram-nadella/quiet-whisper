import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var audioCapture = AudioCapture()
    @StateObject private var modelManager = ModelManager()
    private let whisperBridge = WhisperBridge.shared
    @State private var transcript = ""
    @StateObject private var editorState = TranscriptEditorState()
    @State private var isTranscribing = false
    @State private var isModelLoaded = false
    @State private var isLoadingModel = false
    @State private var statusMessage = "Loading model..."
    @State private var showDownloadView = false
    @State private var ctrlHeld = false
    @State private var keyDownMonitor: Any?
    @State private var keyUpMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            // Transcript area
            TranscriptEditor(text: $transcript, editorState: editorState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Bottom bar
            HStack(spacing: 16) {
                // Model picker
                Picker("", selection: $modelManager.selectedModel) {
                    ForEach(modelManager.availableModels) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                .onChange(of: modelManager.selectedModel) { _, newModel in
                    loadModel(newModel)
                }

                Spacer()

                // Status indicator
                if isLoadingModel {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if isTranscribing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Record button
                RecordButton(
                    isRecording: audioCapture.isRecording,
                    isEnabled: isModelLoaded && !isTranscribing
                ) {
                    startRecording()
                } onRelease: {
                    stopAndTranscribe()
                }

                Spacer()

                // Copy button
                ToolbarIconButton(
                    icon: "doc.on.doc",
                    help: "Copy transcript",
                    isEnabled: !transcript.isEmpty
                ) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript, forType: .string)
                }

                // Clear button
                ToolbarIconButton(
                    icon: "trash",
                    help: "Clear transcript",
                    isEnabled: !transcript.isEmpty
                ) {
                    transcript = ""
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: NSColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1)))
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if modelManager.availableModels.isEmpty {
                showDownloadView = true
            } else {
                loadModel(modelManager.selectedModel)
            }
            installKeyMonitors()
        }
        .onDisappear {
            removeKeyMonitors()
        }
        .sheet(isPresented: $showDownloadView) {
            DownloadModelView(modelManager: modelManager, initialModel: modelManager.selectedModel) { downloaded in
                showDownloadView = false
                modelManager.selectedModel = downloaded
                loadModel(downloaded)
            }
        }
    }

    private func loadModel(_ model: WhisperModel) {
        isLoadingModel = true
        isModelLoaded = false
        statusMessage = "Loading \(model.displayName)..."

        let bridge = whisperBridge
        let path = modelManager.modelPath(for: model).path
        Task.detached(priority: .userInitiated) {
            do {
                try bridge.loadModel(path: path)
                await MainActor.run {
                    isModelLoaded = true
                    isLoadingModel = false
                    statusMessage = ""
                }
            } catch {
                await MainActor.run {
                    isLoadingModel = false
                    statusMessage = "Failed to load model"
                }
            }
        }
    }

    private func startRecording() {
        do {
            try audioCapture.startRecording()
        } catch {
            statusMessage = "Mic error: \(error.localizedDescription)"
        }
    }

    private func stopAndTranscribe() {
        let samples = audioCapture.stopRecording()
        guard !samples.isEmpty else { return }

        // Require at least 0.5s of audio
        guard samples.count > 8000 else {
            statusMessage = "Recording too short"
            return
        }

        isTranscribing = true
        let bridge = whisperBridge
        Task.detached(priority: .userInitiated) {
            let text = bridge.transcribe(samples: samples)
            await MainActor.run {
                if !text.isEmpty {
                    editorState.insertAtCursor(text)
                }
                isTranscribing = false
            }
        }
    }

    // MARK: - Ctrl hold-to-record

    private func installKeyMonitors() {
        // flagsChanged fires on modifier key press/release
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let ctrlNow = event.modifierFlags.contains(.control)
            let canRecord = isModelLoaded && !isTranscribing
            if ctrlNow && !ctrlHeld && canRecord {
                ctrlHeld = true
                startRecording()
            } else if !ctrlNow && ctrlHeld {
                ctrlHeld = false
                stopAndTranscribe()
            }
            return event
        }
    }

    private func removeKeyMonitors() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m); keyUpMonitor = nil }
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let help: String
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundColor(foregroundColor)
            .frame(width: 32, height: 32)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .opacity(isEnabled ? 1.0 : 0.35)
            .help(help)
            .onHover { hovering in
                isHovering = hovering && isEnabled
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        isPressed = true
                    }
                    .onEnded { _ in
                        if isPressed && isEnabled {
                            action()
                        }
                        isPressed = false
                    }
            )
    }

    private var foregroundColor: Color {
        if isPressed && isEnabled {
            return Color(nsColor: .controlTextColor)
        }
        if isHovering {
            return Color(nsColor: .controlTextColor)
        }
        return .secondary
    }

    private var backgroundColor: Color {
        if isPressed && isEnabled {
            return Color.gray.opacity(0.25)
        }
        if isHovering {
            return Color.gray.opacity(0.12)
        }
        return .clear
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false
    @State private var isHovering = false

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "mic.fill")
                    .foregroundColor(iconColor)
                    .font(.system(size: 22))
            )
            .overlay(
                Circle()
                    .strokeBorder(borderColor, lineWidth: isHovering && !isRecording ? 2 : 0)
            )
            .scaleEffect(isRecording ? 1.12 : (isPressed ? 0.92 : (isHovering ? 1.06 : 1.0)))
            .shadow(color: isRecording ? Color.red.opacity(0.4) : .clear, radius: isRecording ? 10 : 0)
            .animation(.easeInOut(duration: 0.15), value: isRecording)
            .animation(.easeInOut(duration: 0.12), value: isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .opacity(isEnabled ? 1.0 : 0.4)
            .onHover { hovering in
                isHovering = hovering
                if isEnabled {
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        isPressed = true
                        onPress()
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        onRelease()
                    }
            )
    }

    private var fillColor: Color {
        if isRecording {
            return Color.red.opacity(0.8)
        }
        if isPressed {
            return Color.gray.opacity(0.3)
        }
        if isHovering && isEnabled {
            return Color.gray.opacity(0.22)
        }
        return Color.gray.opacity(0.15)
    }

    private var iconColor: Color {
        if isRecording {
            return .white
        }
        if isHovering && isEnabled {
            return Color(nsColor: .darkGray)
        }
        return .gray
    }

    private var borderColor: Color {
        if isEnabled {
            return Color.gray.opacity(0.3)
        }
        return .clear
    }
}

// MARK: - Editable transcript view backed by NSTextView

/// Manages the NSTextView instance so ContentView can insert text at the cursor.
@MainActor
class TranscriptEditorState: ObservableObject {
    weak var textView: NSTextView?

    /// Insert text at the current cursor position, or at the end if the text view
    /// isn't focused / has no selection.
    func insertAtCursor(_ newText: String) {
        guard let textView = textView else { return }

        let storage = textView.textStorage!
        let total = storage.length

        // Determine insertion point: use cursor if the text view is first responder,
        // otherwise append at the end.
        let insertionLocation: Int
        if textView.window?.firstResponder === textView {
            insertionLocation = textView.selectedRange().location
        } else {
            insertionLocation = total
        }

        // Add a newline separator if we're inserting into existing text and
        // there isn't already a newline right before the insertion point.
        var prefix = ""
        if insertionLocation > 0 {
            let prior = (storage.string as NSString).character(at: insertionLocation - 1)
            if prior != 0x0A { // \n
                prefix = "\n"
            }
        }

        let toInsert = prefix + newText
        let insertRange = NSRange(location: insertionLocation, length: 0)

        // Use NSTextStorage so it's undo-able and triggers delegate
        storage.beginEditing()
        storage.replaceCharacters(in: insertRange, with: toInsert)
        // Reapply font/color to the inserted range (plain text storage resets attributes)
        let insertedRange = NSRange(location: insertionLocation, length: (toInsert as NSString).length)
        storage.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        ], range: insertedRange)
        storage.endEditing()

        // Move cursor to end of inserted text
        let newCursorPos = insertionLocation + (toInsert as NSString).length
        textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
        textView.scrollRangeToVisible(NSRange(location: newCursorPos, length: 0))

        // Notify the delegate so the binding stays in sync
        textView.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: textView))
    }
}

struct TranscriptEditor: NSViewRepresentable {
    @Binding var text: String
    var editorState: TranscriptEditorState

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 32, height: 32)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        textView.insertionPointColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
        editorState.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if the text actually changed from outside (not from user typing)
        if textView.string != text {
            let wasAtBottom = isScrolledToBottom(scrollView)
            let selectedRange = textView.selectedRange()
            textView.string = text
            if selectedRange.location + selectedRange.length <= text.utf16.count {
                textView.setSelectedRange(selectedRange)
            }
            if wasAtBottom {
                textView.scrollToEndOfDocument(nil)
            }
        }

        context.coordinator.updatePlaceholder(textView)
    }

    private func isScrolledToBottom(_ scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return true }
        let visibleRect = scrollView.contentView.bounds
        let documentHeight = documentView.frame.height
        return visibleRect.maxY >= documentHeight - 20
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranscriptEditor
        weak var textView: NSTextView?
        private var placeholderView: NSTextField?

        init(_ parent: TranscriptEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updatePlaceholder(textView)
        }

        func updatePlaceholder(_ textView: NSTextView) {
            if textView.string.isEmpty {
                if placeholderView == nil {
                    let label = NSTextField(labelWithString: "Hold the button and speak...")
                    label.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
                    label.textColor = NSColor.gray.withAlphaComponent(0.4)
                    label.isEditable = false
                    label.isBordered = false
                    label.drawsBackground = false
                    label.translatesAutoresizingMaskIntoConstraints = false
                    textView.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 32),
                        label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 37),
                    ])
                    placeholderView = label
                }
                placeholderView?.isHidden = false
            } else {
                placeholderView?.isHidden = true
            }
        }
    }
}

struct DownloadModelView: View {
    @ObservedObject var modelManager: ModelManager
    let initialModel: WhisperModel
    let onDone: (WhisperModel) -> Void
    @State private var selectedDownload: WhisperModel = .largeTurbo

    var body: some View {
        VStack(spacing: 20) {
            Text("Download a Model")
                .font(.headline)

            Text("Select a model to download.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Picker("Model", selection: $selectedDownload) {
                ForEach(WhisperModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            if modelManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: modelManager.downloadProgress)
                        .frame(width: 300)
                    Text("\(Int(modelManager.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = modelManager.downloadError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                if modelManager.isModelDownloaded(selectedDownload) {
                    Button("Use This Model") {
                        modelManager.refreshAvailableModels()
                        onDone(selectedDownload)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Download (~1.5 GB)") {
                        Task {
                            do {
                                try await modelManager.downloadModel(selectedDownload)
                            } catch {
                                modelManager.downloadError = error.localizedDescription
                            }
                        }
                    }
                    .disabled(modelManager.isDownloading)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(30)
        .frame(width: 400)
        .onAppear {
            selectedDownload = initialModel
        }
    }
}
