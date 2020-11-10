//
//  HelpTabViewController.h
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface HelpTabViewController : UIViewController <UIWebViewDelegate>

@property (strong) IBOutlet UIWebView *helpWebView;
@property (strong) IBOutlet UIActivityIndicatorView *loadingIndicator;

@end
