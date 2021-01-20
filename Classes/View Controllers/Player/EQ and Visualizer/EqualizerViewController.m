//
//  EqualizerViewController.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "EqualizerViewController.h"
#import "EqualizerView.h"
#import "EqualizerPointView.h"
#import "EqualizerPathView.h"
#import "SnappySlider.h"
#import "Flurry.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "EX2Kit.h"
#import "Swift.h"

@implementation EqualizerViewController

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (UIInterfaceOrientationIsPortrait(UIApplication.orientation)) {
            self.navigationController.navigationBarHidden = NO;
            
            self.equalizerSeparatorLine.alpha = 1.0;
            self.equalizerPath.alpha = 1.0;
            self.equalizerView.frame = self.equalizerPath.frame;
            for (EqualizerPointView *view in self.equalizerPointViews) {
                view.alpha = 1.0;
            }
            
            UIDevice *device = [UIDevice currentDevice];
            if (device.batteryState != UIDeviceBatteryStateCharging && device.batteryState != UIDeviceBatteryStateFull) {
                if (settingsS.isScreenSleepEnabled) {
                    UIApplication.sharedApplication.idleTimerDisabled = NO;
                }
            }
            
            if (!UIDevice.isPad) {
                self.controlsContainer.alpha = 1.0;
                self.controlsContainer.userInteractionEnabled = YES;
                
                if (self.wasVisualizerOffBeforeRotation) {
                    [self.equalizerView changeType:ISMSBassVisualType_none];
                }
            }
        } else {
            self.navigationController.navigationBarHidden = YES;
            
            self.equalizerSeparatorLine.alpha = 0.0;
            self.equalizerPath.alpha = 0.0;
            self.equalizerView.frame = self.view.bounds;
            for (EqualizerPointView *view in self.equalizerPointViews) {
                view.alpha = 0.0;
            }
            
            UIApplication.sharedApplication.idleTimerDisabled = YES;
            
            if (!UIDevice.isPad) {
                [self dismissPicker];
                
                self.controlsContainer.alpha = 0.0;
                self.controlsContainer.userInteractionEnabled = NO;
                
                self.wasVisualizerOffBeforeRotation = (self.equalizerView.visualType == ISMSBassVisualType_none);
                if (self.wasVisualizerOffBeforeRotation) {
                    [self.equalizerView nextType];
                }
            }
        }
        
//        NSUInteger count = [self.navigationController.viewControllers count];
//        UIViewController *backViewController = [self.navigationController.viewControllers objectAtIndex:count-2];
//        [backViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
//        NSUInteger count = [self.navigationController.viewControllers count];
//        UIViewController *backViewController = [self.navigationController.viewControllers objectAtIndex:count-2];
//        [backViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    }];
        
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void)dealloc {
	[NSNotificationCenter removeObserverOnMainThread:self];
}

