//
//  CombinedBrowseStore.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

// A (serverId, artistId) reference into a merged root list — ids alone are ambiguous
// once more than one server contributes rows
struct ArtistRef: Equatable {
    let serverId: Int
    let id: String
}

// Which media folder each server contributes: the Combined Library honors every
// server's own saved dropdown selection
struct ServerMediaFolderSelection: Equatable {
    let serverId: Int
    let mediaFolderId: Int
}

struct CombinedRootList {
    let refs: [ArtistRef]
    let sections: [TableSection]
    // nil when no contributing server has a cached list yet; otherwise the oldest
    // reload across them (the honest "last reload" for a merged view)
    let oldestReloadDate: Date?
}

// Merged root-list queries for the Combined Library: every server's cached
// folder/tag artist list in one alphabetical list (no dedup — duplicates appear once
// per server, side by side). Sections are computed from leading characters, so
// article-aware server index rules ("The Beatles" under B) are not preserved in the
// merged view.
extension Store {
    func combinedFolderArtists(selections: [ServerMediaFolderSelection]) -> CombinedRootList {
        combinedRootList(selections: selections, listTable: "folderArtistList", idColumn: "folderArtistId",
                         artistTable: "folderArtist", metadataTable: "folderArtistListMetadata")
    }

    func combinedTagArtists(selections: [ServerMediaFolderSelection]) -> CombinedRootList {
        combinedRootList(selections: selections, listTable: "tagArtistList", idColumn: "tagArtistId",
                         artistTable: "tagArtist", metadataTable: "tagArtistListMetadata")
    }

    func searchCombinedFolderArtists(name: String, selections: [ServerMediaFolderSelection], offset: Int, limit: Int) -> [ArtistRef] {
        combinedArtistSearch(name: name, selections: selections, listTable: "folderArtistList",
                             idColumn: "folderArtistId", artistTable: "folderArtist", offset: offset, limit: limit)
    }

    func searchCombinedTagArtists(name: String, selections: [ServerMediaFolderSelection], offset: Int, limit: Int) -> [ArtistRef] {
        combinedArtistSearch(name: name, selections: selections, listTable: "tagArtistList",
                             idColumn: "tagArtistId", artistTable: "tagArtist", offset: offset, limit: limit)
    }

    // The selections are trusted integers from the store, interpolated textually to
    // build the OR clause (GRDB literals can't parameterize a variable-length one)
    private static func selectionClauses(_ selections: [ServerMediaFolderSelection], table: String) -> String {
        selections
            .map { "(\(table).serverId = \($0.serverId) AND \(table).mediaFolderId = \($0.mediaFolderId))" }
            .joined(separator: " OR ")
    }

    private func combinedRootList(selections: [ServerMediaFolderSelection], listTable: String, idColumn: String,
                                  artistTable: String, metadataTable: String) -> CombinedRootList {
        guard !selections.isEmpty else { return CombinedRootList(refs: [], sections: [], oldestReloadDate: nil) }
        do {
            return try pool.read { db in
                let sql = """
                    SELECT l.serverId AS serverId, l.\(idColumn) AS artistId, a.name AS name
                    FROM \(listTable) l
                    JOIN \(artistTable) a ON a.serverId = l.serverId AND a.id = l.\(idColumn)
                    WHERE \(Self.selectionClauses(selections, table: "l"))
                    ORDER BY a.name COLLATE NOCASE ASC, l.serverId ASC
                    """
                var refs = [ArtistRef]()
                var sections = [TableSection]()
                let rows = try Row.fetchCursor(db, sql: sql)
                while let row = try rows.next() {
                    let name: String = row["name"]
                    refs.append(ArtistRef(serverId: row["serverId"], id: row["artistId"]))
                    let sectionName = Self.sectionName(for: name)
                    if let last = sections.last, last.name == sectionName {
                        sections[sections.count - 1] = TableSection(serverId: last.serverId, mediaFolderId: last.mediaFolderId,
                                                                    name: last.name, position: last.position, itemCount: last.itemCount + 1)
                    } else {
                        sections.append(TableSection(serverId: LibraryContext.combinedContextId, mediaFolderId: MediaFolder.allFoldersId,
                                                     name: sectionName, position: refs.count - 1, itemCount: 1))
                    }
                }

                let dateSql = """
                    SELECT MIN(reloadDate) FROM \(metadataTable)
                    WHERE \(Self.selectionClauses(selections, table: metadataTable))
                    """
                let oldestReloadDate = try Date.fetchOne(db, sql: dateSql)
                return CombinedRootList(refs: refs, sections: sections, oldestReloadDate: oldestReloadDate)
            }
        } catch {
            DDLogError("Failed to select the combined \(artistTable) list: \(error)")
            return CombinedRootList(refs: [], sections: [], oldestReloadDate: nil)
        }
    }

    private func combinedArtistSearch(name: String, selections: [ServerMediaFolderSelection], listTable: String,
                                      idColumn: String, artistTable: String, offset: Int, limit: Int) -> [ArtistRef] {
        guard !selections.isEmpty else { return [] }
        do {
            return try pool.read { db in
                let sql = """
                    SELECT l.serverId AS serverId, l.\(idColumn) AS artistId
                    FROM \(listTable) l
                    JOIN \(artistTable) a ON a.serverId = l.serverId AND a.id = l.\(idColumn)
                    WHERE (\(Self.selectionClauses(selections, table: "l"))) AND a.name LIKE ?
                    ORDER BY a.name COLLATE NOCASE ASC, l.serverId ASC
                    LIMIT ? OFFSET ?
                    """
                let rows = try Row.fetchAll(db, sql: sql, arguments: ["%\(name)%", limit, offset])
                return rows.map { ArtistRef(serverId: $0["serverId"], id: $0["artistId"]) }
            }
        } catch {
            DDLogError("Failed to search the combined \(artistTable) list for \(name): \(error)")
            return []
        }
    }

    // Letters group under their uppercased initial; everything else under "#"
    // (NOCASE sorting puts those rows first, so "#" leads the index)
    private static func sectionName(for name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespaces).first else { return "#" }
        return first.isLetter ? String(first).uppercased() : "#"
    }
}
