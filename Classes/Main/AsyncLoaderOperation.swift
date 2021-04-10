//
//  AsyncLoaderOperation.swift
//  iSub
//
//  Created by Benjamin Baron on 4/10/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class AsyncLoaderOperation: AsyncOperation {
    private let loader: APILoader
    
    init(loader: APILoader) {
        self.loader = loader
    }
    
    override func main() {
        loader.callback = { _, _, _ in
            self.finish()
        }
        loader.startLoad()
    }
    
    override func cancel() {
        loader.cancelLoad()
        super.cancel()
    }
}