#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    
    self.toggleButton.layer.masksToBounds = YES;
    self.toggleButton.layer.cornerRadius = 2.;
    
    self.presetLabel.superview.layer.cornerRadius = 4.;
    self.presetLabel.superview.layer.masksToBounds = YES;
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showPresetPicker:)];
    [self.presetLabel.superview addGestureRecognizer:recognizer];
	
	self.isSavePresetButtonShowing = NO;
	self.savePresetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	CGRect f = self.presetLabel.superview.frame;
	self.savePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 65., f.origin.y, 60., 30.);
	[self.savePresetButton setTitle:@"Save" forState:UIControlStateNormal];
	[self.savePresetButton addTarget:self action:@selector(promptToSaveCustomPreset) forControlEvents:UIControlEventTouchUpInside];
	self.savePresetButton.alpha = 0.;
	self.savePresetButton.enabled = NO;
    self.savePresetButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.controlsContainer addSubview:self.savePresetButton];
	
    self.isDeletePresetButtonShowing = NO;
	self.deletePresetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	self.deletePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 65., f.origin.y, 60., 30.);
	[self.deletePresetButton setTitle:@"Delete" forState:UIControlStateNormal];
	[self.deletePresetButton addTarget:self action:@selector(promptToDeleteCustomPreset) forControlEvents:UIControlEventTouchUpInside];
	self.deletePresetButton.alpha = 0.;
	self.deletePresetButton.enabled = NO;
    self.deletePresetButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.controlsContainer addSubview:self.deletePresetButton];
    
    self.effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];
    if (!BassGaplessPlayer.shared.equalizer.equalizerValues.count) {
        [self.effectDAO selectPresetAtIndex:self.effectDAO.selectedPresetIndex];
    }
    
    [self updatePresetPicker];
    
	[self updateToggleButton];
	
	[self.equalizerView startEqDisplay];
	
	NSArray *detents = @[ @1.0f, @2.0f, @3.0f ];
	self.gainSlider.snapDistance = .13;
	self.gainSlider.detents = detents;
	self.gainSlider.value = settingsS.gainMultiplier;
	self.lastGainValue = self.gainSlider.value;
	self.gainBoostAmountLabel.text = [NSString stringWithFormat:@"%.1fx", self.gainSlider.value];
	
	if (UIDevice.isPad) {
		self.gainSlider.y += 7;
		self.gainBoostLabel.y += 7;
		self.gainBoostAmountLabel.y += 7;
		self.savePresetButton.y -= 10;
		self.deletePresetButton.y -= 10;
	}
    
    [self.controlsContainer bringSubviewToFront:self.savePresetButton];
    [self.controlsContainer bringSubviewToFront:self.deletePresetButton];
    
    self.savePresetButton.x -= 5.;
    self.deletePresetButton.x -= 5.;
	
	if (UIInterfaceOrientationIsLandscape(UIApplication.orientation) && !UIDevice.isPad) {
		self.controlsContainer.alpha = 0.0;
		self.controlsContainer.userInteractionEnabled = NO;
		
		self.wasVisualizerOffBeforeRotation = (self.equalizerView.visualType == ISMSBassVisualType_none);
		if (self.wasVisualizerOffBeforeRotation) {
			[self.equalizerView nextType];
		}
	}
	
	self.overlay = nil;
	
	self.swipeDetectorLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft)];
	self.swipeDetectorLeft.direction = UISwipeGestureRecognizerDirectionLeft;
	[self.equalizerView addGestureRecognizer:self.swipeDetectorLeft];

	self.swipeDetectorRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight)];
	self.swipeDetectorRight.direction = UISwipeGestureRecognizerDirectionRight;
	[self.equalizerView addGestureRecognizer:self.swipeDetectorRight];
    
    if (self.isBeingPresented) {
        self.closeButton = [UIButton buttonWithType:UIButtonTypeClose];
        CGRect closeButtonFrame = self.closeButton.frame;
        closeButtonFrame.origin = CGPointMake(20, 20);
        self.closeButton.frame = closeButtonFrame;
        self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self.closeButton addTarget:self action:@selector(dismiss:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.closeButton];
    }
    
	[Flurry logEvent:@"Equalizer"];
}

- (void)swipeLeft {
    if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
		[self.equalizerView nextType];
    }
}

- (void)swipeRight {
    if (UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
		[self.equalizerView prevType];
    }
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
		
	[self createEqViews];
	
	if (!UIDevice.isPad && UIInterfaceOrientationIsLandscape(UIApplication.orientation)) {
		self.equalizerPath.alpha = 0.0;
		
		for (EqualizerPointView *view in self.equalizerPointViews) {
			view.alpha = 0.0;
		}
	}
    
    self.navigationController.navigationBar.hidden = UIInterfaceOrientationIsLandscape(UIApplication.orientation);
	
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(createEqViews) name:Notifications.bassEffectPresetLoaded object:nil];
	[NSNotificationCenter addObserverOnMainThread:self selector:@selector(dismissPicker) name:@"hidePresetPicker" object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
	if (settingsS.isShouldShowEQViewInstructions) {
        NSString *message = @"Double tap to create a new EQ point and double tap any existing EQ points to remove them.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Instructions" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Don't Show Again" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            settingsS.isShouldShowEQViewInstructions = NO;
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
	}
}

