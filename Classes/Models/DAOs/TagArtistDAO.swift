//
//  TagArtistDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc final class TagArtistDAO: NSObject {
    private let artistId: String
    private var loader: TagArtistLoader?
    private var tagAlbums = [TagAlbum]()
    
    @objc weak var delegate: SUSLoaderDelegate?
    
    @objc var hasLoaded: Bool { tagAlbums.count > 0 }
    @objc var albumCount: Int { tagAlbums.count }
    
    @objc init(artistId: String, delegate: SUSLoaderDelegate?) {
        self.artistId = artistId
        self.delegate = delegate
        super.init()
        loadTagAlbums()
    }
    
    deinit {
        loader?.cancelLoad()
    }
    
    @objc func tagAlbum(row: Int) -> TagAlbum {
        return tagAlbums[row]
    }
    
    private func loadTagAlbums() {
        tagAlbums.removeAll()
        Database.shared().serverDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT * FROM tagAlbum WHERE artistId = ? ORDER BY itemOrder ASC", artistId) {
                while result.next() {
                    tagAlbums.append(TagAlbum(result: result))
                }
            } else {
                DDLogError("[TagArtistDAO] Failed to read albums for artistId \(artistId)")
            }
        }
    }
}

@objc extension TagArtistDAO: SUSLoaderManager {
    func startLoad() {
        loader = TagArtistLoader(artistId: artistId) { [unowned self] success, error, _ in
            tagAlbums = self.loader?.tagAlbums ?? [TagAlbum]()
            self.loader = nil
            
            if success {
                delegate?.loadingFinished(nil)
            } else {
                delegate?.loadingFailed(nil, withError: error)
            }
        }
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader = nil
    }
}
