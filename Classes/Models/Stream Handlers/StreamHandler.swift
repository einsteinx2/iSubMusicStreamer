//
//  StreamHandler.swift
//  iSub
//
//  Created by Benjamin Baron on 1/22/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

private let isProgressLoggingEnabled = false
private let isThrottleLoggingEnabled = true
private let isSpeedLoggingEnabled = false

protocol StreamHandlerDelegate {
    func streamHandlerStarted(handler: StreamHandler)
    func streamHandlerStartPlayback(handler: StreamHandler)
    func streamHandlerConnectionFinished(handler: StreamHandler)
    func streamHandlerConnectionFailed(handler: StreamHandler, error: Error)
}

// TODO: implement this - Codable protocol and refactor everything
@objc final class StreamHandler: NSObject, Codable {
    private enum CodingKeys: String, CodingKey {
        case song, byteOffset, secondsOffset, isDelegateNotifiedToStartPlayback, isTempCache, isDownloading, contentLength, maxBitrateSetting
    }
    
    @Injected private var playQueue: PlayQueue
    @Injected private var cache: Cache
    @Injected private var settings: Settings
    @Injected private var store: Store
    
    private lazy var session: URLSession = { URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil) }()
    private var request: URLRequest?
    private var dataTask: URLSessionDataTask?
    private var fileHandle: FileHandle?
    
    var delegate: StreamHandlerDelegate?
    
    let song: Song
    private(set) var byteOffset: UInt64
    private(set) var secondsOffset: Double
    let isTempCache: Bool
    
    @objc private(set) var isDelegateNotifiedToStartPlayback = false
    @objc private(set) var isDownloading = false
    private(set) var totalBytesTransferred: UInt64 = 0
    var numberOfReconnects = 0
    @objc private(set) var recentDownloadSpeedInBytesPerSec = 0
    
    private var isCurrentSong = false
    private var isCanceled = false
    private var contentLength = UInt64.max
    private var maxBitrateSetting = Int.max
    private var startDate = Date()
    private var bytesTransfered: UInt64 = 0
    private var bitrate = 0
    private var speedLoggingDate = Date()
    private var speedLoggingLastSize: UInt64 = 0
    private var throttlingDate = Date()
    private var numberOfContentLengthFailures = 0
    
    var totalDownloadSpeedInBytesPerSec: Int { Int(Double(totalBytesTransferred) / Date().timeIntervalSince(startDate)) }
    
    var filePath: String { isTempCache ? song.localTempPath : song.localPath }
    
    init(song: Song, byteOffset: UInt64 = 0, secondsOffset: Double = 0.0, tempCache: Bool, delegate: StreamHandlerDelegate) {
        self.song = song
        self.byteOffset = byteOffset
        self.secondsOffset = secondsOffset
        self.isTempCache = tempCache
        self.delegate = delegate
        super.init()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playlistIndexChanged), name: Notifications.currentPlaylistIndexChanged)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc private func playlistIndexChanged() {
        if let currentSong = playQueue.currentSong, song.isEqual(currentSong) {
            isCurrentSong = true
        }
    }
    
    private func startTimeoutTimer() {
        stopTimeoutTimer()
        perform(#selector(connectionTimedOut), with: nil, afterDelay: 30)
    }
    
    private func stopTimeoutTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(connectionTimedOut), object: nil)
    }
    
    @objc private func connectionTimedOut() {
        DDLogError("[StreamHandler] Stream handler connectionTimedOut for \(song)")
        cancel()
        // TODO: Better error code here
        self.didFailInternal(error: NSError(ismsCode: Int(ISMSErrorCode_CouldNotReachServer)))
    }
    
    // TODO: implement this - refactor for better error handling
    func start(resume: Bool = false) {
        // Clear temp cache if this is a temp file and we're not resuming
        if !resume && isTempCache {
            cache.clearTempCache()
        }
        
        DDLogInfo("[StreamHandler] start(resume: \(resume) for: \(song)")
        
        totalBytesTransferred = 0
        bytesTransfered = 0
        
        // Create the file handle
        fileHandle = FileHandle(forWritingAtPath: filePath)
        if let fileHandle = fileHandle {
            if (resume) {
                // File exists so seek to end
                // TODO: implement this - Handle this Obj-C exception or better, switch to non-deprecated API
                totalBytesTransferred = fileHandle.seekToEndOfFile()
                byteOffset += totalBytesTransferred
            } else {
                // File exists so remove it
                // TODO: implement this - Switch to non-deprecated API
                fileHandle.closeFile()
                self.fileHandle = nil
                // TODO: implement this - error handling
                try? FileManager.default.removeItem(atPath: filePath)
            }
        }
        
        if !resume {
            // Create intermediary directory if needed
            let containingDirectory = (filePath as NSString).deletingLastPathComponent
            if !FileManager.default.fileExists(atPath: containingDirectory) {
                do {
                    try FileManager.default.createDirectory(atPath: containingDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DDLogError("[StreamHandler] Failed to create containing directory \(containingDirectory), error: \(error)")
                }
            }
            
            // Create the file
            do {
                try Data().write(to: URL(fileURLWithPath: filePath), options: [])
            } catch {
                DDLogError("[StreamHandler] Failed to create file \(filePath), error: \(error)")
            }
            fileHandle = FileHandle(forWritingAtPath: filePath)
            if fileHandle == nil {
                DDLogError("[StreamHandler] Failed to create file handle for file \(filePath)")
            }
            
            // TODO: implement this - Make sure that sending estimateContentLength as a book instead of a string works
            var parameters: [String: Any] = ["id": song.id, "estimateContentLength": true]
            if maxBitrateSetting == Int.max {
                maxBitrateSetting = settings.currentMaxBitrate
            } else if maxBitrateSetting != 0 {
                parameters["maxBitRate"] = maxBitrateSetting
            }
            
            request = URLRequest(serverId: song.serverId, subsonicAction: "stream", parameters: parameters, byteOffset: byteOffset)
            if request == nil {
                DDLogError("[StreamHandler] start connection failed to create request")
                delegate?.streamHandlerConnectionFailed(handler: self, error: NSError(ismsCode: Int(ISMSErrorCode_CouldNotCreateConnection)))
            }
            
            bitrate = song.estimatedBitrate
            if let currentSong = playQueue.currentSong, song.isEqual(currentSong) {
                isCurrentSong = true
            }
            
            startConnection()
        }
    }
    
    private func startConnection() {
        guard let request = request else { return }
        
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
        isDownloading = true
        DDLogInfo("[StreamHandler] Stream handler connection started successfully for \(song)")
        
        if !isTempCache {
            _ = store.add(downloadedSong: DownloadedSong(song: song))
        }
        
        DispatchQueue.main.async {
            EX2NetworkIndicator.usingNetwork()
            self.delegate?.streamHandlerStarted(handler: self)
            
            self.startTimeoutTimer()
        }
    }
    
    func cancel() {
        DispatchQueue.mainSyncSafe {
            stopTimeoutTimer()
            EX2NetworkIndicator.doneUsingNetwork()
        }
        
        isDownloading = false
        isCanceled = true
        
        DDLogInfo("[StreamHandler] Stream handler request canceled for \(song)")
        dataTask?.cancel()
        dataTask = nil
        
        // Close the file handle
        // TODO: implement this - use non-deprecated API
        fileHandle?.closeFile()
        fileHandle = nil
    }
    
    private func startPlaybackInternal() {
        assert(Thread.isMainThread, "startPlaybackInternal must be called from the main thread")
        
        delegate?.streamHandlerStartPlayback(handler: self)
    }
    
    private func didFailInternal(error: Error) {
        DDLogError("[StreamHandler] didFailInternal for \(song)")
        assert(Thread.isMainThread, "didFailInternal must be called from the main thread")
        stopTimeoutTimer()
        
        DDLogError("[StreamHandler] Connection Failed for \(song)")
        DDLogError("[StreamHandler] error domain: \(error.domain) code: \(error.code) description: \(error.localizedDescription)")
        
        isDownloading = false
        dataTask = nil
        
        // Close the file handle
        // TODO: implement this - switch to non-deprecated API
        fileHandle?.closeFile()
        fileHandle = nil
        
        EX2NetworkIndicator.doneUsingNetwork()
        
        delegate?.streamHandlerConnectionFailed(handler: self, error: error)
    }
    
    private func didFinishLoadingInternal() {
        DDLogInfo("[StreamHandler] Stream handler didFinishLoadingInternal for \(song)")
        assert(Thread.isMainThread, "didFinishLoadingInternal must be called from the main thread")
        stopTimeoutTimer()
        
        // Check to see if we're at the contentLength (to allow some leeway for contentLength estimation of transcoded songs
        if contentLength != UInt64.max && song.localFileSize < contentLength && numberOfContentLengthFailures < maxContentLengthFailures {
            numberOfContentLengthFailures += 1
            // This is a failed connection that didn't call didFailInternal for some reason, so call didFailWithError
            // TODO: Is there a better error code to use?
            didFailInternal(error: NSError(ismsCode: Int(ISMSErrorCode_CouldNotReachServer)))
        } else {
            // Make sure the player is told to start
            if !isDelegateNotifiedToStartPlayback {
                isDelegateNotifiedToStartPlayback = true
                startPlaybackInternal()
            }
        }
        
        isDownloading = false
        dataTask = nil
        
        // Close the file handle
        // TODO: implement this - switch to non-deprecated API
        fileHandle?.closeFile()
        fileHandle = nil
        
        EX2NetworkIndicator.doneUsingNetwork()
        
        delegate?.streamHandlerConnectionFinished(handler: self)
    }
    
    // MARK: Equality
    
    override var hash: Int { song.serverId | song.id }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? StreamHandler {
            return song.isEqual(object.song)
        }
        return false
    }
    
    override var description: String { "\(super.description): for \(song)" }
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
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        DispatchQueue.main.async { self.stopTimeoutTimer() }
        guard !isCanceled else { return }
        
        if isSpeedLoggingEnabled {
            speedLoggingDate = Date()
            speedLoggingLastSize = totalBytesTransferred
        }
        
        totalBytesTransferred += UInt64(data.count)
        bytesTransfered += UInt64(data.count)
        
        if let fileHandle = fileHandle {
            // Save the data to the file
            // TODO: implement this - use non-deprecated API
            do {
                try ObjC.perform {
                    fileHandle.write(data)
                }
            } catch {
                DispatchQueue.main.async { self.cancel() }
            }
            
            // Notify delegate if enough bytes received to start playback
            if !isDelegateNotifiedToStartPlayback && totalBytesTransferred > UInt64(minBytesToStartLimiting(kiloBitrate: Float(bitrate))) {
                isDelegateNotifiedToStartPlayback = true
                DispatchQueue.main.async { self.startPlaybackInternal() }
            }
            
            // Log progress
            if isProgressLoggingEnabled {
                DDLogInfo("[StreamHandler] downloadedLength: \(totalBytesTransferred) bytesRead: \(data.count)")
            }
            
            // If near beginning of file, don't throttle
            if totalBytesTransferred < UInt64(minBytesToStartLimiting(kiloBitrate: Float(bitrate))) {
                throttlingDate = Date()
                bytesTransfered = 0
            }
        } else {
            DDLogInfo("[StreamHandler] received data but file handle was nil for \(song)")
            if !isCanceled {
                // There is no file handle for some reason, cancel the connection
                dataTask.cancel()
                self.dataTask = nil
                DispatchQueue.main.async {
                    self.didFailInternal(error: NSError(ismsCode: Int(ISMSErrorCode_CouldNotReachServer)))
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
        
        DispatchQueue.main.async { self.startTimeoutTimer() }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.didFailInternal(error: error)
            } else {
                self.didFinishLoadingInternal()
            }
        }
    }
}

