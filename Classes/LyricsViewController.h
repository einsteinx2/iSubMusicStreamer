//
//  LyricsViewController.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//
@class SUSLyricsDAO;

@interface LyricsViewController : UIViewController

@property (strong) SUSLyricsDAO *dataModel;
@property (strong) UITextView *textView;

- (void)updateLyricsLabel;
@end
