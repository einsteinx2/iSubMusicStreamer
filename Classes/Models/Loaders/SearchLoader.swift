//
//  SearchLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 2/16/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class SearchLoader: APILoader {
    static let searchItemCount = 20
    
    enum SearchType {
        case old, folder, tag
        var action: String {
            switch self {
            case .old:    return "search"
            case .folder: return "search2"
            case .tag:    return "search3"
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
    
    private(set) var folderArtists = [FolderArtist]()
    private(set) var folderAlbums = [FolderAlbum]()
    private(set) var tagArtists = [TagArtist]()
    private(set) var tagAlbums = [TagAlbum]()
    private(set) var songs = [Song]()
    
    init(serverId: Int, searchType: SearchType = .folder, searchItemType: SearchItemType = .all, query: String = "", offset: Int = 0, delegate: APILoaderDelegate? = nil, callback: APILoaderCallback? = nil) {
        self.serverId = serverId
        self.searchType = searchType
        self.searchItemType = searchItemType
        self.query = query
        self.offset = offset
        super.init(delegate: delegate, callback: callback)
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
    
    override func processResponse(data: Data) {
        folderArtists.removeAll()
        folderAlbums.removeAll()
        tagArtists.removeAll()
        tagAlbums.removeAll()
        songs.removeAll()
        guard let root = validate(data: data) else { return }
        
        if let searchResult = root.child("searchResult") {
            // Old search
            searchResult.iterate("match") { element, _ in
                self.songs.append(Song(serverId: self.serverId, element: element))
            }
        } else if let searchResult2 = root.child("searchResult2") {
            // Folder search
            searchResult2.iterate("artist") { element, _ in
                self.folderArtists.append(FolderArtist(serverId: self.serverId, element: element))
            }
            searchResult2.iterate("album") { element, _ in
                self.folderAlbums.append(FolderAlbum(serverId: self.serverId, element: element))
            }
            searchResult2.iterate("song") { element, _ in
                self.songs.append(Song(serverId: self.serverId, element: element))
            }
        } else if let searchResult3 = root.child("searchResult3") {
            // Tag search
            searchResult3.iterate("artist") { element, _ in
                self.tagArtists.append(TagArtist(serverId: self.serverId, element: element))
            }
            searchResult3.iterate("album") { element, _ in
                self.tagAlbums.append(TagAlbum(serverId: self.serverId, element: element))
            }
            searchResult3.iterate("song") { element, _ in
                self.songs.append(Song(serverId: self.serverId, element: element))
            }
        }
        
        informDelegateLoadingFinished()
    }
}
