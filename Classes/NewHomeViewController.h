//
//  NewHomeViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class AsynchronousImageView;

@interface NewHomeViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIButton *playerButton;
@property (nonatomic, strong) IBOutlet UIButton *jukeboxButton;
@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UISegmentedControl *searchSegment;
@property (nonatomic, strong) IBOutlet UIView *searchSegmentBackground;
@property (nonatomic, strong) UIView *searchOverlay;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic) BOOL isSearch;
@property (nonatomic, strong) IBOutlet UILabel *quickLabel;
@property (nonatomic, strong) IBOutlet UILabel *shuffleLabel;
@property (nonatomic, strong) IBOutlet UILabel *jukeboxLabel;
@property (nonatomic, strong) IBOutlet UILabel *settingsLabel;
@property (nonatomic, strong) IBOutlet UILabel *chatLabel;
@property (nonatomic, strong) IBOutlet UILabel *playerLabel;
@property (nonatomic, strong) UIButton *coverArtBorder;
@property (nonatomic, strong) AsynchronousImageView *coverArtView;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *albumLabel;
@property (nonatomic, strong) UILabel *songLabel;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *receivedData;

@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *topRow;
@property (nonatomic, strong) IBOutletCollection(UILabel) NSArray *topRowLabels;

@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *bottomRow;
@property (nonatomic, strong) IBOutletCollection(UILabel) NSArray *bottomRowLabels;

- (IBAction)quickAlbums;
- (IBAction)serverShuffle;
- (IBAction)settings;
- (IBAction)player;
- (IBAction)jukebox;
- (IBAction)chat;

- (IBAction)support:(id)sender;

- (void)initSongInfo;

- (void)performServerShuffle:(NSNotification*)notification;

- (void)cancelLoad;

@end
