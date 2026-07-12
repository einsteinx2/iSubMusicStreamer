//
//  StreamHandler.swift
//  iSub
//
//  Created by Benjamin Baron on 1/22/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import CocoaLumberjackSwift
import CwlCatchException

private let isProgressLoggingEnabled = false
private let isThrottleLoggingEnabled = true
private let isSpeedLoggingEnabled = false

protocol StreamHandlerDelegate: AnyObject {
    func streamHandlerStarted(handler: StreamHandler)
    func streamHandlerStartPlayback(handler: StreamHandler)
    func streamHandlerConnectionFinished(handler: StreamHandler)
    func streamHandlerConnectionFailed(handler: StreamHandler, error: Error)
}

// TODO: implement this - refactor to clean up the code
final class StreamHandler: NSObject, Codable {
    // Everything a handler needs from the outside, passed at creation (or via
    // decoder.userInfo on the Codable path) instead of resolved ambiently
    struct Dependencies {
        let downloadsManager: DownloadsManager
        let settings: SavedSettings
        let store: Store
        let player: PlayerControlling
        let networkStatus: NetworkStatus

        // Transitional bridge for creators that are not yet constructor-converted
        // (StreamManager/DownloadQueue, until Phase 5a) and for tests; resolves from
        // the container at handler-creation time
        static func fromResolver() -> Dependencies {
            Dependencies(downloadsManager: Resolver.resolve(),
                         settings: Resolver.resolve(),
                         store: Resolver.resolve(),
                         player: Resolver.resolve(),
                         networkStatus: Resolver.resolve())
        }
    }

    private enum CodingKeys: String, CodingKey {
        case serverId, songId, byteOffset, secondsOffset, isDelegateNotifiedToStartPlayback, isTempCache, isDownloading, contentLength, maxBitrateSetting
    }

    private let downloadsManager: DownloadsManager
    private let settings: SavedSettings
    private let store: Store
    private let player: PlayerControlling
    private let networkStatus: NetworkStatus

    // Weak: the delegate (StreamManager/DownloadQueue) owns the handler, so a strong
    // reference here is a retain cycle that keeps replaced queues alive forever
    weak var delegate: StreamHandlerDelegate?
    
    let song: Song
    private(set) var byteOffset: Int
    private(set) var secondsOffset: Double
    let isTempCache: Bool
    
    private(set) var isDelegateNotifiedToStartPlayback = false
    private(set) var isDownloading = false
    private(set) var totalBytesTransferred = 0
    var numberOfReconnects = 0
    private(set) var recentDownloadSpeedInBytesPerSec = 0
    // Number of times the transfer was delayed by throttling (exposed for tests)
    private(set) var throttleCount = 0
    