// MARK: Constants and Helper Functions

private func minimumBytesToStartPlayback(kiloBitrate: Float) -> Float {
    return bytesForSeconds(seconds: 10, kiloBitrate: kiloBitrate)
}

private let throttleTimeInterval = 0.1

private let maxKilobitsPerSecondCell = 500
private func maxBytesPerIntervalCell() -> Float {
    return bytesForSeconds(seconds: Float(throttleTimeInterval), kiloBitrate: Float(maxKilobitsPerSecondCell))
}

private let maxKilobitsPerSecondWifi = 8000
private func maxBytesPerIntervalWifi() -> Float {
    return bytesForSeconds(seconds: Float(throttleTimeInterval), kiloBitrate: Float(maxKilobitsPerSecondWifi))
}

private func minBytesToStartLimiting(kiloBitrate: Float) -> Float {
    return bytesForSeconds(seconds: 60, kiloBitrate: kiloBitrate)
}

private let maxContentLengthFailures = 25

private func maxBytesPerInterval(kiloBitrate: Float, isCell: Bool) -> Float {
    let maxBytesDefault = isCell ? maxBytesPerIntervalCell() : maxBytesPerIntervalWifi()
    var maxBytesPerInterval = maxBytesDefault * (kiloBitrate / 160.0)
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
private func minBytesToStartPlayback(kiloBitrate: Float, bytesPerSec: Int) -> UInt64 {
    // If start date is nil somehow, or total bytes transferred is 0 somehow,
    guard kiloBitrate > 0 && bytesPerSec > 0 else { return UInt64(minimumBytesToStartPlayback(kiloBitrate: kiloBitrate)) }
    
    // Get the download speed so far
    let kiloBytesPerSec = Float(bytesPerSec) / 1024.0
    
    // Find out out many bytes equals 1 second of audio
    let bytesForOneSecond = bytesForSeconds(seconds: 1, kiloBitrate: kiloBitrate)
    let kiloBytesForOneSecond = bytesForOneSecond * 1024.0
    
    // Calculate the amount of seconds to start as a factor of how many seconds of audio are being downloaded per second
    let secondsPerSecondFactor = kiloBytesPerSec / kiloBytesForOneSecond
    
    let minSecondsToStartPlayback: Float
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
    return UInt64(minBytesToStartPlayback)
}
