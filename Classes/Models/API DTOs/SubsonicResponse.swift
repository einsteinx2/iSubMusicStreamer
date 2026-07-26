//
//  SubsonicResponse.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Decode-only DTOs mirroring the Subsonic API wire schema. One set of types decodes
// both wire formats: JSON via SubsonicJSON.decoder and XML via SubsonicXMLDecoder
// (attributes become fields, repeated child elements become arrays, element text
// becomes "value"). These are deliberately separate from the domain models, whose
// synthesized Codable conformances drive GRDB column names.
//
// Every field except ids is Optional: the API models tolerate any missing attribute,
// and the DTO layer must not turn tolerated server quirks into hard decode failures.

struct SubsonicEnvelope: Decodable, Equatable {
    let response: SubsonicResponse

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }
}

extension SubsonicEnvelope {
    /// Decodes either wire format by sniffing the first meaningful byte, so a server
    /// that answers XML despite f=json (or vice versa) parses fine. Throws
    /// DecodingError; callers translate into their own error domains.
    static func decode(from data: Data) throws -> SubsonicEnvelope {
        switch firstMeaningfulByte(of: data) {
        case UInt8(ascii: "{"):
            return try SubsonicJSON.decode(SubsonicEnvelope.self, from: data)
        case UInt8(ascii: "<"):
            return try SubsonicXMLDecoder.decode(SubsonicEnvelope.self, from: data)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Data is neither JSON nor XML"))
        }
    }

    private static func firstMeaningfulByte(of data: Data) -> UInt8? {
        var bytes = data[...]
        // Skip a UTF-8 BOM if present
        if bytes.count >= 3, bytes.prefix(3).elementsEqual([0xEF, 0xBB, 0xBF]) {
            bytes = bytes.dropFirst(3)
        }
        return bytes.first { $0 != 0x09 && $0 != 0x0A && $0 != 0x0D && $0 != 0x20 }
    }
}

struct SubsonicResponse: Decodable, Equatable {
    let status: String?
    let version: String?
    let type: String?
    let serverVersion: String?
    let openSubsonic: Bool?
    let error: SubsonicErrorDTO?

    // At most one of these is non-nil per endpoint
    let musicFolders: MusicFoldersDTO?
    let indexes: IndexesDTO?
    let directory: DirectoryDTO?
    let artists: ArtistsID3DTO?
    let artist: ArtistID3DTO?
    let album: AlbumID3DTO?
    let song: ChildDTO?
    let randomSongs: SongListDTO?
    let albumList: AlbumListDTO?
    let searchResult: SearchResultDTO?
    let searchResult2: SearchResult2DTO?
    let searchResult3: SearchResult3DTO?
    let nowPlaying: NowPlayingDTO?
    let chatMessages: ChatMessagesDTO?
    let lyrics: LyricsDTO?
    let playlists: PlaylistsDTO?
    let playlist: PlaylistDTO?
    let jukeboxStatus: JukeboxStatusDTO?
    let jukeboxPlaylist: JukeboxStatusDTO?
}

struct SubsonicErrorDTO: Decodable, Equatable {
    let code: Int
    let message: String?
}

struct LyricsDTO: Decodable, Equatable {
    let artist: String?
    let title: String?
    let value: String?
}

struct MusicFoldersDTO: Decodable, Equatable {
    let musicFolder: LenientArray<MusicFolderDTO>?
}

struct MusicFolderDTO: Decodable, Equatable {
    let id: SubsonicID
    let name: String?
}

struct ChatMessagesDTO: Decodable, Equatable {
    let chatMessage: LenientArray<ChatMessageDTO>?
}

struct ChatMessageDTO: Decodable, Equatable {
    let username: String?
    let time: Int?
    let message: String?
}

// Shared by the jukeboxStatus and jukeboxPlaylist payloads (identical attributes;
// only jukeboxPlaylist carries entry children)
struct JukeboxStatusDTO: Decodable, Equatable {
    let currentIndex: Int?
    let playing: Bool?
    let gain: Double?
    let position: Int?
    let entry: LenientArray<ChildDTO>?
}