    private lazy var session: URLSession = {
        let configuration = APIURLSession.ephemeralConfiguration()
        configuration.networkServiceType = .avStreaming
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    private var request: URLRequest?
    private var dataTask: URLSessionDataTask?
    private var fileHandle: FileHandle?
    
    private var contentLength: Int?
    private var maxBitrateSetting: Int?
    private var bytesTransfered = 0
    private var kiloBitrate = 0
    private var speedLoggingDate = Date()
    private var speedLoggingLastSize = 0
    private var throttlingDate = Date()
    private var numberOfContentLengthFailures = 0
    
    var filePath: String { isTempCache ? song.localTempPath : song.localPath }
    
    init(song: Song, byteOffset: Int = 0, secondsOffset: Double = 0.0, tempCache: Bool, delegate: StreamHandlerDelegate, dependencies: Dependencies) {
        self.song = song
        self.byteOffset = byteOffset
        self.secondsOffset = secondsOffset
        self.isTempCache = tempCache
        self.delegate = delegate
        self.downloadsManager = dependencies.downloadsManager
        self.settings = dependencies.settings
        self.store = dependencies.store
        self.player = dependencies.player
        self.networkStatus = dependencies.networkStatus
        super.init()
    }

    // Custom implementation to prevent storing Song objects directly to allow for easier changes to Song model
    init(from decoder: Decoder) throws {
        guard let dependencies = decoder.userInfo[.streamHandlerDependencies] as? Dependencies else {
            throw RuntimeError(message: "Error decoding StreamHandler, Dependencies missing from decoder userInfo (set by StreamManager.loadHandlerStack)")
        }
        self.downloadsManager = dependencies.downloadsManager
        self.settings = dependencies.settings
        self.store = dependencies.store
        self.player = dependencies.player
        self.networkStatus = dependencies.networkStatus

        let values = try decoder.container(keyedBy: CodingKeys.self)
        let serverId: Int = try values.decode(forKey: .serverId)
        let songId: String = try values.decode(forKey: .songId)
        guard let song = dependencies.store.song(serverId: serverId, id: songId) else {
            throw RuntimeError(message: "Error decoding StreamHandler, Song doesn't exist for serverId \(serverId) and songId \(songId)")
        }
        self.song = song
        self.byteOffset = try values.decode(forKey: .byteOffset)
        self.secondsOffset = try values.decode(forKey: .secondsOffset)
        self.isDelegateNotifiedToStartPlayback = try values.decode(forKey: .isDelegateNotifiedToStartPlayback)
        self.isTempCache = try values.decode(forKey: .isTempCache)
        self.isDownloading = try values.decode(forKey: .isDownloading)
        self.contentLength = try values.decodeIfPresent(forKey: .contentLength)
        self.maxBitrateSetting = try values.decodeIfPresent(forKey: .maxBitrateSetting)
        super.init()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(song.serverId, forKey: .serverId)
        try container.encode(song.id, forKey: .songId)
        try container.encode(byteOffset, forKey: .byteOffset)
        try container.encode(secondsOffset, forKey: .secondsOffset)
        try container.encode(isDelegateNotifiedToStartPlayback, forKey: .isDelegateNotifiedToStartPlayback)
        try container.encode(isTempCache, forKey: .isTempCache)
        try container.encode(isDownloading, forKey: .isDownloading)
        try container.encodeIfPresent(contentLength, forKey: .contentLength)
        try container.encodeIfPresent(maxBitrateSetting, forKey: .maxBitrateSetting)
    }
    
    // TODO: implement this - refactor for better error handling
    func start(resume: Bool = false) {
        guard !isDownloading else { return }
        
        isDownloading = true
        
        // Clear temp cache if this is a temp file and we're not resuming
        if !resume && isTempCache {
            downloadsManager.clearTempCache()
        }
        
        if Debug.streamManager {
            DDLogInfo("[StreamHandler] \(super.description) start(resume: \(resume) for: \(song)")
        }
        
        totalBytesTransferred = 0
        bytesTransfered = 0
        
        // Create the file handle
        fileHandle = FileHandle(forWritingAtPath: filePath)
        if let fileHandle = fileHandle {
            if (resume) {
                // File exists so seek to end
                do {
                    let endOfFile = try fileHandle.seekToEnd()
                    totalBytesTransferred = Int(endOfFile)
                    byteOffset += totalBytesTransferred
                } catch {
                    DDLogError("[StreamHandler] Failed to seek to end existing file \(filePath), error: \(error)")
                }
            } else {
                // File exists so remove it
                do {
                    try fileHandle.close()
                } catch {
                    DDLogError("[StreamHandler] Failed to close file handle for existing file \(filePath)")
                }
                self.fileHandle = nil
                do {
                    try FileManager.default.removeItem(atPath: filePath)
                } catch {
                    DDLogError("[StreamHandler] Failed to delete existing file \(filePath), error: \(error)")
                    isDownloading = false
                    delegate?.streamHandlerConnectionFailed(handler: self, error: APIError.filesystem)
                    return
                }
            }
        }
        
        // No usable file handle at this point means the file doesn't exist yet — either
        // a fresh start, or a resume whose partial file is missing (handler never
        // started, or the file was evicted between sessions). Create it and download
        // from the requested byteOffset rather than failing on the first data callback.
        if fileHandle == nil {
            // Create intermediary directory if needed
            let containingDirectory = (filePath as NSString).deletingLastPathComponent
            if !FileManager.default.fileExists(atPath: containingDirectory) {
                do {
                    try FileManager.default.createDirectory(atPath: containingDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DDLogError("[StreamHandler] Failed to create containing directory \(containingDirectory), error: \(error)")
                    isDownloading = false
                    delegate?.streamHandlerConnectionFailed(handler: self, error: APIError.filesystem)
                    return
                }
            }
            
            // Create the file
            do {
                try Data().write(to: URL(fileURLWithPath: filePath), options: [])
            } catch {
                DDLogError("[StreamHandler] Failed to create file \(filePath), error: \(error)")
                isDownloading = false
                delegate?.streamHandlerConnectionFailed(handler: self, error: APIError.filesystem)
                return
            }
            fileHandle = FileHandle(forWritingAtPath: filePath)
            if fileHandle == nil {
                DDLogError("[StreamHandler] Failed to create file handle for file \(filePath)")
                isDownloading = false
                delegate?.streamHandlerConnectionFailed(handler: self, error: APIError.filesystem)
                return
            }

            // New files never inherit the backup-exclusion flag, so apply the user's
            // setting to each freshly created download file
            var fileURL = URL(fileURLWithPath: filePath)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = !settings.isBackupCacheEnabled
            do {
                try fileURL.setResourceValues(resourceValues)
            } catch {
                DDLogError("[StreamHandler] Failed to set backup exclusion on \(filePath), error: \(error)")
            }
        }
            
        // TODO: implement this - Make sure that sending estimateContentLength as a bool instead of a string works
        var parameters: [String: Any] = ["id": song.id, "estimateContentLength": true]
        if maxBitrateSetting == nil {
            maxBitrateSetting = settings.currentMaxBitrate
        }
        if let maxBitrateSetting = maxBitrateSetting, maxBitrateSetting != 0 {
            parameters["maxBitRate"] = maxBitrateSetting
        }
        
        request = URLRequest(serverId: song.serverId, subsonicAction: .stream, parameters: parameters, byteOffset: byteOffset)
        guard let request else {
            DDLogError("[StreamHandler] start connection failed to create request")
            isDownloading = false
            delegate?.streamHandlerConnectionFailed(handler: self, error: APIError.requestCreation)
            return
        }
        
        kiloBitrate = song.estimatedKiloBitrate
        
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
        if Debug.streamManager {
            DDLogInfo("[StreamHandler] \(super.description) Stream handler connection started successfully for \(song)")
        }
        
        if !isTempCache {
            // TODO: implement this - error handling
            _ = store.add(downloadedSong: DownloadedSong(song: song))
        }
        
        DispatchQueue.main.async {
            self.delegate?.streamHandlerStarted(handler: self)
        }
    }
    
    func cancel() {
        isDownloading = false
        
        if let dataTask = dataTask {
            if Debug.streamManager {
                DDLogInfo("[StreamHandler] Stream handler request canceled for \(song)")
            }
            dataTask.cancel()
            self.dataTask = nil
        }
        
        // Close the file handle
        do {
            try fileHandle?.close()
        } catch {
            DDLogError("[StreamHandler] Error closing file handle for \(song)")
        }
        fileHandle = nil
    }
    
    // MARK: Equality
    
    override var hash: Int { song.serverId | song.id.hash }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? StreamHandler {
            return song == object.song
        }
        return false
    }
    
    override var description: String { "\(super.description): for \(song)" }
}

extension CodingUserInfoKey {
    // Carries StreamHandler.Dependencies through JSONDecoder when rehydrating the
    // persisted handler stack (see StreamManager.loadHandlerStack)
    static let streamHandlerDependencies = CodingUserInfoKey(rawValue: "streamHandlerDependencies")!
}

extension StreamHandler {
    /// Validates a finished download (shared by StreamManager and DownloadQueue): an
    /// empty body or a tiny Subsonic error XML body (e.g. trial expired) means the
    /// server sent no audio. Presents the matching alert, deletes the invalid file,
    /// and returns false for those failures.
    func validateFinishedDownload() -> Bool {
        if totalBytesTransferred == 0 {
            // Not a trial issue, but no data was returned at all
            let message = "We asked for a song, but the server didn't send anything!\n\nIt's likely that Subsonic's transcoding failed."
            let alert = UIAlertController(title: "Uh Oh!", message: message, preferredStyle: .alert)
            alert.addOKAction()
            UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)

            // TODO: Do we care if this fails? Can the file potentially not be there at all?
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: filePath))
            return false
        } else if totalBytesTransferred < 1000 {
            // Verify that it's a license issue
            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                let root = RXMLElement(xmlData: data)
                if root.isValid {
                    if let error = root.child("error"), error.isValid {
                        let subsonicError = SubsonicError(element: error)
                        if case .trialExpired = subsonicError {
                            let alert = UIAlertController(title: "Subsonic Error", message: subsonicError.localizedDescription, preferredStyle: .alert)
                            alert.addOKAction()
                            UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)

                            // TODO: Do we care if this fails? Can the file potentially not be there at all?
                            try? FileManager.default.removeItem(at: URL(fileURLWithPath: filePath))
                            return false
                        }
                    }
                }
            }
        }
        return true
    }
}

