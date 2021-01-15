//
//  LocalPlaylistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

@objc final class LocalPlaylistViewController: UITableViewController {
    @Injected private var store: Store
    
    private let localPlaylist: LocalPlaylist
    
    @objc init(localPlaylist: LocalPlaylist) {
        self.localPlaylist = localPlaylist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = localPlaylist.name
        
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        
        if !Settings.shared().isOfflineMode {
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
            
            let saveButton = UIButton(type: .custom)
            saveButton.frame = CGRect(x: 0, y: 0, width: 320, height: 50)
            saveButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            saveButton.addTarget(self, action: #selector(uploadPlaylist), for: .touchUpInside)
            saveButton.setTitle("Save to Server", for: .normal)
            saveButton.setTitleColor(.systemBlue, for: .normal)
            saveButton.titleLabel?.textAlignment = .center
            saveButton.titleLabel?.font = .boldSystemFont(ofSize: 24)
            headerView.addSubview(saveButton)
            
            tableView.tableHeaderView = headerView
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "music.quarternote.3"), style: .plain, target: self, action: #selector(nowPlayingAction))
        }
    }
    
    @objc private func nowPlayingAction() {
        let controller = PlayerViewController()
        controller.hidesBottomBarWhenPushed = true
        pushCustom(controller)
    }
    
    @objc private func uploadPlaylist() {
        // TODO: implement this
    //    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.title), @"name", nil];
    //
    //    NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5];
    //    NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:query];
    //    NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:count];
    //    for (int i = 1; i <= count; i++) {
    //        @autoreleasepool {
    //            NSString *query = [NSString stringWithFormat:@"SELECT songId FROM playlist%@ WHERE ROWID = %i", self.md5, i];
    //            NSString *songId = [databaseS.localPlaylistsDbQueue stringForQuery:query];
    //
    //            [songIds addObject:n2N(songId)];
    //        }
    //    }
    //    [parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
    //
    //    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
    //    self.dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    //        if (error) {
    //            if (settingsS.isPopupsEnabled) {
    //                [EX2Dispatch runInMainThreadAsync:^{
    //                    NSString *message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", (long)error.code, error.localizedDescription];
    //                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    //                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    //                    [self presentViewController:alert animated:YES completion:nil];
    //                }];
    //            }
    //        } else {
    //            DDLogVerbose(@"[PlaylistSongsViewController] upload playlist response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    //            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
    //            if (!root.isValid) {
    //                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
    //                [self subsonicErrorCode:nil message:error.description];
    //            } else {
    //                RXMLElement *error = [root child:@"error"];
    //                if (error.isValid) {
    //                    NSString *code = [error attribute:@"code"];
    //                    NSString *message = [error attribute:@"message"];
    //                    [self subsonicErrorCode:code message:message];
    //                }
    //            }
    //        }
    //
    //        [EX2Dispatch runInMainThreadAsync:^{
    //            self.tableView.scrollEnabled = YES;
    //            [viewObjectsS hideLoadingScreen];
    //            [self.refreshControl endRefreshing];
    //        }];
    //    }];
    //    [self.dataTask resume];
    //
    //    self.tableView.scrollEnabled = NO;
    //    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        return store.song(localPlaylistId: localPlaylist.id, position: indexPath.row)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return localPlaylist.songCount
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideNumberLabel = false
        cell.hideCoverArt = false
        cell.hideDurationLabel = false
        cell.hideSecondaryLabel = false
        cell.number = indexPath.row + 1
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
        EX2Dispatch.runInBackgroundAsync {
            // TODO: implement this
            
            EX2Dispatch.runInMainThreadAsync {
                ViewObjects.shared().hideLoadingScreen()
//                if !song.isVideo {
//                    showPlayer()
//                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath) {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
}
