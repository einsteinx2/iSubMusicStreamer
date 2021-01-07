//
//  GRDB+Helper.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import GRDB

extension TableDefinition {
    @discardableResult
    func column(_ columnExpression: ColumnExpression, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        self.column(columnExpression.name, type)
    }
    
    @discardableResult
    func column(_ column: Column, _ type: Database.ColumnType? = nil) -> ColumnDefinition {
        self.column(column.name, type)
    }
    
    @discardableResult
    public func autoIncrementedPrimaryKey(_ columnExpression: ColumnExpression, onConflict conflictResolution: Database.ConflictResolution? = nil) -> ColumnDefinition {
        self.autoIncrementedPrimaryKey(columnExpression.name, onConflict: conflictResolution)
    }
    
    @discardableResult
    public func autoIncrementedPrimaryKey(_ column: Column, onConflict conflictResolution: Database.ConflictResolution? = nil) -> ColumnDefinition {
        self.autoIncrementedPrimaryKey(column.name, onConflict: conflictResolution)
    }
}
