//
//  SubsonicJSON.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

enum SubsonicJSON {
    /// JSONDecoder configured for Subsonic API responses (date strings parsed with
    /// the same rules as the XML path so both formats produce identical values).
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = SubsonicDateParsing.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized Subsonic date format: \(string)")
            }
            return date
        }
        return decoder
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder().decode(T.self, from: data)
    }
}
