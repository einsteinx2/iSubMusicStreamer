//
//  ArtistsViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

protocol ArtistsViewModel: AnyObject {
    var delegate: APILoaderDelegate? { get set }
    
    var serverId: Int { get set }
    var mediaFolderId: Int { get set }
    
    var itemType: String { get }
    
    var tableSections: [TableSection] { get }
    
    var isCached: Bool { get }
    var count: Int { get }
    var searchCount: Int { get }
    var reloadDate: Date? { get }
    
    func reset()
    
    func artist(indexPath: IndexPath) -> Artist?
    func artistInSearch(indexPath: IndexPath) -> Artist?
    func clearSearch()
    func search(name: String)
    func continueSearch()
    
    func startLoad()
    func cancelLoad()
}
