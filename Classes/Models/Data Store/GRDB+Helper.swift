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
    
    public func primaryKey(_ columnExpressions: [ColumnExpression], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        let columns = columnExpressions.map({ $0.name })
        self.primaryKey(columns, onConflict: conflictResolution)
    }
    
    public func uniqueKey(_ columnExpressions: [ColumnExpression], onConflict conflictResolution: Database.ConflictResolution? = nil) {
        let columns = columnExpressions.map({ $0.name })
        self.uniqueKey(columns, onConflict: conflictResolution)
    }
}

extension Database {
    public func create(index name: String, on table: String, columnExpressions: [ColumnExpression], unique: Bool = false, ifNotExists: Bool = false, condition: SQLExpressible? = nil) throws {
        let columns = columnExpressions.map({ $0.name })
        try self.create(index: name, on: table, columns: columns, unique: unique, ifNotExists: ifNotExists, condition: condition)
    }
    
    public func create(indexOn table: String, columns: [ColumnExpression], unique: Bool = false, ifNotExists: Bool = false, condition: SQLExpressible? = nil) throws {
        let columnNames = columns.map({ $0.name })
        let name = "\(table)_on_\(columnNames.joined(separator: "_"))"
        try self.create(index: name, on: table, columns: columnNames, unique: unique, ifNotExists: ifNotExists, condition: condition)
    }
}