- (void)createAndDrawEqualizerPath {
	// Sort the points
	NSUInteger length = [self.equalizerPointViews count];
	CGPoint *points = malloc(sizeof(CGPoint) * [self.equalizerPointViews count]);
	//for (EqualizerPointView *eqView in equalizerPointViews)
	for (int i = 0; i < length; i++) {
		EqualizerPointView *eqView = [self.equalizerPointViews objectAtIndex:i];
		points[i] = eqView.center;
	}
	//equalizerPath.points = points;
	//equalizerPath.length = length;
	
	[self.equalizerPath setPoints:points length:length];
	
	/*NSMutableArray *points = [NSMutableArray arrayWithCapacity:[equalizerPointViews count]];
	for (EqualizerPointView *eqView in equalizerPointViews)
	{
		[points addObject:[NSValue valueWithCGPoint:eqView.center]];
	}
	equalizerPath.points = points;*/

	// Draw the curve
	//[equalizerPath setNeedsDisplay];
}

- (void)createEqViews {
	[self removeEqViews];
		
	self.equalizerPointViews = [[NSMutableArray alloc] initWithCapacity:BassGaplessPlayer.shared.equalizer.equalizerValues.count];
	for (BassParamEqValue *value in BassGaplessPlayer.shared.equalizer.equalizerValues) {
		//DLog(@"eq handle: %i", value.handle);
		EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithEqValue:value parentSize:self.equalizerView.frame.size];
		[self.equalizerPointViews addObject:eqView];
		
		[self.view insertSubview:eqView aboveSubview:self.equalizerPath];
		//if (overlay)
		//	[self.view insertSubview:eqView belowSubview:overlay];
		//else
		//	[self.view insertSubview:eqView belowSubview:self.controlsContainer];
	}
	//DLog(@"equalizerValues: %@", audioEngineS.equalizerValues);
	//DLog(@"equalizerViews: %@", equalizerPointViews);

	//Draw the path
	[self createAndDrawEqualizerPath];
}

- (void)removeEqViews {
	for (EqualizerPointView *eqView in self.equalizerPointViews) {
		[eqView removeFromSuperview];
	}
    self.equalizerPointViews = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
	[NSNotificationCenter removeObserverOnMainThread:self name:Notifications.bassEffectPresetLoaded object:nil];
	[NSNotificationCenter removeObserverOnMainThread:self name:@"hidePresetPicker" object:nil];
	[self removeEqViews];
	[self.equalizerView stopEqDisplay];
	[self.equalizerView removeFromSuperview];
	self.equalizerView = nil;
    BassGaplessPlayer.shared.visualizer.type = BassVisualizerTypeNone;
	self.navigationController.navigationBar.hidden = NO;
}

- (void)hideSavePresetButton:(BOOL)animated {
	self.isSavePresetButtonShowing = NO;
    if (animated) {
        [UIView animateWithDuration:0.5 animations:^{
            self.presetLabel.superview.width = 300.;
            self.savePresetButton.alpha = 0.;
        }];
    } else {
        self.presetLabel.superview.width = 300.;
        self.savePresetButton.alpha = 0.;
    }
	self.savePresetButton.enabled = NO;
}

- (void)showSavePresetButton:(BOOL)animated {
    [self hideDeletePresetButton:NO];
	self.isSavePresetButtonShowing = YES;
	self.savePresetButton.enabled = YES;
    
    if (animated) {
        [UIView animateWithDuration:0.5 animations:^{
            self.presetLabel.superview.width = 300. - 70.;
            self.savePresetButton.alpha = 1.;
        }];
    } else {
        self.presetLabel.superview.width = 300. - 70.;
        self.savePresetButton.alpha = 1.;
    }
}

- (void)hideDeletePresetButton:(BOOL)animated {
	self.isDeletePresetButtonShowing = NO;
    if (animated) {
        [UIView animateWithDuration:0.5 animations:^{
            self.presetLabel.superview.width = 300.;
            self.deletePresetButton.alpha = 0.;
        }];
    } else {
        self.presetLabel.superview.width = 300.;
        self.deletePresetButton.alpha = 0.;
    }
	self.deletePresetButton.enabled = NO;
}