extension StreamHandler: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Allow self-signed SSL certificates
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if Debug.streamManager {
            DDLogInfo("[StreamHandler] Stream handler didReceiveResponse for \(song)")
        }
        
        if let response = response as? HTTPURLResponse {
            if response.statusCode >= 500 {
                // This is a failure, cancel the connection and call the didFail delegate method.
                // The cancellation also surfaces in didCompleteWithError as NSURLErrorCancelled,
                // which is ignored there since all cancellations are reported at their source.
                dataTask.cancel()
                self.dataTask = nil
                DispatchQueue.main.async {
                    self.connectionFailed(error: APIError.serverUnreachable)
                }
                completionHandler(.cancel)
                return
            } else if contentLength == nil, let contentLengthString = response.value(forHTTPHeaderField: "Content-Length") {
                // Set the content length if it isn't set already, only set the first connection, not on retries
                contentLength = Int(contentLengthString)
            }
        }

        bytesTransfered = 0
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask.state == .running else { return }
        
        if isSpeedLoggingEnabled {
            speedLoggingDate = Date()
            speedLoggingLastSize = totalBytesTransferred
        }
        
        totalBytesTransferred += data.count
        bytesTransfered += data.count
        
        if let fileHandle = fileHandle {
            // Save the data to the file
            do {
                try fileHandle.write(contentsOf: data)
            } catch {
                DispatchQueue.main.async { self.cancel() }
            }
            
            // Notify delegate if enough bytes received to start playback (~10 seconds of audio,
            // adjusted for the recent download speed when known)
            if !isDelegateNotifiedToStartPlayback && totalBytesTransferred > minBytesToStartPlayback(kiloBitrate: kiloBitrate, bytesPerSec: recentDownloadSpeedInBytesPerSec) {
                isDelegateNotifiedToStartPlayback = true
                DispatchQueue.main.async {
                    self.delegate?.streamHandlerStartPlayback(handler: self)
                }
            }
            
            // Log progress
            if isProgressLoggingEnabled {
                DDLogInfo("[StreamHandler] downloadedLength: \(totalBytesTransferred) bytesRead: \(data.count)")
            }
            
            // If near beginning of file, don't throttle
            if totalBytesTransferred < minBytesToStartLimiting(kiloBitrate: kiloBitrate) {
                throttlingDate = Date()
                bytesTransfered = 0
            }

            // Throttle the download after the initial buffer so background caching doesn't
            // compete with the playing stream or blow through cellular limits. Like the old
            // rate limiting behavior, only throttle while a song is actively playing.
            if player.isPlaying {
                let intervalSinceLastThrottle = Date().timeIntervalSince(throttlingDate)
                if intervalSinceLastThrottle > throttleTimeInterval && totalBytesTransferred > minBytesToStartLimiting(kiloBitrate: kiloBitrate) {
                    let delay = throttleDelay(bytesTransferred: bytesTransfered, intervalSinceLastThrottle: intervalSinceLastThrottle, kiloBitrate: kiloBitrate, isCell: !networkStatus.isWifi)
                    if delay > 0 {
                        if isThrottleLoggingEnabled {
                            DDLogInfo("[StreamHandler] Throttling: pausing for \(delay), interval: \(intervalSinceLastThrottle), bytesTransferred: \(bytesTransfered)")
                        }

                        throttleCount += 1
                        bytesTransfered = 0

                        // Runs on the session's background delegate queue, so sleeping
                        // delays the next data callback without blocking anything else
                        Thread.sleep(forTimeInterval: delay)

                        // The download may have been canceled while sleeping
                        guard isDownloading else { return }
                    }
                    throttlingDate = Date()
                }
            }
        } else {
            DDLogError("[StreamHandler] received data but file handle was nil for \(song)")
            if dataTask.state != .canceling {
                // There is no file handle for some reason, cancel the connection
                dataTask.cancel()
                self.dataTask = nil
                DispatchQueue.main.async {
                    // TODO: implement this - use better error message
                    self.connectionFailed(error: APIError.filesystem)
                }
            }
        }
        
        // Check every 10 seconds
        let now = Date()
        let speedInterval = now.timeIntervalSince(speedLoggingDate)
        if speedInterval >= 10 {
            let transferredSinceLastCheck = totalBytesTransferred - speedLoggingLastSize
            
            let speedInBytes = Double(transferredSinceLastCheck) / speedInterval
            recentDownloadSpeedInBytesPerSec = Int(speedInBytes)
            
            if isSpeedLoggingEnabled {
                let speedInKbytes = speedInBytes / 1024.0
                DDLogInfo("[StreamHandler] rate: \(speedInKbytes) speedInterval: \(speedInterval) transferredSinceLastCheck: \(transferredSinceLastCheck)")
            }
            
            speedLoggingLastSize = totalBytesTransferred
            speedLoggingDate = now
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Cancellations are always initiated locally (cancel() or the HTTP error
            // handling in didReceive response) and are reported to the delegate at their
            // source, so don't route them through connectionFailed (which would retry)
            if !error.isCanceled {
                DispatchQueue.main.async { self.connectionFailed(error: error) }
            }
        } else {
            if Debug.streamManager {
                DDLogInfo("[StreamHandler] Stream handler didFinishLoadingInternal for \(song)")
            }

            // Check to see if we're at the contentLength (to allow some leeway for contentLength estimation of transcoded songs)
            if let contentLength = contentLength, song.localFileSize < contentLength && numberOfContentLengthFailures < maxContentLengthFailures {
                numberOfContentLengthFailures += 1
                // This is a failed connection that didn't call didFailInternal for some reason,
                // so route it to connectionFailed (which resets state and closes the file
                // handle) instead of falling through to a clean finish
                // TODO: Is there a better error code to use?
                DispatchQueue.main.async { self.connectionFailed(error: APIError.serverUnreachable) }
                return
            }

            // Make sure the player is told to start
            if !isDelegateNotifiedToStartPlayback {
                isDelegateNotifiedToStartPlayback = true
                DispatchQueue.main.async { self.delegate?.streamHandlerStartPlayback(handler: self) }
            }

            isDownloading = false
            dataTask = nil
            
            // Close the file handle
            do {
                try fileHandle?.close()
            } catch {
                DDLogError("[StreamHandler] Failed to close file handle after completion for \(song)")
            }
            fileHandle = nil
            
            DispatchQueue.main.async {
                self.delegate?.streamHandlerConnectionFinished(handler: self)
            }
        }
    }
    
    private func connectionFailed(error: Error) {
        assert(Thread.isMainThread, "didFailInternal must be called from the main thread")
        DDLogError("[StreamHandler] Connection Failed for \(song), error: \(error)")
        
        isDownloading = false
        dataTask = nil
        
        // Close the file handle
        do {
            try fileHandle?.close()
        } catch {
            DDLogError("[StreamHandler] Failed to close file handle after connection failed for \(song)")
        }
        fileHandle = nil
                
        delegate?.streamHandlerConnectionFailed(handler: self, error: error)
    }
}

