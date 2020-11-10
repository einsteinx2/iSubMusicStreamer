//
//  iPhoneStreamingPlayerViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class PageControlViewController, MPVolumeView, OBSlider, Song;

@interface iPhoneStreamingPlayerViewController : UIViewController <AsynchronousImageViewDelegate, UIGestureRecognizerDelegate>

@property NSUInteger reflectionHeight;
@property BOOL isFlipped;
@property BOOL isExtraButtonsShowing;
@property (strong) PageControlViewController *pageControlViewController;
@property uint64_t bookmarkBytePosition;	
@property (strong) MPVolumeView *volumeView;
@property (strong) UISlider *jukeboxVolumeView;
@property (strong) UILabel *artistTitleLabel;
@property (strong) UILabel *albumTitleLabel;
@property (strong) UILabel *songTitleLabel;
@property (strong) IBOutlet UIButton *back30Button;
@property (strong) IBOutlet UIButton *forw30Button;
@property (strong) IBOutlet UIButton *playButton;
@property (strong) IBOutlet UIButton *nextButton;
@property (strong) IBOutlet UIButton *prevButton;
@property (strong) IBOutlet UIButton *eqButton;
@property (strong) IBOutlet UIView *volumeSlider;
@property (strong) IBOutlet AsynchronousImageView *coverArtImageView;
@property (strong) IBOutlet UIImageView *reflectionView;
@property (strong) IBOutlet UIButton *songInfoToggleButton;
@property (strong) UILabel *artistLabel;
@property (strong) UILabel *albumLabel;
@property (strong) UILabel *titleLabel;
@property (strong) IBOutlet UIView *extraButtons;
@property (strong) IBOutlet UIImageView *extraButtonsBackground;
@property (strong) IBOutlet UIButton *extraButtonsButton;
@property (strong) IBOutlet UIView *songInfoView;
@property (strong) IBOutlet UILabel *sliderMultipleLabel;
@property (strong) IBOutlet UILabel *trackLabel;
@property (strong) IBOutlet UILabel *genreLabel;
@property (strong) IBOutlet UILabel *yearLabel;
@property (strong) IBOutlet UILabel *formatLabel;
@property (strong) UIImage *extraButtonsButtonOffImage;
@property (strong) UIImage *extraButtonsButtonOnImage;
@property (strong) IBOutlet UIView *coverArtHolderView;
@property (strong) IBOutlet UIButton *currentAlbumButton;
@property (strong) IBOutlet UIButton *repeatButton;
@property (strong) IBOutlet UIButton *bookmarkButton;
@property (strong) IBOutlet UIButton *shuffleButton;
@property (strong) IBOutlet OBSlider *progressSlider;
@property (strong) IBOutlet UILabel *elapsedTimeLabel;
@property (strong) IBOutlet UILabel *remainingTimeLabel;
@property (strong) UIView *downloadProgress;
@property (strong) NSTimer *updateTimer;
@property (strong) NSTimer *progressTimer;
@property (nonatomic) BOOL pauseSlider;
@property (nonatomic) BOOL hasMoved;
@property (nonatomic) float oldPosition;
@property (nonatomic) NSUInteger byteOffset;
@property (copy) ISMSSong *currentSong;
@property (strong) NSArray *bookmarkEntry;
@property (nonatomic) NSInteger bookmarkIndex;
@property (nonatomic) int bookmarkPosition;
@property (strong) IBOutlet UILabel *quickBackLabel;
@property (strong) IBOutlet UILabel *quickForwLabel;
@property (strong) UISwipeGestureRecognizer *swipeDetector;
@property NSUInteger lastProgress;
@property (strong) IBOutlet UIView *largeOverlayView;
@property (strong) IBOutlet UILabel *largeOverlayArtist;
@property (strong) IBOutlet UILabel *largeOverlaySong;
@property (strong) IBOutlet UILabel *largeOverlayAlbum;

- (void)setPlayButtonImage;
- (void)setPauseButtonImage;
- (IBAction)songInfoToggle:(id)sender;
- (IBAction)playButtonPressed:(id)sender;
- (IBAction)prevButtonPressed:(id)sender;
- (IBAction)nextButtonPressed:(id)sender;
- (IBAction)currentAlbumPressed:(id)sender;

- (void)createSongTitle;
- (void)removeSongTitle;
- (void)setSongTitle;
- (IBAction)toggleExtraButtons:(id)sender;
- (void)extraButtonsToggleAnimated:(BOOL)animated saveState:(BOOL)saveState;

- (void)playlistToggleAnimated:(BOOL)animated saveState:(BOOL)saveState;

- (IBAction)showEq:(id)sender;


- (IBAction)repeatButtonToggle:(id)sender;
- (IBAction)bookmarkButtonToggle:(id)sender;
- (IBAction)shuffleButtonToggle:(id)sender;
- (IBAction)touchedSlider:(id)sender;
- (IBAction)movingSlider:(id)sender;
- (IBAction)movedSlider:(id)sender;

- (IBAction)skipBack30:(id)sender;
- (IBAction)skipForward30:(id)sender;

- (void)updateDownloadProgress;
- (void)updateSlider;
- (void)updateShuffleIcon;

- (void)quickSecondsSetLabels;


@end

