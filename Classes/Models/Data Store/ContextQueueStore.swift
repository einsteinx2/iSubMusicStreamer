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

// The playback state saved alongside a context's queue snapshot: everything needed to
// come back to a context exactly where it was left (paused at the same position)
struct PlayQueueStateSnapshot: Equatable {
    var isShuffle = false
    var repeatMode: RepeatMode = .none
    var normalIndex = 0
    var shuffleIndex = 0
    var seekTime = 0.0
    var byteOffset = 0
    var kiloBitrate = 0
}

extension Store {
    /// ONE write transaction: snapshot the live queue rows (play + shuffle) and the
    /// playback state under the outgoing context (when non-nil), replace the live rows
    /// and their songCounts from the incoming context's snapshot, and move the
    /// activeQueueContext marker. Restoring copies — a context's snapshot persists
    /// until its next save. An incoming context with no snapshot (or -1) restores a
    /// clean empty queue. The jukebox queue rows (3/4) are not part of context state.
    func swapLiveQueue(outgoingContextId: Int?, outgoingState: PlayQueueStateSnapshot?, incomingContextId: Int) -> PlayQueueStateSnapshot {
        do {
            return try pool.write { db in
                if let outgoingContextId {
                    try saveQueueSnapshot(db, contextId: outgoingContextId, state: outgoingState ?? PlayQueueStateSnapshot())
                }
                let incomingState = try queueStateSnapshot(db, contextId: incomingContextId) ?? PlayQueueStateSnapshot()
                try loadQueueSnapshotIntoLiveRows(db, contextId: incomingContextId)
                try db.execute(sql: "UPDATE \(ContextQueue.Table.activeQueueContext) SET contextId = ? WHERE id = 0",
                               arguments: [incomingContextId])
                return incomingState
            }
        } catch {
            DDLogError("Failed to swap the live queue from context \(String(describing: outgoingContextId)) to \(incomingContextId): \(error)")
            return PlayQueueStateSnapshot()
        }
    }

    // Which context currently owns the live queue rows (the crash-heal marker)
    func liveQueueContextId() -> Int? {
        do {
            return try pool.read { db in
                try Int.fetchOne(db, sql: "SELECT contextId FROM \(ContextQueue.Table.activeQueueContext) WHERE id = 0")
            }
        } catch {
            DDLogError("Failed to read the live queue context marker: \(error)")
            return nil
        }
    }

    /// Launch-time healing for a crash between the queue swap's database commit and
    /// the UserDefaults context write: when the marker disagrees with the persisted
    /// active context, re-restore that context from its snapshot (which the
    /// interrupted swap already saved). A matching marker is the normal case and must
    /// leave the live rows alone — they are fresher than the snapshot.
    func reconcileLiveQueue(activeContextId: Int) {
        guard let marker = liveQueueContextId(), marker != activeContextId else { return }
        _ = swapLiveQueue(outgoingContextId: nil, outgoingState: nil, incomingContextId: activeContextId)
    }

    func contextQueueState(contextId: Int) -> PlayQueueStateSnapshot? {
        do {
            return try pool.read { db in
                try queueStateSnapshot(db, contextId: contextId)
            }
        } catch {
            DDLogError("Failed to read the queue state snapshot for context \(contextId): \(error)")
            return nil
        }
    }

    private func saveQueueSnapshot(_ db: Database, contextId: Int, state: PlayQueueStateSnapshot) throws {
        try db.execute(sql: "DELETE FROM \(ContextQueue.Table.contextQueueSong) WHERE contextId = ?", arguments: [contextId])
        let liveQueues: [(kind: ContextQueue.QueueKind, playlistId: Int)] = [
            (.play, LocalPlaylist.Default.playQueueId),
            (.shuffle, LocalPlaylist.Default.shuffleQueueId),
        ]
        for (kind, playlistId) in liveQueues {
            try db.execute(sql: """
                INSERT INTO \(ContextQueue.Table.contextQueueSong) (contextId, queueKind, position, serverId, songId)
                SELECT ?, ?, position, serverId, songId
                FROM localPlaylistSong
                WHERE localPlaylistId = ?
                """, arguments: [contextId, kind.rawValue, playlistId])
        }
        try db.execute(sql: """
            INSERT INTO \(ContextQueue.Table.contextQueueState)
            (contextId, isShuffle, repeatMode, normalIndex, shuffleIndex, seekTime, byteOffset, kiloBitrate, savedDate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(contextId) DO UPDATE SET
                isShuffle = excluded.isShuffle,
                repeatMode = excluded.repeatMode,
                normalIndex = excluded.normalIndex,
                shuffleIndex = excluded.shuffleIndex,
                seekTime = excluded.seekTime,
                byteOffset = excluded.byteOffset,
                kiloBitrate = excluded.kiloBitrate,
                savedDate = excluded.savedDate
            """, arguments: [contextId, state.isShuffle, state.repeatMode.rawValue, state.normalIndex, state.shuffleIndex,
                             state.seekTime, state.byteOffset, state.kiloBitrate, Date()])
    }

    private func queueStateSnapshot(_ db: Database, contextId: Int) throws -> PlayQueueStateSnapshot? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM \(ContextQueue.Table.contextQueueState) WHERE contextId = ?",
                                         arguments: [contextId]) else { return nil }
        return PlayQueueStateSnapshot(isShuffle: row["isShuffle"],
                                      repeatMode: RepeatMode(rawValue: row["repeatMode"]) ?? .none,
                                      normalIndex: row["normalIndex"],
                                      shuffleIndex: row["shuffleIndex"],
                                      seekTime: row["seekTime"],
                                      byteOffset: row["byteOffset"],
                                      kiloBitrate: row["kiloBitrate"])
    }

    private func loadQueueSnapshotIntoLiveRows(_ db: Database, contextId: Int) throws {
        let liveQueues: [(kind: ContextQueue.QueueKind, playlistId: Int)] = [
            (.play, LocalPlaylist.Default.playQueueId),
            (.shuffle, LocalPlaylist.Default.shuffleQueueId),
        ]
        for (kind, playlistId) in liveQueues {
            try db.execute(sql: "DELETE FROM localPlaylistSong WHERE localPlaylistId = ?", arguments: [playlistId])
            try db.execute(sql: """
                INSERT INTO localPlaylistSong (localPlaylistId, position, serverId, songId)
                SELECT ?, position, serverId, songId
                FROM \(ContextQueue.Table.contextQueueSong)
                WHERE contextId = ? AND queueKind = ?
                ORDER BY position ASC
                """, arguments: [playlistId, contextId, kind.rawValue])
            try db.execute(sql: """
                UPDATE localPlaylist
                SET songCount = (SELECT COUNT(*) FROM localPlaylistSong WHERE localPlaylistId = ?)
                WHERE id = ?
                """, arguments: [playlistId, playlistId])
        }
    }
}