// MARK: Constants and Helper Functions

// Internal (not private) for test access
func minimumBytesToStartPlayback(kiloBitrate: Int) -> Int {
    return bytesForSeconds(seconds: 10, kiloBitrate: kiloBitrate)
}

let throttleTimeInterval = 0.1

private let maxKilobitsPerSecondCell = 500
func maxBytesPerIntervalCell() -> Int {
    return bytesForSeconds(seconds: throttleTimeInterval, kiloBitrate: maxKilobitsPerSecondCell)
}

private let maxKilobitsPerSecondWifi = 8000
func maxBytesPerIntervalWifi() -> Int {
    return bytesForSeconds(seconds: throttleTimeInterval, kiloBitrate: maxKilobitsPerSecondWifi)
}

func minBytesToStartLimiting(kiloBitrate: Int) -> Int {
    return bytesForSeconds(seconds: 60, kiloBitrate: kiloBitrate)
}

private let maxContentLengthFailures = 25

// Returns how long the transfer should sleep to stay under the throttling cap: the time
// the bytes received since the last throttle check *should* have taken at the capped
// rate, minus the time they actually took. 0 when under the cap.
func throttleDelay(bytesTransferred: Int, intervalSinceLastThrottle: TimeInterval, kiloBitrate: Int, isCell: Bool) -> TimeInterval {
    let maxBytes = Double(maxBytesPerInterval(kiloBitrate: kiloBitrate, isCell: isCell))
    let numberOfIntervals = intervalSinceLastThrottle / throttleTimeInterval
    let maxBytesPerTotalInterval = maxBytes * numberOfIntervals
    guard Double(bytesTransferred) > maxBytesPerTotalInterval else { return 0 }

    let speedDifferenceFactor = Double(bytesTransferred) / maxBytesPerTotalInterval
    return (speedDifferenceFactor * intervalSinceLastThrottle) - intervalSinceLastThrottle
}

