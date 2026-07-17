//
//  CombinedBrowseStoreTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The merged root-list queries behind the Combined Library's Folders/Artists tabs:
// alphabetical across servers (no dedup), sections computed over the union, each
// server contributing its own media-folder selection.
final class CombinedBrowseStoreTests: StoreTestCase {

    private func addTagArtist(serverId: Int, id: String, name: String, mediaFolderId: Int = MediaFolder.allFoldersId) {
        let artist = TagArtist(serverId: serverId,
                               element: try! XMLTestHelpers.element(tag: "artist", xml: "<artist id=\"\(id)\" name=\"\(name)\" albumCount=\"1\"/>"))
        XCTAssertTrue(store.add(tagArtist: artist, mediaFolderId: mediaFolderId))
    }

    private func addMetadata(serverId: Int, mediaFolderId: Int = MediaFolder.allFoldersId, reloadDate: Date) {
        XCTAssertTrue(store.add(tagArtistListMetadata: RootListMetadata(serverId: serverId, mediaFolderId: mediaFolderId,
                                                                        itemCount: 1, reloadDate: reloadDate)))
    }

    func testCombinedListMergesAlphabeticallyAcrossServers() {
        addTagArtist(serverId: 1, id: "10", name: "Beatles")
        addTagArtist(serverId: 1, id: "11", name: "Zappa")
        addTagArtist(serverId: 2, id: "20", name: "Aerosmith")
        addTagArtist(serverId: 2, id: "21", name: "beatles")

        let list = store.combinedTagArtists(selections: [ServerMediaFolderSelection(serverId: 1, mediaFolderId: MediaFolder.allFoldersId),
                                                         ServerMediaFolderSelection(serverId: 2, mediaFolderId: MediaFolder.allFoldersId)])

        XCTAssertEqual(list.refs.map(\.id), ["20", "10", "21", "11"], "case-insensitive name order, server order on ties")
        XCTAssertEqual(list.refs.map(\.serverId), [2, 1, 2, 1])
        XCTAssertEqual(list.sections.map(\.name), ["A", "B", "Z"])
        XCTAssertEqual(list.sections.map(\.position), [0, 1, 3])
        XCTAssertEqual(list.sections.map(\.itemCount), [1, 2, 1])
    }

    func testCombinedListHonorsEachServersFolderSelection() {
        addTagArtist(serverId: 1, id: "10", name: "In Folder Five", mediaFolderId: 5)
        addTagArtist(serverId: 1, id: "11", name: "In Folder Six", mediaFolderId: 6)
        addTagArtist(serverId: 2, id: "20", name: "All Folders")

        let list = store.combinedTagArtists(selections: [ServerMediaFolderSelection(serverId: 1, mediaFolderId: 5),
                                                         ServerMediaFolderSelection(serverId: 2, mediaFolderId: MediaFolder.allFoldersId)])

        XCTAssertEqual(list.refs.map(\.id), ["20", "10"], "server 1 contributes only its selected folder")
    }

    func testNonLetterNamesGroupUnderHashFirst() {
        addTagArtist(serverId: 1, id: "10", name: "22-20s")
        addTagArtist(serverId: 1, id: "11", name: "Abba")

        let list = store.combinedTagArtists(selections: [ServerMediaFolderSelection(serverId: 1, mediaFolderId: MediaFolder.allFoldersId)])

        XCTAssertEqual(list.sections.map(\.name), ["#", "A"])
    }

    func testOldestReloadDateAcrossServers() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        addTagArtist(serverId: 1, id: "10", name: "One")
        addTagArtist(serverId: 2, id: "20", name: "Two")
        addMetadata(serverId: 1, reloadDate: newer)
        addMetadata(serverId: 2, reloadDate: older)

        let selections = [ServerMediaFolderSelection(serverId: 1, mediaFolderId: MediaFolder.allFoldersId),
                          ServerMediaFolderSelection(serverId: 2, mediaFolderId: MediaFolder.allFoldersId)]
        XCTAssertEqual(store.combinedTagArtists(selections: selections).oldestReloadDate, older)

        XCTAssertNil(store.combinedTagArtists(selections: [ServerMediaFolderSelection(serverId: 9, mediaFolderId: -1)]).oldestReloadDate,
                     "no cached metadata means not cached")
    }

    func testCombinedSearchPagesAcrossServers() {
        addTagArtist(serverId: 1, id: "10", name: "The Band")
        addTagArtist(serverId: 2, id: "20", name: "Band of Horses")
        addTagArtist(serverId: 1, id: "11", name: "Unrelated")

        let selections = [ServerMediaFolderSelection(serverId: 1, mediaFolderId: MediaFolder.allFoldersId),
                          ServerMediaFolderSelection(serverId: 2, mediaFolderId: MediaFolder.allFoldersId)]
        let refs = store.searchCombinedTagArtists(name: "band", selections: selections, offset: 0, limit: 10)

        XCTAssertEqual(refs.map(\.id), ["20", "10"], "matches from every server, name-ordered")

        let paged = store.searchCombinedTagArtists(name: "band", selections: selections, offset: 1, limit: 10)
        XCTAssertEqual(paged.map(\.id), ["10"])
    }

    func testDeleteMediaFoldersIsServerScoped() {
        XCTAssertTrue(store.add(mediaFolders: [MediaFolder(serverId: 1, id: 5, name: "Music"),
                                               MediaFolder(serverId: 2, id: 5, name: "Music")]))

        XCTAssertTrue(store.deleteMediaFolders(serverId: 1))

        XCTAssertTrue(store.mediaFolders(serverId: 1).isEmpty)
        XCTAssertEqual(store.mediaFolders(serverId: 2).count, 1,
                       "one server's reload must not clobber another's folders")
    }
}
