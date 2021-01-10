//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc(ISMSSong) final class Song: NSObject, NSCopying, NSSecureCoding, Codable {
    static var supportsSecureCoding: Bool = true
    
    @objc let serverId: Int
    @objc(songId) let id: Int
    @objc let title: String
    @objc let coverArtId: String?
    @objc let parentFolderId: Int
    @objc let tagArtistName: String?
    @objc let tagAlbumName: String?
    @objc let playCount: Int
    @objc let year: Int
    @objc let tagArtistId: Int
    @objc let tagAlbumId: Int
    @objc let genre: String?
    @objc let path: String
    @objc let suffix: String
    @objc let transcodedSuffix: String?
    @objc let duration: Int
    @objc let bitrate: Int
    @objc let track: Int
    @objc let discNumber: Int
    @objc let size: Int
    @objc let isVideo: Bool
    
    @objc var localSuffix: String? { transcodedSuffix ?? suffix }
    @objc var localPath: String {
//        let fileName = NSString(string: path).md5
//        return NSString(Settings.shared().songCachePath()).path
////         ? NSString(Settings.shared().songCachePath()).}
        fatalError("implement this")
    }
    @objc var localTempPath: String {
        fatalError("implement this")
    }
    @objc var currentPath: String {
        fatalError("implement this")
    }
    
    @objc var isTempCached: Bool {
        // If the song is fully cached, then it doesn't matter if there is a temp cache file
        //if self.isFullyCached { return false }
        
        // Return YES if the song exists in the temp folder
        return FileManager.default.fileExists(atPath: localTempPath)
    }
    
    @objc var localFileSize: Int64 {
        // NOTE: This is almost certainly no longer the case
        // Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
        // Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
        // Still waiting for an answer on what the crash could be, so this is my temporary "solution"
        var st = stat()
        stat(currentPath.cString(using: .utf8), &st)
        return st.st_size;
        
//        return FileManager.default.attributesOfItem(atPath: currentPath)[.size]
    }
    
    @objc var fileExists: Bool {
        // Filesystem check
        return FileManager.default.fileExists(atPath: currentPath)
        
        // Database check
        //return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
    }
    
    @objc var estimatedBitrate: Int {
        let currentMaxBitrate = Settings.shared().currentMaxBitrate
        
        // Default to 128 if there is no bitrate for this song object (should never happen)
        var rate = bitrate == 0 ? 128 : bitrate
        
        // Check if this is being transcoded to the best of our knowledge
        if transcodedSuffix != nil {
            // This is probably being transcoded, so attempt to determine the bitrate
            if (rate > 128 && currentMaxBitrate == 0) {
                rate = 128 // Subsonic default transcoding bitrate
            } else if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        } else {
            // This is not being transcoded between formats, however bitrate limiting may be active
            if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        }

        return rate
    }
    
    @objc init(serverId: Int, id: Int, title: String, coverArtId: String?, parentFolderId: Int, tagArtistName: String?, tagAlbumName: String?, playCount: Int, year: Int, tagArtistId: Int, tagAlbumId: Int, genre: String?, path: String, suffix: String, transcodedSuffix: String?, duration: Int, bitrate: Int, track: Int, discNumber: Int, size: Int, isVideo: Bool) {
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
        self.bitrate = bitrate
        self.track = track
        self.discNumber = discNumber
        self.size = size
        self.isVideo = isVideo
        super.init()
    }
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.title = element.attribute("title").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.parentFolderId = element.attribute("parent").intXML
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.tagAlbumName = element.attribute("album").stringXMLOptional
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXML
        self.tagArtistId = element.attribute("artistId").intXML
        self.tagAlbumId = element.attribute("albumId").intXML
        self.genre = element.attribute("genre").stringXMLOptional
        self.path = element.attribute("path").stringXML
        self.suffix = element.attribute("suffix").stringXML
        self.transcodedSuffix = element.attribute("transcodedSuffix").stringXMLOptional
        self.duration = element.attribute("duration").intXML
        self.bitrate = element.attribute("bitRate").intXML
        self.track = element.attribute("track").intXML
        self.discNumber = element.attribute("discNumber").intXML
        self.size = element.attribute("size").intXML
        self.isVideo = element.attribute("isVideo").boolXML
        super.init()
    }
    
    @objc init(serverId: Int, attributeDict: [String: String]) {
        self.serverId = serverId
        self.id = attributeDict["id"].intXML
        self.title = attributeDict["title"].stringXML
        self.coverArtId = attributeDict["coverArt"].stringXMLOptional
        self.parentFolderId = attributeDict["parent"].intXML
        self.tagArtistName = attributeDict["artist"].stringXMLOptional
        self.tagAlbumName = attributeDict["album"].stringXMLOptional
        self.playCount = attributeDict["playCount"].intXML
        self.year = attributeDict["year"].intXML
        self.tagArtistId = attributeDict["artistId"].intXML
        self.tagAlbumId = attributeDict["albumId"].intXML
        self.genre = attributeDict["genre"].stringXMLOptional
        self.path = attributeDict["path"].stringXML
        self.suffix = attributeDict["suffix"].stringXML
        self.transcodedSuffix = attributeDict["transcodedSuffix"].stringXMLOptional
        self.duration = attributeDict["duration"].intXML
        self.bitrate = attributeDict["bitRate"].intXML
        self.track = attributeDict["track"].intXML
        self.discNumber = attributeDict["discNumber"].intXML
        self.size = attributeDict["size"].intXML
        self.isVideo = attributeDict["isVideo"].boolXML
        super.init()
    }
    
    init?(coder: NSCoder) {
        // Handle old coding format
        if coder.containsValue(forKey: "coderVersion") && coder.decodeInteger(forKey: "coderVersion") == 1 {
            // New coding type
            self.serverId = coder.decodeInteger(forKey: "serverId")
            self.id = coder.decodeInteger(forKey: "id")
            self.title = coder.decodeObject(forKey: "title") as? String ?? ""
            self.coverArtId = coder.decodeObject(forKey: "coverArtid") as? String
            self.parentFolderId = coder.decodeInteger(forKey: "parentFolderId")
            self.tagArtistName = coder.decodeObject(forKey: "tagArtistName") as? String
            self.tagAlbumName = coder.decodeObject(forKey: "tagAlbumName") as? String
            self.playCount = coder.decodeInteger(forKey: "playCount")
            self.year = coder.decodeInteger(forKey: "year")
            self.tagArtistId = coder.decodeInteger(forKey: "tagArtistId")
            self.tagAlbumId = coder.decodeInteger(forKey: "tagAlbumId")
            self.genre = coder.decodeObject(forKey: "genre") as? String
            self.path = coder.decodeObject(forKey: "path") as? String ?? ""
            self.suffix = coder.decodeObject(forKey: "suffix") as? String ?? ""
            self.transcodedSuffix = coder.decodeObject(forKey: "transcodedSuffix") as? String
            self.duration = coder.decodeInteger(forKey: "duration")
            self.bitrate = coder.decodeInteger(forKey: "bitrate")
            self.track = coder.decodeInteger(forKey: "track")
            self.discNumber = coder.decodeInteger(forKey: "discNumber")
            self.size = coder.decodeInteger(forKey: "size")
            self.isVideo = coder.decodeBool(forKey: "isVideo")
        } else {
            // Old coding type
            self.title = (coder.decodeObject(forKey: "title") as? String).stringXML
            self.id = (coder.decodeObject(forKey: "songId") as? String).intXML
            self.parentFolderId = (coder.decodeObject(forKey: "parentId") as? String).intXML
            self.tagArtistName = coder.decodeObject(forKey: "artist") as? String
            self.tagAlbumName = coder.decodeObject(forKey: "album") as? String
            self.genre = coder.decodeObject(forKey: "genre") as? String
            self.coverArtId = coder.decodeObject(forKey: "coverArtid") as? String
            self.path = coder.decodeObject(forKey: "path") as? String ?? ""
            self.suffix = coder.decodeObject(forKey: "suffix") as? String ?? ""
            self.transcodedSuffix = coder.decodeObject(forKey: "transcodedSuffix") as? String
            self.duration = (coder.decodeObject(forKey: "duration") as? String).intXML
            self.bitrate = (coder.decodeObject(forKey: "bitRate") as? String).intXML
            self.track = (coder.decodeObject(forKey: "track") as? String).intXML
            self.year = (coder.decodeObject(forKey: "year") as? String).intXML
            self.size = (coder.decodeObject(forKey: "size") as? String).intXML
            self.isVideo = coder.decodeBool(forKey: "isVideo")
            self.discNumber = (coder.decodeObject(forKey: "discNumber") as? String).intXML

            // Not encoded
            self.serverId = -1
            self.playCount = 0
            self.tagArtistId = 0
            self.tagAlbumId = 0
        }
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(1, forKey: "coderVersion")
        coder.encode(serverId, forKey: "serverId")
        coder.encode(id, forKey: "id")
        coder.encode(title, forKey: "title")
        coder.encode(coverArtId, forKey: "coverArtId")
        coder.encode(parentFolderId, forKey: "parentFolderId")
        coder.encode(tagArtistName, forKey: "tagArtistName")
        coder.encode(tagAlbumName, forKey: "tagAlbumName")
        coder.encode(playCount, forKey: "playCount")
        coder.encode(year, forKey: "year")
        coder.encode(tagArtistId, forKey: "tagArtistId")
        coder.encode(tagAlbumId, forKey: "tagAlbumId")
        coder.encode(genre, forKey: "genre")
        coder.encode(path, forKey: "path")
        coder.encode(suffix, forKey: "suffix")
        coder.encode(transcodedSuffix, forKey: "transcodedSuffix")
        coder.encode(duration, forKey: "duration")
        coder.encode(bitrate, forKey: "bitrate")
        coder.encode(track, forKey: "track")
        coder.encode(discNumber, forKey: "discNumber")
        coder.encode(size, forKey: "size")
        coder.encode(isVideo, forKey: "isVideo")
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return Song(serverId: serverId, id: id, title: title, coverArtId: coverArtId, parentFolderId: parentFolderId, tagArtistName: tagArtistName, tagAlbumName: tagAlbumName, playCount: playCount, year: year, tagArtistId: tagArtistId, tagAlbumId: tagAlbumId, genre: genre, path: path, suffix: suffix, transcodedSuffix: transcodedSuffix, duration: duration, bitrate: bitrate, track: track, discNumber: discNumber, size: size, isVideo: isVideo)
    }
    
    override var description: String {
        return "\(super.description): serverId: \(serverId), id: \(id), title: \(title)"
    }
    
    override var hash: Int {
        return id.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? Song {
            return self === object || (serverId == object.serverId && id == object.id)
        }
        return false
    }
    
    // MARK: ISMSSong+DAO