- (void)showDeletePresetButton:(BOOL)animated {
    [self hideSavePresetButton:NO];
	self.isDeletePresetButtonShowing = YES;
	self.deletePresetButton.enabled = YES;
    if (animated) {
        [UIView animateWithDuration:0.5 animations:^{
            self.presetLabel.superview.width = 300. - 70.;
            self.deletePresetButton.alpha = 1.;
        }];
    } else {
        self.presetLabel.superview.width = 300. - 70.;
        self.deletePresetButton.alpha = 1.;
    }
}

- (NSArray *)serializedEqPoints {
	NSMutableArray *points = [NSMutableArray arrayWithCapacity:0];
	for (EqualizerPointView *pointView in self.equalizerPointViews) {
		[points addObject:NSStringFromCGPoint(pointView.position)];
	}
	return [NSArray arrayWithArray:points];
}

- (void)saveTempCustomPreset {
	[self.effectDAO saveTempCustomPreset:[self serializedEqPoints]];
	[self updatePresetPicker];
}

- (void)promptToDeleteCustomPreset {
    NSString *title = [NSString stringWithFormat:@"\"%@\"", [self.effectDAO.selectedPreset objectForKey:@"name"]];
    NSString *message = @"Are you sure you want to delete this preset?";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.effectDAO deleteCustomPresetForId:self.effectDAO.selectedPresetId];
        [self updatePresetPicker];
        [self.presetPicker selectRow:0 inComponent:0 animated:NO];
        [self pickerView:self.presetPicker didSelectRow:0 inComponent:0];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptToSaveCustomPreset {
	NSUInteger count = [self.effectDAO.userPresets count];
    if ([self.effectDAO.userPresets objectForKey:[@(BassEffectTempCustomPresetId) stringValue]]) {
		count--;
    }
	
	if (count > 0) {
		self.saveDialog = [[DDSocialDialog alloc] initWithFrame:CGRectMake(0., 0., 300., 300.) theme:DDSocialDialogThemeISub];
		self.saveDialog.dialogDelegate = self;
		self.saveDialog.titleLabel.text = @"Choose Preset To Save";
		UITableView *saveTable = [[UITableView alloc] initWithFrame:self.saveDialog.contentView.frame style:UITableViewStylePlain];
		saveTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		saveTable.dataSource = self;
		saveTable.delegate = self;
		[self.saveDialog.contentView addSubview:saveTable];
		[self.saveDialog show];
	} else {
		[self promptForSavePresetName];
	}
}

- (void)promptForSavePresetName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Create Preset" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Preset name";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *name = [alert.textFields.firstObject text];
        [self.effectDAO saveCustomPreset:self.serializedEqPoints name:name];
        [self.effectDAO deleteTempCustomPreset];
        [self updatePresetPicker];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)movedGainSlider:(id)sender {
	CGFloat gainValue = self.gainSlider.value;
	CGFloat minValue = self.gainSlider.minimumValue;
	CGFloat maxValue = self.gainSlider.maximumValue;
	
	settingsS.gainMultiplier = gainValue;
    BassGaplessPlayer.shared.equalizer.gain = gainValue;
	
	CGFloat difference = fabs(gainValue - self.lastGainValue);
	if (difference >= .1 || gainValue == minValue || gainValue == maxValue) {
		self.gainBoostAmountLabel.text = [NSString stringWithFormat:@"%.1fx", gainValue];
		self.lastGainValue = gainValue;
	}
}

