//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class Song: Codable, Hashable, CustomStringConvertible {
    private var store: Store { ModelServices.store }

    let serverId: Int
    let id: String
    let title: String
    let coverArtId: String?
    let parentFolderId: String?
    let tagArtistName: String?
    let tagAlbumName: String?
    let playCount: Int?
    let year: Int?
    let tagArtistId: String?
    let tagAlbumId: String?
    let genre: String?
    let path: String
    let suffix: String
    let transcodedSuffix: String?
    let duration: Int
    let kiloBitrate: Int
    let track: Int?
    let discNumber: Int?
    let size: Int
    let isVideo: Bool
    let createdDate: Date
    let starredDate: Date?
    
    var localSuffix: String? { transcodedSuffix ?? suffix }
    var localPath: String {
        let serverPathPrefix: String
        if let server = store.server(id: serverId) {
            serverPathPrefix = server.path
        } else {
            serverPathPrefix = "Unknown"
        }
        let localPath = FileSystem.downloadsDirectory.appendingPathComponent(serverPathPrefix).appendingPathComponent(path).path
        return localPath
    }
    
    var localTempPath: String {
        let serverPathPrefix: String
        if let server = store.server(id: serverId) {
            serverPathPrefix = server.path
        } else {
            serverPathPrefix = "Unknown"
        }
        let localPath = FileSystem.tempDownloadsDirectory.appendingPathComponent(serverPathPrefix).appendingPathComponent(path).path
        return localPath
    }
    var currentPath: String { isTempCached ? localTempPath : localPath }
    
    var isTempCached: Bool {
        // If the song is fully cached, then it doesn't matter if there is a temp cache file
        //if self.isFullyCached { return false }
        
        // Return YES if the song exists in the temp folder
        return FileManager.default.fileExists(atPath: localTempPath)
    }
    
    var localFileSize: Int {
        var st = stat()
        stat(currentPath, &st)
        return Int(st.st_size)
        
//        return URL(fileURLWithPath: currentPath).fileSize ?? 0
        
        
        // NOTE: This is almost certainly no longer the case
        // Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
        // Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
        // Still waiting for an answer on what the crash could be, so this is my temporary "solution"
//        var st = stat()
//        stat(currentPath.cString(using: .utf8), &st)
//        return Int(st.st_size)
        
//        return FileManager.default.attributesOfItem(atPath: currentPath)[.size]
    }
    
    var fileExists: Bool {
        // Filesystem check
        return FileManager.default.fileExists(atPath: currentPath)
        
        // Database check
        //return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
    }
    
    var estimatedKiloBitrate: Int {
        BitratePolicy.estimatedKiloBitrate(songKiloBitrate: kiloBitrate,
                                           isTranscoded: transcodedSuffix != nil,
                                           currentMaxBitrate: ModelServices.settings?.currentMaxBitrate ?? 0)
    }
    
    init(serverId: Int, id: String, title: String, coverArtId: String?, parentFolderId: String?, tagArtistName: String?, tagAlbumName: String?, playCount: Int?, year: Int?, tagArtistId: String?, tagAlbumId: String?, genre: String?, path: String, suffix: String, transcodedSuffix: String?, duration: Int, kiloBitrate: Int, track: Int?, discNumber: Int?, size: Int, isVideo: Bool, createdDate: Date, starredDate: Date?) {
        self.serverId = serverId
        self.id = id
        self.title = title
        self.coverArtId = coverArtId
        self.parentFolderId = parentFolderId
        self.tagArtistName = tagArtistName
        self.tagAlbumName = tagAlbumName
        self.playCount = playCount
        self.year = year
        self.tagArtistId = tagArtistId
        self.tagAlbumId = tagAlbumId
        self.genre = genre
        self.path = path
        self.suffix = suffix
        self.transcodedSuffix = transcodedSuffix
        self.duration = duration
        self.kiloBitrate = kiloBitrate
        self.track = track
        self.discNumber = discNumber
        self.size = size
        self.isVideo = isVideo
        self.createdDate = createdDate
        self.starredDate = starredDate
    }
    
    // NOTE: The dto inits reproduce the legacy XML inits' defaults exactly (including
    // the legacy XML parser's "nil" string sentinel) so DB rows are byte-identical
    // whichever wire format produced them — Combined Library dedup/equality depends
    // on that.
    init(serverId: Int, dto: ChildDTO) {
        self.serverId = serverId
        self.id = dto.id.value
        self.title = dto.title ?? "nil"
        self.coverArtId = dto.coverArt?.value
        self.parentFolderId = dto.parent?.value
        self.tagArtistName = dto.artist
        self.tagAlbumName = dto.album
        self.playCount = dto.playCount
        self.year = dto.year
        self.tagArtistId = dto.artistId?.value
        self.tagAlbumId = dto.albumId?.value
        self.genre = dto.genre
        self.path = dto.path ?? "nil"
        self.suffix = dto.suffix ?? "nil"
        self.transcodedSuffix = dto.transcodedSuffix
        self.duration = dto.duration ?? 0
        self.kiloBitrate = dto.bitRate ?? 0
        self.track = dto.track
        self.discNumber = dto.discNumber
        self.size = dto.size ?? 0
        self.isVideo = dto.isVideo ?? false
        self.createdDate = dto.created ?? .distantPast
        self.starredDate = dto.starred
    }

    // MARK: Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(serverId)
        hasher.combine(id)
    }
    
    static func ==(lhs: Song, rhs: Song) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
    
    // MARK: ISMSSong+DAO
    
    var isFullyCached: Bool {
        return store.isDownloadFinished(song: self)
    }
}

extension Song: TableCellModel {
    var primaryLabelText: String? { title }
    var secondaryLabelText: String? { tagArtistName }
    var durationLabelText: String? { formatTime(seconds: duration) }
    var isDownloaded: Bool { isFullyCached }
    var isDownloadable: Bool { !isVideo && !isDownloaded }
    var isAvailableOffline: Bool { isDownloaded }
    
    func download() { _ = store.addToDownloadQueue(song: self) }
    func queue() { _ = store.queue(song: self) }
    func queueNext() { queueNext(offset: 0) }
    func queueNext(offset: Int = 0) { _ = store.queueNext(song: self, offset: offset) }
}

extension UniversalTableViewCell {
    func update(song: Song, number: Bool = true, downloaded: Bool = true, art: Bool = false, secondary: Bool = true, duration: Bool = true) {
        var showNumber = false
        if number, let track = song.track {
            showNumber = true
            self.number = track
        }
        show(downloaded: downloaded, number: showNumber, art: art, secondary: secondary, duration: duration)
        update(model: song)
    }
}
