//
//  QuickAlbumsViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface QuickAlbumsViewController : UIViewController <ISMSLoaderDelegate>

@property (nonatomic, weak) UIViewController *parent;

@property (nonatomic, strong) NSDictionary *titles;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) IBOutlet UIButton *randomButton;
@property (nonatomic, strong) IBOutlet UIButton *frequentButton;
@property (nonatomic, strong) IBOutlet UIButton *newestButton;
@property (nonatomic, strong) IBOutlet UIButton *recentButton;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;

- (IBAction)random;
- (IBAction)frequent;
- (IBAction)newest;
- (IBAction)recent;
- (IBAction)cancel;

- (void)cancelLoad;

@end
