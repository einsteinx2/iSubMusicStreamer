//
//  PlayQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift

@objc final class PlayQueueViewController: UIViewController {
    private let saveEditHeader = SaveEditHeader(saveType: "playlist", countType: "song")
    private let tableView = UITableView()
        
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    private func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: ISMSNotification_BassInitialized)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: ISMSNotification_BassFreed)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: ISMSNotification_CurrentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: ISMSNotification_CurrentPlaylistShuffleToggled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxSongInfoUpdated), name: ISMSNotification_JukeboxSongInfo)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songsQueued), name: ISMSNotification_CurrentPlaylistSongsQueued)
    }
    
    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_BassInitialized)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_BassFreed)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistIndexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistShuffleToggled)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_JukeboxSongInfo)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistSongsQueued)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(named: "isubBackgroundColor")
        title = "Play Queue"
        
        if isModal {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismiss(sender:)))
        }
        
        registerForNotifications()
        
        saveEditHeader.delegate = self
        saveEditHeader.count = PlayQueue.shared.count
        view.addSubview(saveEditHeader)
        saveEditHeader.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.leading.trailing.top.equalToSuperview()
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(named: "isubBackgroundColor")
        tableView.separatorStyle = .none
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        tableView.rowHeight = Defines.rowHeight
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(saveEditHeader.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectRow()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
        if isEditing {
            setEditing(false, animated: true)
        }
    }
    
    @objc private func selectRow() {
        tableView.reloadData()
        let currentIndex = PlayQueue.shared.currentIndex
        if currentIndex >= 0 && currentIndex < PlayQueue.shared.count {
            tableView.selectRow(at: IndexPath(row: currentIndex, section: 0), animated: false, scrollPosition: .top)
        }
    }
    
    @objc private func jukeboxSongInfoUpdated() {
        saveEditHeader.count = PlayQueue.shared.count
        tableView.reloadData()
        selectRow()
    }
    
    @objc private func songsQueued() {
        saveEditHeader.count = PlayQueue.shared.count
        tableView.reloadData()
    }
    
    @objc private func dismiss(sender: Any) {
        if let navigationController = navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        saveEditHeader.setEditing(editing, animated: animated)
        
        if isEditing {
            // Deselect all the rows
            for i in 0..<PlayQueue.shared.count {
                tableView.deselectRow(at: IndexPath(row: i, section: 0), animated: false)
            }
            saveEditHeader.selectedCount = 0
        } else {
            selectRow()
            saveEditHeader.selectedCount = PlayQueue.shared.count
        }
    }
    
    var selectedRows: [Int] {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            return indexPathsForSelectedRows.map { $0.row }
        }
        return []
    }
    
    var selectedRowsCount: Int {
        return tableView.indexPathsForSelectedRows?.count ?? 0
    }
    
    private func showSavePlaylistAlert(local: Bool) {
        //    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save Playlist" message:nil preferredStyle:UIAlertControllerStyleAlert];
        //    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        //        textField.placeholder = @"Playlist name";
        //    }];
        //    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //        NSString *name = [[[alert textFields] firstObject] text];
        //        if (self.savePlaylistLocal || settingsS.isOfflineMode) {
        //            // Check if the playlist exists, if not create the playlist table and add the entry to localPlaylists table
        //            NSString *test = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT md5 FROM localPlaylists WHERE md5 = ?", name.md5];
        //            if (test) {
        //                // If it exists, ask to overwrite
        //                [self showOverwritePlaylistAlert:name];
        //            } else {
        //                NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
        //                NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
        //                NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
        //                NSString *table = PlayQueue.shared.isShuffle ? shufTable : currTable;
        //
        //                [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
        //                    [db executeUpdate:@"INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)", name, name.md5];
        //                    [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", name.md5, ISMSSong.standardSongColumnSchema]];
        //
        //                    [db executeUpdate:@"ATTACH DATABASE ? AS ?", [settingsS.databasePath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
        //                    if (db.hadError) { DDLogError(@"[CurrentPlaylistViewController] Err attaching the currentPlaylistDb %d: %@", db.lastErrorCode, db.lastErrorMessage); }
        //                    [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", name.md5, table]];
        //                    [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
        //                }];
        //            }
        //        } else {
        //            NSString *tableName = [NSString stringWithFormat:@"splaylist%@", name.md5];
        //            if ([databaseS.localPlaylistsDbQueue tableExists:tableName]) {
        //                // If it exists, ask to overwrite
        //                [self showOverwritePlaylistAlert:name];
        //            } else {
        //                [self uploadPlaylist:name];
        //            }
        //        }
        //    }]];
        //    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        //    [self presentViewController:alert animated:YES completion:nil];
    }
    
    private func showOverwritePlaylistAlert(local: Bool, name: String) {
        //    NSString *message = [NSString stringWithFormat:@"A playlist named \"%@\" already exists. Would you like to overwrite it?", name];
        //    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Overwrite?" message:message preferredStyle:UIAlertControllerStyleAlert];
        //    [alert addAction:[UIAlertAction actionWithTitle:@"Overwrite" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        //        // If yes, overwrite the playlist
        //        if (self.savePlaylistLocal || settingsS.isOfflineMode) {
        //            NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", settingsS.urlString.md5];
        //            NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
        //            NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
        //            NSString *table = PlayQueue.shared.isShuffle ? shufTable : currTable;
        //
        //            [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
        //                [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE playlist%@", name.md5]];
        //                [db executeUpdate:[NSString stringWithFormat:@"CREATE TABLE playlist%@ (%@)", name.md5, ISMSSong.standardSongColumnSchema]];
        //
        //                [db executeUpdate:@"ATTACH DATABASE ? AS ?", [settingsS.databasePath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
        //                if (db.hadError) { DDLogError(@"[CurrentPlaylistViewController] Err attaching the currentPlaylistDb %d: %@", db.lastErrorCode, db.lastErrorMessage); }
        //                [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO playlist%@ SELECT * FROM %@", name.md5, table]];
        //                [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
        //            }];
        //        } else {
        //            [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
        //                [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE splaylist%@", name.md5]];
        //            }];
        //
        //            [self uploadPlaylist:name];
        //        }
        //    }]];
        //    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        //    [self presentViewController:alert animated:YES completion:nil];
    }
    
    private func updateTableCellNumbers() {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            for indexPath in indexPathsForSelectedRows {
                if let cell = tableView.cellForRow(at: indexPath) as? UniversalTableViewCell {
                    cell.number = indexPath.row + 1
                }
            }
        }
    }
    
    private func uploadPlaylist(name: String) {
        //    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(name), @"name", nil];
        //    NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:self.currentPlaylistCount];
        //    NSString *currTable = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
        //    NSString *shufTable = settingsS.isJukeboxEnabled ? @"jukeboxShufflePlaylist" : @"shufflePlaylist";
        //    NSString *table = PlayQueue.shared.isShuffle ? shufTable : currTable;
        //
        //    [databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
        //         for (int i = 0; i < self.currentPlaylistCount; i++) {
        //             @autoreleasepool {
        //                 ISMSSong *aSong = [ISMSSong songFromDbRow:i inTable:table inDatabase:db];
        //                 [songIds addObject:n2N(aSong.songId)];
        //             }
        //         }
        //     }];
        //    [parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
        //
        //    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
        //    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //        [EX2Dispatch runInMainThreadAsync:^{
        //            if (error) {
        //                // Inform the user that the connection failed.
        //                if (settingsS.isPopupsEnabled) {
        //                    NSString *message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", (long)error.code, error.localizedDescription];
        //                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        //                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        //                    [self presentViewController:alert animated:YES completion:nil];
        //                }
        //
        //                self.tableView.scrollEnabled = YES;
        //                [viewObjectsS hideLoadingScreen];
        //            } else {
        //                RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
        //                if (!root.isValid) {
        //                    NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
        //                    [self subsonicErrorCode:nil message:error.description];
        //                } else {
        //                    RXMLElement *error = [root child:@"error"];
        //                    if (error.isValid)
        //                    {
        //                        NSString *code = [error attribute:@"code"];
        //                        NSString *message = [error attribute:@"message"];
        //                        [self subsonicErrorCode:code message:message];
        //                    }
        //                }
        //
        //                self.tableView.scrollEnabled = YES;
        //                [viewObjectsS hideLoadingScreen];
        //            }
        //        }];
        //    }];
        //    [dataTask resume];
        //
        //    self.tableView.scrollEnabled = NO;
        //    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    }
    
    //- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    //    DDLogError(@"[CurrentPlaylistViewController] subsonic error %@: %@", errorCode, message);
    //    if (settingsS.isPopupsEnabled) {
    //        [EX2Dispatch runInMainThreadAsync:^{
    //            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    //            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    //            [self presentViewController:alert animated:YES completion:nil];
    //        }];
    //    }
    //}
    
    
}

