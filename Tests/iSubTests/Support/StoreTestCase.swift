//
//  StoreTestCase.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import XCTest
@testable import iSub_Beta

// Base class for tests that need an in-memory Store registered in the DI container
// (so model classes that resolve Store, like Song, see the same database)
class StoreTestCase: SandboxedTestCase {
    private(set) var store: Store!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = Store()
        store.setup(location: .memory)
        let injectedStore: Store = store
        TestContainer.register { injectedStore }
    }

    override func tearDownWithError() throws {
        store = nil
        try super.tearDownWithError()
    }
}

// Factories for quickly constructing model values in tests
enum TestData {
    static func song(serverId: Int = 1,
                     id: String = "1",
                     title: String = "Test Song",
                     path: String = "Artist/Album/01 Test Song.mp3",
                     tagArtistId: String? = nil,
                     tagAlbumId: String? = nil,
                     tagArtistName: String? = "Test Artist",
                     tagAlbumName: String? = "Test Album",
                     parentFolderId: String? = nil,
                     coverArtId: String? = nil,
                     suffix: String = "mp3",
                     transcodedSuffix: String? = nil,
                     duration: Int = 240,
                     kiloBitrate: Int = 320,
                     track: Int? = nil,
                     discNumber: Int? = nil,
                     size: Int = 9_600_000,
                     isVideo: Bool = false,
                     createdDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
                     starredDate: Date? = nil) -> Song {
        Song(serverId: serverId, id: id, title: title, coverArtId: coverArtId, parentFolderId: parentFolderId,
             tagArtistName: tagArtistName, tagAlbumName: tagAlbumName, playCount: nil, year: nil,
             tagArtistId: tagArtistId, tagAlbumId: tagAlbumId, genre: nil, path: path, suffix: suffix,
             transcodedSuffix: transcodedSuffix, duration: duration, kiloBitrate: kiloBitrate, track: track,
             discNumber: discNumber, size: size, isVideo: isVideo, createdDate: createdDate, starredDate: starredDate)
    }

    static func server(id: Int = 1, urlString: String = "https://music.example.com:8080/subsonic", username: String = "user") -> Server {
        Server(id: id, type: .subsonic, url: URL(string: urlString)!, username: username, password: "password")
    }
}
