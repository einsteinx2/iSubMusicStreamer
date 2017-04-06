//
//  EqualizerViewController.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "DDSocialDialog.h"

@class EqualizerView, EqualizerPointView, EqualizerPathView, BassParamEqValue, BassEffectDAO, SnappySlider;
@interface EqualizerViewController : UIViewController <DDSocialDialogDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDataSource, UIPickerViewDelegate>

@property (strong) UIView *overlay;
@property (strong) UIButton *dismissButton;
@property (strong) IBOutlet UIView *controlsContainer;
@property BOOL isPresetPickerShowing;
@property (strong) IBOutlet UIPickerView *presetPicker;
@property (strong) IBOutlet UILabel *presetLabel;
@property (strong) IBOutlet UIButton *toggleButton;
@property (strong) IBOutlet EqualizerPathView *equalizerPath;
@property (strong) IBOutlet EqualizerView *equalizerView;
@property (strong) NSMutableArray *equalizerPointViews;
@property (strong) IBOutlet SnappySlider *gainSlider;
@property (strong) IBOutlet UILabel *gainBoostAmountLabel;
@property (strong) IBOutlet UILabel *gainBoostLabel;
@property CGFloat lastGainValue;
@property (strong) BassEffectDAO *effectDAO;
@property (strong) EqualizerPointView *selectedView;
@property (strong) UIButton *deletePresetButton;
@property (strong) UIButton *savePresetButton;
@property BOOL isSavePresetButtonShowing;
@property BOOL isDeletePresetButtonShowing;
@property (strong) DDSocialDialog *saveDialog;
@property BOOL wasVisualizerOffBeforeRotation;
@property (strong) UISwipeGestureRecognizer *swipeDetectorLeft;
@property (strong) UISwipeGestureRecognizer *swipeDetectorRight;
@property (strong) IBOutlet UIView *landscapeButtonsHolder;

- (IBAction)dismiss:(id)sender;
- (IBAction)type:(id)sender;
- (IBAction)toggle:(id)sender;
- (void)updateToggleButton;

- (void)createEqViews;
- (void)removeEqViews;

- (void)promptForSavePresetName;
- (void)hideSavePresetButton:(BOOL)animated;
- (void)showSavePresetButton:(BOOL)animated;
- (void)hideDeletePresetButton:(BOOL)animated;
- (void)showDeletePresetButton:(BOOL)animated;
- (void)saveTempCustomPreset;

- (IBAction)movedGainSlider:(id)sender;

@end