extension PlayQueueViewController: SaveEditHeaderDelegate {
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
        if saveEditHeader.deleteLabel.isHidden {
            if !isEditing {
                if Settings.shared().isOfflineMode {
                    showSavePlaylistAlert(local: true)
                } else {
                    let message = "Would you like to save this playlist to your device or to your Subsonic server?"
                    let alert = UIAlertController(title: "Playlist Location", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Local", style: .default, handler: { _ in
                        self.showSavePlaylistAlert(local: true)
                    }))
                    alert.addAction(UIAlertAction(title: "Server", style: .default, handler: { _ in
                        self.showSavePlaylistAlert(local: false)
                    }))
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    present(alert, animated: true, completion: nil)
                }
            }
        } else {
            unregisterForNotifications()
            
            if selectedRowsCount == 0 {
                // Select all the rows
                for i in 0..<PlayQueue.shared.count {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
                saveEditHeader.selectedCount = PlayQueue.shared.count
            } else {
                // Delete action
                PlayQueue.shared.removeSongs(indexes: selectedRows)
                saveEditHeader.count = PlayQueue.shared.count
                tableView.deleteRows(at: tableView.indexPathsForSelectedRows ?? [], with: .automatic)
                updateTableCellNumbers()
                setEditing(false, animated: true)
            }
            
            if !Settings.shared().isJukeboxEnabled {
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistOrderChanged)
            }
            
            registerForNotifications()
        }
    }
    
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!self.isEditing, animated: true)
    }
}

extension PlayQueueViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return PlayQueue.shared.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.number = indexPath.row + 1
        cell.update(model: PlayQueue.shared.song(index: indexPath.row))
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        _ = PlayQueue.shared.moveSong(fromIndex: sourceIndexPath.row, toIndex: destinationIndexPath.row)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
        
        if isModal {
            dismiss(sender: self)
            EX2Dispatch.runInMainThread(afterDelay: 0.5) {
                Music.shared().playSong(atPosition: indexPath.row)
            }
        } else {
            Music.shared().playSong(atPosition: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = PlayQueue.shared.song(index: indexPath.row), !song.isVideo {
            return SwipeAction.downloadQueueAndDeleteConfig(model: song) { [unowned self] in
                PlayQueue.shared.removeSongs(indexes: [indexPath.row])
                self.saveEditHeader.count = PlayQueue.shared.count
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
        return nil
    }
}
