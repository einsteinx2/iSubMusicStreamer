//
//  AsyncCoverArtLoader.swift
//  iSub
//
//  Created by Ben Baron on 6/3/25.
//  Copyright © 2025 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class AsyncCoverArtLoader: AsyncAPILoader<CoverArt> {
    @Injected private var store: Store
    
    let serverId: Int
    let coverArtId: String
    let isLarge: Bool
    
    init(serverId: Int, coverArtId: String, isLarge: Bool) {
        self.serverId = serverId
        self.coverArtId = coverArtId
        self.isLarge = isLarge
        super.init()
    }

    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .coverArt }
    
    override func createRequest() -> URLRequest? {
        let scale = UIScreen.main.scale
        var size = scale * 80
        if isLarge {
            size = UIDevice.isPad ? scale * 1080 : scale * 640
        }
        return URLRequest(serverId: serverId, subsonicAction: .getCoverArt, parameters: ["id": coverArtId, "size": size])
    }
    
    override func processResponse(data: Data) async throws -> CoverArt {
        try Task.checkCancellation()
        
        let coverArt = CoverArt(serverId: serverId, id: coverArtId, isLarge: isLarge, data: data)
        guard let _ = coverArt.image else {
            throw APIError.dataNotFound
        }
        
        return coverArt
    }
}
