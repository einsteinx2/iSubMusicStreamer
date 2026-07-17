//
//  ContextQueueStore.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjackSwift

// Per-context play queue snapshots: every library context (a server, or the Combined
// Library as context 0) keeps its own copy of the play/shuffle queues plus the
// playback state needed to restore them (indexes, shuffle/repeat mode, seek
// position). The live queue stays in the reserved localPlaylist rows 1/2; switching
// contexts saves the outgoing context here and reloads the incoming one (the swap
// APIs land with the context switcher). activeQueueContext is a single-row marker
// recording which context currently owns the live rows, so a crash between the
// database swap and the UserDefaults context write can be healed at launch.
enum ContextQueue {
    struct Table {
        static let contextQueueState = "contextQueueState"
        static let contextQueueSong = "contextQueueSong"
        static let activeQueueContext = "activeQueueContext"
    }

    // Which live queue a snapshot row belongs to
    enum QueueKind: Int {
        case play = 0
        case shuffle = 1
    }

    enum StateColumn: String, ColumnExpression {
        case contextId, isShuffle, repeatMode, normalIndex, shuffleIndex, seekTime, byteOffset, kiloBitrate, savedDate
    }
    enum SongColumn: String, ColumnExpression {
        case contextId, queueKind, position, serverId, songId
    }
    enum MarkerColumn: String, ColumnExpression {
        case id, contextId
    }

    static func createLibraryContextsSchema(_ db: Database, legacyContextId: Int) throws {
        try db.create(table: Table.contextQueueState) { t in
            t.column(StateColumn.contextId, .integer).notNull().primaryKey()
            t.column(StateColumn.isShuffle, .boolean).notNull().defaults(to: false)
            t.column(StateColumn.repeatMode, .integer).notNull().defaults(to: 0)
            t.column(StateColumn.normalIndex, .integer).notNull().defaults(to: 0)
            t.column(StateColumn.shuffleIndex, .integer).notNull().defaults(to: 0)
            t.column(StateColumn.seekTime, .double).notNull().defaults(to: 0)
            t.column(StateColumn.byteOffset, .integer).notNull().defaults(to: 0)
            t.column(StateColumn.kiloBitrate, .integer).notNull().defaults(to: 0)
            t.column(StateColumn.savedDate, .datetime).notNull()
        }

        try db.create(table: Table.contextQueueSong) { t in
            t.column(SongColumn.contextId, .integer).notNull()
            t.column(SongColumn.queueKind, .integer).notNull()
            t.column(SongColumn.position, .integer).notNull()
            t.column(SongColumn.serverId, .integer).notNull()
            t.column(SongColumn.songId, .text).notNull()
        }
        try db.create(indexOn: Table.contextQueueSong, columns: [SongColumn.contextId, SongColumn.queueKind, SongColumn.position])
        try db.create(indexOn: Table.contextQueueSong, columns: [SongColumn.serverId, SongColumn.songId])

        try db.create(table: Table.activeQueueContext) { t in
            t.column(MarkerColumn.id, .integer).primaryKey().check { $0 == 0 }
            t.column(MarkerColumn.contextId, .integer).notNull()
        }
        try db.execute(sql: "INSERT INTO \(Table.activeQueueContext) (id, contextId) VALUES (0, ?)", arguments: [legacyContextId])
    }
}
