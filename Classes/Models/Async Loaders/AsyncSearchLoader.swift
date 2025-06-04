//
//  AsyncSearchLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation

struct SearchAPIResponseData {
    let folderArtists: [FolderArtist]
    let folderAlbums: [FolderAlbum]
    let tagArtists: [TagArtist]
    let tagAlbums: [TagAlbum]
    let songs: [Song]
}

final class AsyncSearchLoader: AsyncAPILoader<SearchAPIResponseData> {
    static let searchItemCount = 20
    
    enum SearchType {
        case old, folder, tag
        var action: SubsonicAction {
            switch self {
            case .old:    return .search
            case .folder: return .search2
            case .tag:    return .search3
            }
        }
        var queryKey: String {
            switch self {
            case .old: return "any"
            default:   return "query"
            }
        }
    }
    
    enum SearchItemType {
        case all, artists, albums, songs
        func parameters(searchType: SearchType, offset: Int) -> [String: Any] {
            guard searchType != .old else {
                return ["count": 20, "offset": offset]
            }
            
            switch self {
            case .all:
                return ["artistCount": searchItemCount, "albumCount": searchItemCount, "songCount": searchItemCount,
                        "artistOffset":         offset, "albumOffset":         offset, "songOffset":         offset]
            case .artists:
                return ["artistCount": searchItemCount, "albumCount":               0, "songCount":               0, "artistOffset": offset]
            case .albums:
                return ["artistCount":               0, "albumCount": searchItemCount, "songCount":               0, "albumOffset":  offset]
            case .songs:
                return ["artistCount":               0, "albumCount":               0, "songCount": searchItemCount, "songOffset":   offset]
            }
        }
    }
    
    let serverId: Int
    let searchType: SearchType
    let searchItemType: SearchItemType
    let query: String
    var offset: Int
    
    init(serverId: Int, searchType: SearchType = .folder, searchItemType: SearchItemType = .all, query: String = "", offset: Int = 0) {
        self.serverId = serverId
        self.searchType = searchType
        self.searchItemType = searchItemType
        self.query = query
        self.offset = offset
        super.init()
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .search }
    
    override func createRequest() -> URLRequest? {
        // Due to a Subsonic bug, to get good search results, we need to add a * to the end of
        // Latin based languages, but not to unicode languages like Japanese.
        var finalQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchType != .old && query.canBeConverted(to: .isoLatin1) {
            finalQuery += "*"
        }
        
        var parameters = searchItemType.parameters(searchType: searchType, offset: offset)
        parameters[searchType.queryKey] = finalQuery
        return URLRequest(serverId: serverId, subsonicAction: searchType.action, parameters: parameters)
    }
    
    override func processResponse(data: Data) async throws -> SearchAPIResponseData {
        try Task.checkCancellation()
        
        guard let root = try await validate(data: data) else {
            throw APIError.responseNotXML
        }
        
        try Task.checkCancellation()
        
        var folderArtists = [FolderArtist]()
        var folderAlbums = [FolderAlbum]()
        var tagArtists = [TagArtist]()
        var tagAlbums = [TagAlbum]()
        var songs = [Song]()
        
        if let searchResult = root.child("searchResult") {
            // Old search
            for try await element in searchResult.iterate("match") {
                songs.append(Song(serverId: self.serverId, element: element))
            }
        } else if let searchResult2 = root.child("searchResult2") {
            // Folder search
            for try await element in searchResult2.iterate("artist") {
                folderArtists.append(FolderArtist(serverId: serverId, element: element))
            }
            try Task.checkCancellation()
            for try await element in searchResult2.iterate("album") {
                folderAlbums.append(FolderAlbum(serverId: serverId, element: element))
            }
            try Task.checkCancellation()
            for try await element in searchResult2.iterate("song") {
                songs.append(Song(serverId: serverId, element: element))
            }
        } else if let searchResult3 = root.child("searchResult3") {
            // Tag search
            for try await element in searchResult3.iterate("artist") {
                tagArtists.append(TagArtist(serverId: serverId, element: element))
            }
            try Task.checkCancellation()
            for try await element in searchResult3.iterate("album") {
                tagAlbums.append(TagAlbum(serverId: serverId, element: element))
            }
            try Task.checkCancellation()
            for try await element in searchResult3.iterate("song") {
                songs.append(Song(serverId: serverId, element: element))
            }
        }
        
        return SearchAPIResponseData(folderArtists: folderArtists, folderAlbums: folderAlbums, tagArtists: tagArtists, tagAlbums: tagAlbums, songs: songs)
    }
}
