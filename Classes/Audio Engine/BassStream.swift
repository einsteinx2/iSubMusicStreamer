//
//  BassStream.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class BassStream: Equatable, CustomStringConvertible {
    let song: Song
    var hstream: HSTREAM = 0
    
    var channelCount = 0
    var sampleRate = 0
    
    // TODO: Get rid of this reference
    weak var player: BassPlayer?
    // TODO: Get rid of these properties (or greatly simplify)
    var shouldWaitForData = false
    var isWaiting = false
    var shouldBreakWaitLoop = false
    var shouldBreakWaitLoopForever = false
    
    // Using C file handle to directly copy to the buffer (FileHandle would require
    // first reading into a Data object then copying to the actual buffer)
    private let file: UnsafeMutablePointer<FILE>
    
    var fileSize: QWORD {
        if song.isFullyCached || song.isTempCached {
            // Return actual file size on disk
            return QWORD(sizeOnDisk)
        } else {
            // Return server reported file size
            return QWORD(song.size)
        }
    }
    
    // TODO: Better to use stat or the URL attributes? Should do some testing to confirm the numbers are equal and if there's any performance difference. For now, using stat to keep with the "everything using C" theme...
    var sizeOnDisk: Int {
        var st = stat()
        stat(song.currentPath.cString(using: .utf8), &st)
        return Int(st.st_size)
    }
    
    init?(song: Song) {
        guard let cFileHandle = fopen(song.currentPath, "rb") else { return nil }
        self.song = song
        self.file = cFileHandle
    }
    
    deinit {
        fclose(file)
    }
    
    func readBytes(buffer: UnsafeMutableRawPointer, length: DWORD) -> DWORD {
        return UInt32(fread(buffer, 1, Int(length), file))
    }
    
    func seek(to offset: QWORD) -> Bool {
        // First check the file size to make sure we don't try and skip past the end of the file
        guard sizeOnDisk >= offset else { return false }
        return fseek(file, Int(offset), SEEK_SET) == 0
    }
    
    static func ==(lhs: BassStream, rhs: BassStream) -> Bool {
        return lhs === rhs
    }
}
