//
//  AsyncBlockOperation.swift
//  iSub
//
//  Created by Benjamin Baron on 4/10/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

final class AsyncBlockOperation: AsyncOperation, @unchecked Sendable {
    private let block: (_ completion: @escaping () -> Void) -> Void
    
    init(block: @escaping (_ completion: @escaping () -> Void) -> ()) {
        self.block = block
    }
    
    override func main() {
        block {
            self.finish()
        }
    }
}
