//
//  LyricsViewController.m
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "LyricsViewController.h"
#import "Defines.h"
#import "PlaylistSingleton.h"
#import "SUSLyricsDAO.h"
#import "ISMSSong+DAO.h"
#import "EX2Kit.h"

@implementation LyricsViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil  {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        _dataModel = [[SUSLyricsDAO alloc] init];
		
        // Custom initialization
		self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
		self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        		
		_textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 45, 320, 255)];
		_textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_textView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
		_textView.textColor = [UIColor whiteColor];
		_textView.font = ISMSRegularFont(16.5);
		_textView.editable = NO;
        
		[self updateLyricsLabel];
		[self.view addSubview:_textView];
		
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
		titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		titleLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.font = ISMSBoldFont(30);
		titleLabel.textAlignment = NSTextAlignmentCenter;
		titleLabel.text = @"Lyrics";
		[self.view addSubview:titleLabel];
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:ISMSNotification_LyricsDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:ISMSNotification_LyricsFailed object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_LyricsDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_LyricsFailed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	[self.dataModel cancelLoad];
}

- (void)dealloc {
	_dataModel.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateLyricsLabel {
    ISMSSong *currentSong = playlistS.currentSong;
    NSString *lyrics = [self.dataModel lyricsForArtist:currentSong.artist andTitle:currentSong.title];
    if (!lyrics.hasValue) {
        lyrics = @"\n\nNo lyrics found";
    }
    self.textView.text = lyrics;
}

@end