#pragma mark Touch gestures interception

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	//DLog(@"touch began");
	
	//DLog(@"tap count: %i", [touch tapCount]);
	
	UIView *touchedView = [self.view hitTest:[touch locationInView:self.view] withEvent:nil];
	if ([touchedView isKindOfClass:[EqualizerPointView class]]) {
		self.selectedView = (EqualizerPointView *)touchedView;
		
		if ([touch tapCount] == 2) {
			// remove the point
			//DLog(@"double tap, remove point");
			
			[BassGaplessPlayer.shared.equalizer removeEqualizerValue:self.selectedView.eqValue];
			[self.equalizerPointViews removeObject:self.selectedView];
			[self.selectedView removeFromSuperview];
			self.selectedView = nil;
			
			[self createAndDrawEqualizerPath];
		}
	}
	/*else if (touchedView == self.landscapeButtonsHolder)
	{
		[self hideLandscapeVisualizerButtons];
	}*/
	else if ([touchedView isKindOfClass:[EqualizerView class]]) {
		/*if ([touch tapCount] == 1)
		{
			if (!UIDevice.isPad && UIInterfaceOrientationIsLandscape(UIApplication.orientation))
			{
				[self showLandscapeVisualizerButtons];
			}
			
			// Only change visualizers in lanscape mode, when visualier is full screen
			//if (UIInterfaceOrientationIsLandscape(UIApplication.orientation))
			//	[self performSelector:@selector(type:) withObject:nil afterDelay:0.25];
		}*/
		if ([touch tapCount] == 2) {
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(type:) object:nil];
			
			// Only create EQ points in portrait mode when EQ is visible
			if (UIDevice.isPad || UIInterfaceOrientationIsPortrait(UIApplication.orientation)) {
				// add a point
				//DLog(@"double tap, adding point");
				
				// Find the tap point
				CGPoint point = [touch locationInView:self.equalizerView];
				
				// Create the eq view
				EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithCGPoint:point parentSize:self.equalizerView.bounds.size];
				BassParamEqValue *value = [BassGaplessPlayer.shared.equalizer addEqualizerValue:eqView.eqValue.parameters];
				eqView.eqValue = value;
				
				// Add the view
				[self.equalizerPointViews addObject:eqView];
				[self.view addSubview:eqView];
                
                [self createAndDrawEqualizerPath];
				
				[self saveTempCustomPreset];
			}
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (self.selectedView != nil) {
		UITouch *touch = [touches anyObject];
		CGPoint location = [touch locationInView:self.equalizerView];
		if (CGRectContainsPoint(self.equalizerView.frame, location)) {
			self.selectedView.center = [touch locationInView:self.view];
			[BassGaplessPlayer.shared.equalizer updateEqParameter:self.selectedView.eqValue];
			[self createAndDrawEqualizerPath];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	// Apply the EQ
	if (self.selectedView != nil) {
		[BassGaplessPlayer.shared.equalizer updateEqParameter:self.selectedView.eqValue];
		self.selectedView = nil;
		[self saveTempCustomPreset];
	}
}

- (void)dismiss:(id)sender {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)toggle:(id)sender {

	if ([BassGaplessPlayer.shared.equalizer toggleEqualizer]) {
		[self removeEqViews];
		[self createEqViews];
	}
	[self updateToggleButton];
	[self.equalizerPath setNeedsDisplay];
}

- (void)updateToggleButton {
	if (settingsS.isEqualizerOn) {
		[self.toggleButton setTitle:@"EQ is ON" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [UIColor colorWithWhite:1. alpha:.25];
	} else {
		[self.toggleButton setTitle:@"EQ is OFF" forState:UIControlStateNormal];
		self.toggleButton.backgroundColor = [UIColor clearColor];
	}
}

- (IBAction)type:(id)sender {
	[self.equalizerView nextType];
}

#pragma mark Preset Picker

- (void)updatePresetPicker {
    [self.presetPicker reloadAllComponents];
    [self.presetPicker selectRow:self.effectDAO.selectedPresetIndex inComponent:0 animated:YES];
    self.presetLabel.text = self.effectDAO.selectedPreset[@"name"];
    
    if (self.effectDAO.selectedPresetId == BassEffectTempCustomPresetId) {
		[self showSavePresetButton:NO];
	} else if (![[self.effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue]) {
		[self showDeletePresetButton:NO];
	}
}

- (void)showPresetPicker:(id)sender {
    if (!self.isPresetPickerShowing) {
        self.isPresetPickerShowing = YES;
        
        self.overlay = [[UIView alloc] init];
        self.overlay.translatesAutoresizingMaskIntoConstraints = NO;
        self.overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
        self.overlay.alpha = 0.0;
        [self.view insertSubview:self.overlay belowSubview:self.controlsContainer];
        [NSLayoutConstraint activateConstraints:@[
            [self.overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [self.overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        ]];
        
        self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.dismissButton addTarget:self action:@selector(dismissPicker) forControlEvents:UIControlEventTouchUpInside];
        self.dismissButton.frame = self.equalizerView.frame;
        self.dismissButton.enabled = NO;
        [self.overlay addSubview:self.dismissButton];
        
        self.presetPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, self.view.height - self.equalizerView.height)];
        self.presetPicker.dataSource = self;
        self.presetPicker.delegate = self;
        
        self.presetPickerBlurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        self.presetPickerBlurView.frame = CGRectMake(0, self.view.height, self.view.width, self.view.height - self.equalizerView.height);
        [self.presetPickerBlurView.contentView addSubview:self.presetPicker];
        [self.view addSubview:self.presetPickerBlurView];
        [self.view bringSubviewToFront:self.overlay];
        [self.view bringSubviewToFront:self.presetPickerBlurView];
        [self updatePresetPicker];
        
        [UIView animateWithDuration:.3 delay:0. options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.overlay.alpha = 1;
            self.dismissButton.enabled = YES;
            self.presetPickerBlurView.y = self.equalizerView.height;
        } completion:nil];
    }
}

- (void)dismissPicker {
    if (self.isPresetPickerShowing) {
        [self.presetPicker resignFirstResponder];
		[UIView animateWithDuration:.3 delay:0. options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.overlay.alpha = 0;
            self.dismissButton.enabled = NO;
            self.presetPickerBlurView.y = self.view.height;
//            self.presetPicker.y = self.view.height;
        } completion:^(BOOL finished) {
            [self.presetPicker removeFromSuperview];
            self.presetPicker = nil;
            [self.presetPickerBlurView removeFromSuperview];
            self.presetPickerBlurView = nil;
            [self.dismissButton removeFromSuperview];
            self.dismissButton = nil;
            [self.overlay removeFromSuperview];
            self.overlay = nil;
            self.isPresetPickerShowing = NO;
        }];
	}
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    [self.effectDAO selectPresetAtIndex:row];
    
	BOOL isDefault = [[self.effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue];
	if (self.effectDAO.selectedPresetId == BassEffectTempCustomPresetId && !self.isSavePresetButtonShowing) {
		[self showSavePresetButton:YES];
	} else if (self.effectDAO.selectedPresetId != BassEffectTempCustomPresetId && self.isSavePresetButtonShowing) {
		[self hideSavePresetButton:YES];
	}
	
	if (self.effectDAO.selectedPresetId != BassEffectTempCustomPresetId && !self.isDeletePresetButtonShowing && !isDefault) {
		[self showDeletePresetButton:YES];
	} else if ((self.effectDAO.selectedPresetId == BassEffectTempCustomPresetId || isDefault) && self.isDeletePresetButtonShowing) {
		[self hideDeletePresetButton:YES];
	}
    
    [self updatePresetPicker];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [self.effectDAO.presetsArray[row] objectForKey:@"name"];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.effectDAO.presets.count;
}

#pragma mark TableView delegate for save dialog

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0: return 1;
		case 1: return self.effectDAO.userPresetsArrayMinusCustom.count;
		default: return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"NoResuse";
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	NSDictionary *preset = nil;
	switch (indexPath.section) {
		case 0:
			cell.textLabel.text = @"New Preset";
			break;
		case 1:
			preset = self.effectDAO.userPresetsArrayMinusCustom[indexPath.row];
			cell.tag = [[preset objectForKey:@"presetId"] intValue];
			cell.textLabel.text = [preset objectForKey:@"name"];
			break;
		default:
			break;
	}
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0: return @"";
		case 1: return @"Saved Presets";
		default: return @"";
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (indexPath.section == 0) {
		// Save a new preset
		[self promptForSavePresetName];
	} else {
		// Save over an existing preset
		UITableViewCell *currentTableCell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
		[self.effectDAO saveCustomPreset:[self serializedEqPoints] name:currentTableCell.textLabel.text presetId:currentTableCell.tag];
		[self.effectDAO deleteTempCustomPreset];
		[self updatePresetPicker];
	}
	[self.saveDialog dismiss:YES];
}

@end
