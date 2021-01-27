//
//  Decoding+Generic.swift
//  iSub
//
//  Created by Benjamin Baron on 1/26/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Combine

// Decode using type inference (why Apple didn't just write these we may never know...)
extension KeyedDecodingContainer {
    func decode<T: Decodable>(forKey key: KeyedDecodingContainer<K>.Key) throws -> T {
        try decode(T.self, forKey: key)
    }
    
    func decodeIfPresent<T: Decodable>(forKey key: KeyedDecodingContainer<K>.Key) throws -> T? {
        try decodeIfPresent(T.self, forKey: key)
    }
}

extension TopLevelDecoder {

//    /// The type this decoder accepts.
//    associatedtype Input

    /// Decodes an instance of the indicated type.
    func decode<T: Decodable>(from: Self.Input) throws -> T {
        try decode(T.self, from: from)
    }
}
