//
//  SwipeAction.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

// Haptic info: https://medium.com/@sdrzn/make-your-ios-app-feel-better-a-comprehensive-guide-over-taptic-engine-and-haptic-feedback-724dec425f10

struct SwipeAction {
    static func downloadAndQueueConfig(model: TableCellModel?) -> UISwipeActionsConfiguration? {
        guard let model = model else { return nil }
        
        let actions = model.isDownloaded ? [queue(model: model)] : [download(model: model), queue(model: model)];
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    static func downloadQueueAndDeleteConfig(model: TableCellModel?, deleteHandler: @escaping () -> ()) -> UISwipeActionsConfiguration? {
        guard let model = model else { return nil }
        
        let actions = !model.isDownloaded && model.isDownloadable ? [download(model: model), queue(model: model), delete(handler: deleteHandler)] : [queue(model: model), delete(handler: deleteHandler)]
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    static func downloadQueueAndDeleteConfig(downloadHandler: (() -> ())?, queueHandler: (() -> ())?, deleteHandler: (() -> ())?) -> UISwipeActionsConfiguration {
        var actions = [UIContextualAction]()
        if let downloadHandler = downloadHandler {
            actions.append(download(handler: downloadHandler))
        }
        if let queueHandler = queueHandler {
            actions.append(queue(handler: queueHandler))
        }
        if let deleteHandler = deleteHandler {
            actions.append(delete(handler: deleteHandler))
        }
        
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false;
        return config;
    }
    
    private static func download(model: TableCellModel) -> UIContextualAction {
        return download(handler: model.download)
    }
    
    private static func queue(model: TableCellModel) -> UIContextualAction {
        return queue(handler: model.queue)
    }
    
    private static func download(handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Download") { _, _, completionHandler in
            handler()
            SlidingNotification.showOnMainWindow(message: "Added to download queue", duration: 1.0)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            completionHandler(true)
        }
        action.backgroundColor = .systemBlue
        return action
    }
    
    private static func queue(handler: @escaping () -> ()) -> UIContextualAction {
        let action = UIContextualAction(style: .normal, title: "Queue") { _, _, completionHandler in
            handler()
            SlidingNotification.showOnMainWindow(message: "Added to play queue", duration: 1.0)
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
