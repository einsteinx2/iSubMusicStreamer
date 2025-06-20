//
//  ContextMenu.swift
//  iSub
//
//  Created by Benjamin Baron on 2/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import ProgressHUD

// NOTE: When exporting from Icons8, add a stroke width of 2px in black

extension UIViewController {
    private var store: Store { Resolver.resolve() }
    
    func contextMenuDownloadAndQueueConfig(model: TableCellModel) -> UIContextMenuConfiguration? {        
        // Navigation Actions
        let artistAction = tagArtistAction(model: model)
        let albumAction = tagAlbumAction(model: model)
        let navigationActionsMenu = menu(actions: [artistAction, albumAction])
        
        // Item Actions
        let downloadAction = !model.isDownloaded && model.isDownloadable ? download(model: model) : nil
        let queueAction = queue(model: model)
        let queueNextAction = queueNext(model: model)
        let itemActionsMenu = menu(actions: [downloadAction, queueAction, queueNextAction])
        
        // Main Menu
        let mainMenu = menu(submenus: [navigationActionsMenu, itemActionsMenu].compactMap({ $0 }))
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            return mainMenu
        }
    }
    
    private func menu(actions: [UIAction?], title: String = "", displayInline: Bool = true) -> UIMenu? {
        let children = actions.compactMap({ $0 })
        if children.count > 0 {
            let options: UIMenu.Options = displayInline ? [.displayInline] : []
            return UIMenu(title: title, options: options, children: children)
        }
        return nil
    }
    
    private func menu(submenus: [UIMenu?], title: String = "", displayInline: Bool = true) -> UIMenu? {
        let children = submenus.compactMap({ $0 })
        if children.count > 0 {
            let options: UIMenu.Options = displayInline ? [.displayInline] : []
            return UIMenu(title: title, options: options, children: children)
        }
        return nil
    }
    
    private func tagArtistAction(model: TableCellModel) -> UIAction? {
        if let tagArtistId = model.tagArtistId {
            return UIAction(title: "View Artist", image: UIImage(systemName: "person")) { _ in
                if let tagArtist = self.store.tagArtist(serverId: model.serverId, id: tagArtistId) {
                    self.pushViewControllerCustom(TagArtistViewController(tagArtist: tagArtist))
                } else {
                    HUD.show()
                    Task {
                        do {
                            defer {
                                HUD.hide()
                            }
                            _ = try await AsyncTagArtistLoader(serverId: model.serverId, tagArtistId: tagArtistId).load()
                            if let tagArtist = self.store.tagArtist(serverId: model.serverId, id: tagArtistId) {
                                self.pushViewControllerCustom(TagArtistViewController(tagArtist: tagArtist))
                            } else {
                                throw APIError.dataNotFound
                            }
                        } catch {
                            ProgressHUD.banner("Error loading the artist", model.primaryLabelText)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func tagAlbumAction(model: TableCellModel) -> UIAction? {
        if let tagAlbumId = model.tagAlbumId {
            let image = UIImage(named: "icons8-cd")?.with(insets: 1.5)?.withTintColor(.label)
            return UIAction(title: "View Album", image: image) { _ in
                if let tagAlbum = self.store.tagAlbum(serverId: model.serverId, id: tagAlbumId) {
                    self.pushViewControllerCustom(TagAlbumViewController(tagAlbum: tagAlbum))
                } else {
                    HUD.show()
                    Task {
                        do {
                            defer {
                                HUD.hide()
                            }
                            _ = try await AsyncTagAlbumLoader(serverId: model.serverId, tagAlbumId: tagAlbumId).load()                            
                            if let tagAlbum = self.store.tagAlbum(serverId: model.serverId, id: tagAlbumId) {
                                self.pushViewControllerCustom(TagAlbumViewController(tagAlbum: tagAlbum))
                            } else {
                                throw APIError.dataNotFound
                            }
                        } catch {
                            ProgressHUD.banner("Error loading the artist", model.primaryLabelText)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func download(model: TableCellModel) -> UIAction {
        return download(model: model, handler: model.download)
    }
    
    private func queue(model: TableCellModel) -> UIAction {
        return queue(model: model, handler: model.queue)
    }
    
    private func queueNext(model: TableCellModel) -> UIAction {
        return queueNext(model: model, handler: model.queueNext)
    }
    
    private func download(model: TableCellModel, handler: @escaping () -> ()) -> UIAction {
        return UIAction(title: "Download", image: UIImage(systemName: "square.and.arrow.down")) { _ in
            handler()
            ProgressHUD.banner("Added to download queue", model.primaryLabelText)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func queue(model: TableCellModel, handler: @escaping () -> ()) -> UIAction {
        return UIAction(title: "Queue", image: UIImage(systemName: "plus.square")) { _ in
            handler()
            ProgressHUD.banner("Added to play queue", model.primaryLabelText)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func queueNext(model: TableCellModel, handler: @escaping () -> ()) -> UIAction {
        return UIAction(title: "Queue Next", image: UIImage(systemName: "plus.circle")) { _ in
            handler()
            ProgressHUD.banner("Added next in play queue", model.primaryLabelText)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func delete(handler: @escaping () -> ()) -> UIAction {
        return UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            handler()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
