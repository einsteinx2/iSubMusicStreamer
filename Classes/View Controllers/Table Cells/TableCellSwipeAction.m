//
//  TableCellSwipeAction.m
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

#import "SwipeAction.h"

@implementation SwipeAction

+ (UIContextualAction *)downloadAction:(NSObject<ISMSTableCellModel> *)model {
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"Download"
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [model download];
    }];
    action.backgroundColor = UIColor.systemBlueColor;
    return action;
}

+ (UIContextualAction *)queueAction:(NSObject<ISMSTableCellModel> *)model {
    UIContextualAction *action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"Queue"
                                                                       handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [model queue];
    }];
    action.backgroundColor = UIColor.systemGreenColor;
    return action;
}

@end
