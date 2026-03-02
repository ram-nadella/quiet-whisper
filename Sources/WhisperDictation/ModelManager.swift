import Foundation

enum WhisperModel: String, CaseIterable, Identifiable, Hashable {
    case tinyEn = "tiny.en"
    case largeTurbo = "large-v3-turbo"

    var id: String { rawValue }

    var filename: String {
        "ggml-\(rawValue).bin"
    }

    var displayName: String {
        switch self {
        case .tinyEn: return "Tiny (Fast)"
        case .largeTurbo: return "Large Turbo"
        }
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }
}

@MainActor
class ModelManager: ObservableObject {
    @Published var availableModels: [WhisperModel] = []
    @Published var selectedModel: WhisperModel = .largeTurbo
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadError: String?

    let modelsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("WhisperDictation/models")
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        refreshAvailableModels()
    }

    func modelPath(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.filename)
    }

    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: model).path)
    }

    func refreshAvailableModels() {
        availableModels = WhisperModel.allCases.filter { isModelDownloaded($0) }
        if !availableModels.contains(selectedModel), let first = availableModels.first {
            selectedModel = first
        }
    }

    func downloadModel(_ model: WhisperModel) async throws {
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        defer {
            isDownloading = false
        }

        let destination = modelPath(for: model)

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

        let (tempURL, response) = try await session.download(from: model.downloadURL, delegate: DownloadDelegate { progress in
            Task { @MainActor in
                self.downloadProgress = progress
            }
        })

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ModelDownloadError.downloadFailed
        }

        try FileManager.default.moveItem(at: tempURL, to: destination)
        refreshAvailableModels()
    }
}

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by the async download call
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress(progress)
        }
    }
}

enum ModelDownloadError: LocalizedError {
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Failed to download model"
        }
    }
}
