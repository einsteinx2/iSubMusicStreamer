//
//  SwipeAction.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import ProgressHUD

// Haptic info: https://medium.com/@sdrzn/make-your-ios-app-feel-better-a-comprehensive-guide-over-taptic-engine-and-haptic-feedback-724dec425f10

struct SwipeAction {
    static func downloadAndQueueConfig(model: TableCellModel) -> UISwipeActionsConfiguration? {
        let actions = model.isDownloaded ? [queue(model: model)] : [download(model: model), queue(model: model)];
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    static func downloadQueueAndDeleteConfig(model: TableCellModel, deleteHandler: @escaping () -> ()) -> UISwipeActionsConfiguration? {
        let actions: [UIContextualAction]
        if !model.isDownloaded && model.isDownloadable {
            actions = [download(model: model), queue(model: model), delete(handler: deleteHandler)]
        } else {
            actions = [queue(model: model), delete(handler: deleteHandler)]
        }
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    static func downloadQueueAndDeleteConfig(model: TableCellModel, downloadHandler: (() -> ())?, queueHandler: (() -> ())?, deleteHandler: (() -> ())?) -> UISwipeActionsConfiguration {
        var actions = [UIContextualAction]()
        if let downloadHandler {
            actions.append(download(model: model, handler: downloadHandler))
        }
        if let queueHandler {
            actions.append(queue(model: model, handler: queueHandler))
        }
        if let deleteHandler {
            actions.append(delete(handler: deleteHandler))
        }
        
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    private static func download(model: TableCellModel) -> UIContextualAction {
        return download(model: model, handler: model.download)
    }
    
    private static func queue(model: TableCellModel) -> UIContextualAction {
        return queue(model: model, handler: model.queue)
    }
    
    private static func download(model: TableCellModel, handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Download") { _, _, completionHandler in
            handler()
            ProgressHUD.banner("Added to download queue", model.primaryLabelText)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            completionHandler(true)
        }
        action.backgroundColor = .systemBlue
        return action
    }
    
    private static func queue(model: TableCellModel, handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Queue") { _, _, completionHandler in
            handler()
            ProgressHUD.banner("Added to play queue", model.primaryLabelText)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            completionHandler(true)
        }
        action.backgroundColor = .systemGreen
        return action
    }
    
    private static func delete(handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Delete") { _, _, completionHandler in
            handler()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            completionHandler(true)
        }
        action.backgroundColor = .systemRed
        return action
    }
}