//
//    var fileExists: Bool {
//        // Filesystem check
//        return FileManager.default.fileExists(atPath:currentPath)
//    }
//
    @objc var isPartiallyCached: Bool {
        // Implement this
        return false
    }
    
    @objc var isFullyCached: Bool {
        // Implement this
        return false
    }

    @objc var downloadProgress: Float {
        var downloadProgress: Float = 0
        
        if isFullyCached {
            downloadProgress = 1
        } else if isPartiallyCached {
            var bitrate = Float(estimatedBitrate)
            if let player = AudioEngine.shared().player, player.isPlaying {
                bitrate = Float(BassWrapper.estimateBitrate(player.currentStream))
            }
            
            var seconds = Float(duration)
            if transcodedSuffix != nil {
                // This is a transcode, so we'll want to use the actual bitrate if possible
                if let currentSong = PlayQueue.shared.currentSong, currentSong == self {
                    // This is the current playing song, so see if BASS has an actual bitrate for it
                    if let player = AudioEngine.shared().player, player.bitRate > 0 {
                        // Bass has a non-zero bitrate, so use that for the calculation
                        // convert to bytes per second, multiply by number of seconds
                        bitrate = Float(player.bitRate)
                        seconds = Float(duration)
                    }
                }
            }
            let totalSize = bytesForSecondsAtBitrate(seconds: seconds, bitrate: bitrate)
            downloadProgress = Float(localFileSize) / totalSize
        }
        
        // Keep within bounds
        downloadProgress = downloadProgress < 0 ? 0 : downloadProgress
        downloadProgress = downloadProgress > 1 ? 1 : downloadProgress
        
        // The song hasn't started downloading yet
        return downloadProgress;
    }
    
    @objc func removeFromCachedSongsTable() {
        // Implement this
    }
}

extension Song: TableCellModel {
    var primaryLabelText: String? { title }
    var secondaryLabelText: String? { tagArtistName }
    var durationLabelText: String? { NSString.formatTime(Double(duration)) }
    var isCached: Bool { isFullyCached }
    func download() {
        let store: Store = Resolver.resolve()
        _ = store.addToDownloadQueue(song: self)
    }
    func queue() {
        let store: Store = Resolver.resolve()
        _ = store.queue(song: self)
    }
}