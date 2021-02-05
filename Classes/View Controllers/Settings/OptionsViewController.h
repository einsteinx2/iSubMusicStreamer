//
//  OptionsViewController.h
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OptionsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;
@property (nonatomic, strong) IBOutlet UIView *scrollViewContents;

@property (nonatomic, strong) IBOutlet UILabel *versionLabel;
@property (nonatomic, strong) IBOutlet UISwitch *manualOfflineModeSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *autoReloadArtistSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *disablePopupsSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *disableRotationSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *disableScreenSleepSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *enableBasicAuthSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *disableCellUsageSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableSongsTabLabel;
@property (nonatomic, strong) IBOutlet UILabel *enableSongsTabDesc;
@property (nonatomic, strong) IBOutlet UISegmentedControl *recoverSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxBitrateWifiSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxBitrate3GSegmentedControl;
@property (nonatomic, strong) IBOutlet UISwitch *autoPlayerInfoSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *enableSwipeSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *enableTapAndHoldSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableManualCachingOnWWANLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableManualCachingOnWWANSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableSongCachingLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableSongCachingSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableNextSongCacheLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableNextSongCacheSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableNextSongPartialCacheLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableNextSongPartialCacheSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableBackupCacheLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableBackupCacheSwitch;
@property (nonatomic, strong) IBOutlet UISegmentedControl *cachingTypeSegmentedControl;
@property (nonatomic) NSInteger totalSpace;
@property (nonatomic) NSInteger freeSpace;
@property (nonatomic) IBOutlet UILabel *cacheSpaceLabel1;
@property (nonatomic, strong) IBOutlet UITextField *cacheSpaceLabel2;
@property (nonatomic, strong) IBOutlet UILabel *freeSpaceLabel;
@property (nonatomic, strong) IBOutlet UILabel *totalSpaceLabel;
@property (nonatomic, strong) IBOutlet UIView *totalSpaceBackground;
@property (nonatomic, strong) IBOutlet UIView *freeSpaceBackground;
@property (nonatomic, strong) IBOutlet UISlider *cacheSpaceSlider;
@property (nonatomic, strong) IBOutlet UILabel *cacheSpaceDescLabel;
@property (nonatomic, strong) IBOutlet UISwitch *autoDeleteCacheSwitch;
@property (nonatomic, strong) IBOutlet UISegmentedControl *autoDeleteCacheTypeSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *cacheSongCellColorSegmentedControl;
@property (nonatomic, strong) IBOutlet UISwitch *enableScrobblingSwitch;
@property (nonatomic, strong) IBOutlet UILabel *scrobblePercentLabel;
@property (nonatomic, strong) IBOutlet UISlider *scrobblePercentSlider;
@property (nonatomic, strong) IBOutlet UISegmentedControl *quickSkipSegmentControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *secondsToStartPlayerSegmentControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *secondsToBufferSegmentControl;
@property (nonatomic, strong) IBOutlet UISwitch *enableLockScreenArt;
@property (nonatomic, strong) IBOutlet UILabel *enableLockArtLabel;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxVideoBitrateWifiSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxVideoBitrate3GSegmentedControl;
@property (nonatomic, strong) NSDate *loadedTime;
@property (nonatomic, strong) IBOutlet UIButton *resetAlbumArtCacheButton;
@property (nonatomic, strong) IBOutlet UIButton *shareLogsButton;
@property (nonatomic, strong) IBOutlet UIButton *openSourceLicensesButton;

@property (nonatomic, strong) IBOutletCollection(UISwitch) NSArray *switches;

- (void)toggleCacheControlsVisibility;
- (void)cachingTypeToggle;
- (IBAction)segmentAction:(id)sender;
- (IBAction)switchAction:(id)sender;
- (IBAction)updateMinFreeSpaceLabel;
- (IBAction)updateMinFreeSpaceSetting;
- (IBAction)revertMinFreeSpaceSlider;
- (IBAction)updateScrobblePercentLabel;
- (IBAction)updateScrobblePercentSetting;
- (IBAction)resetAlbumArtCacheAction;
- (IBAction)shareAppLogsAction;
- (IBAction)viewOpenSourceLicensesAction;
- (void)textFieldDidChange:(UITextField *)textField;

@end
