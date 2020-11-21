//
//  ChatViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SUSLoaderDelegate.h"

@class CustomUITextView, SUSChatDAO;

@interface ChatViewController : UITableViewController <UITextViewDelegate, SUSLoaderDelegate>

@property (strong) UIView *headerView;
@property (strong) CustomUITextView *textInput;
@property BOOL isNoChatMessagesScreenShowing;
@property (strong) UIImageView *noChatMessagesScreen;
@property (strong) NSMutableArray *chatMessages;
@property (strong) NSMutableData *receivedData;
@property NSInteger lastCheck;
@property (strong) SUSChatDAO *dataModel;

- (void)cancelLoad;

@end
