//
//  SubsonicLenient.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Subsonic-family servers disagree on JSON value shapes, so the DTO layer uses these
// wrapper types (not property wrappers, which break decodeIfPresent for optional fields).

/// Navidrome sends ids as JSON strings, classic Subsonic and some others as numbers.
/// Decodes either into a String. XML attribute values are always strings.
struct SubsonicID: Decodable, Equatable, Hashable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a string or integer id"))
        }
    }
}

/// Some server serializers emit a lone object where the schema says array (a single
/// child element serialized without the surrounding list). Decodes either into [Element].
struct LenientArray<Element: Decodable & Equatable>: Decodable, Equatable {
    let values: [Element]

    init(_ values: [Element]) {
        self.values = values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            values = try container.decode([Element].self)
        } catch DecodingError.typeMismatch {
            values = [try container.decode(Element.self)]
        }
    }
}