func maxBytesPerInterval(kiloBitrate: Int, isCell: Bool) -> Int {
    let maxBytesDefault = isCell ? maxBytesPerIntervalCell() : maxBytesPerIntervalWifi()
    var maxBytesPerInterval = Int(Double(maxBytesDefault) * (Double(kiloBitrate) / 160.0))
    if maxBytesPerInterval < maxBytesDefault {
        // Don't go lower than the default
        maxBytesPerInterval = maxBytesDefault
    } else if maxBytesPerInterval > maxBytesPerIntervalWifi() * 2 {
        // Don't go higher than twice the Wifi limit to prevent disk bandwidth issues
        maxBytesPerInterval = maxBytesPerIntervalWifi() * 2
    }
    return maxBytesPerInterval
}

// TODO: Refactor this to simplify (minSecondsToStartPlayback could be a single equation for example)
func minBytesToStartPlayback(kiloBitrate: Int, bytesPerSec: Int) -> Int {
    // If start date is nil somehow, or total bytes transferred is 0 somehow,
    guard kiloBitrate > 0 && bytesPerSec > 0 else { return minimumBytesToStartPlayback(kiloBitrate: kiloBitrate) }
    
    // Get the download speed so far
    let kiloBytesPerSec = Double(bytesPerSec) / 1024.0
    
    // Find out out many bytes equals 1 second of audio
    let bytesForOneSecond = bytesForSeconds(seconds: 1, kiloBitrate: kiloBitrate)
    let kiloBytesForOneSecond = Double(bytesForOneSecond) / 1024.0
    
    // Calculate the amount of seconds to start as a factor of how many seconds of audio are being downloaded per second
    let secondsPerSecondFactor = kiloBytesPerSec / kiloBytesForOneSecond
    
    let minSecondsToStartPlayback: Int
    if secondsPerSecondFactor < 1.0 {
        // Downloading slower than needed for playback, allow for a long buffer
        minSecondsToStartPlayback = 16
    } else if secondsPerSecondFactor >= 1.0 && secondsPerSecondFactor < 1.5 {
        // Downloading faster, but not much faster, allow for a long buffer period
        minSecondsToStartPlayback = 8
    } else if secondsPerSecondFactor >= 1.5 && secondsPerSecondFactor < 1.8 {
        // Downloading fast enough for a smaller buffer
        minSecondsToStartPlayback = 6
    } else if secondsPerSecondFactor >= 1.8 && secondsPerSecondFactor < 2.0 {
        // Downloading fast enough for an even smaller buffer
        minSecondsToStartPlayback = 4
    } else {
        // Downloading multiple times playback speed, start quickly
        minSecondsToStartPlayback = 2
    }
    
    // Convert from seconds to bytes
    let minBytesToStartPlayback = minSecondsToStartPlayback * bytesForOneSecond
    return Int(minBytesToStartPlayback)
}
