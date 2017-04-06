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
#import "FXBlurView.h"

@implementation EqualizerViewController

#define hidePickerTimer @"EqualizerViewController hide picker timer"
#define hidePickerTimerDelay 5.

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return !self.isPresetPickerShowing;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	[UIView beginAnimations:@"rotate" context:nil];
	[UIView setAnimationDuration:duration];
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		self.equalizerPath.alpha = 1.0;
		for (EqualizerPointView *view in self.equalizerPointViews)
		{
			view.alpha = 1.0;
		}
		
		UIDevice *device = [UIDevice currentDevice];
		if (device.batteryState != UIDeviceBatteryStateCharging && device.batteryState != UIDeviceBatteryStateFull) 
		{
			if (settingsS.isScreenSleepEnabled)
				[UIApplication sharedApplication].idleTimerDisabled = NO;
		}
		
		if (!IS_IPAD())
		{
            [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];

			self.controlsContainer.alpha = 1.0;
			self.controlsContainer.userInteractionEnabled = YES;
			
			if (self.wasVisualizerOffBeforeRotation)
			{
				[self.equalizerView changeType:ISMSBassVisualType_none];
			}
			
			/*if (self.landscapeButtonsHolder.superview)
				[self hideLandscapeVisualizerButtons];*/
		}
	}
	else
	{
		self.equalizerPath.alpha = 0.0;
		for (EqualizerPointView *view in self.equalizerPointViews)
		{
			view.alpha = 0.0;
		}
		
		[UIApplication sharedApplication].idleTimerDisabled = YES;
		
		if (!IS_IPAD())
		{
            [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];

			self.controlsContainer.alpha = 0.0;
			self.controlsContainer.userInteractionEnabled = NO;
			
			self.wasVisualizerOffBeforeRotation = (self.equalizerView.visualType == ISMSBassVisualType_none);
			if (self.wasVisualizerOffBeforeRotation)
			{
				[self.equalizerView nextType];
			}
		}
	}
	[UIView commitAnimations];
	
	NSUInteger count = [self.navigationController.viewControllers count];
	UIViewController *backViewController = [self.navigationController.viewControllers objectAtIndex:count-2];
	[backViewController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	/*if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation))
	{
		[self removeEqViews];
	}
	else
	{
		[self createEqViews];
	}*/
	
	NSUInteger count = [self.navigationController.viewControllers count];
	UIViewController *backViewController = [self.navigationController.viewControllers objectAtIndex:count-2];
	[backViewController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[EX2Dispatch cancelTimerBlockWithName:hidePickerTimer];
	//[hidePickerTimer release]; hidePickerTimer = nil;
	
	
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.toggleButton.layer.masksToBounds = YES;
    self.toggleButton.layer.cornerRadius = 2.;
    
    self.presetLabel.superview.layer.cornerRadius = 4.;
    self.presetLabel.superview.layer.masksToBounds = YES;
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showPresetPicker:)];
    [self.presetLabel.superview addGestureRecognizer:recognizer];
	
    if (!audioEngineS.player)
    {
        [audioEngineS startEmptyPlayer];
    }
	
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
    if (!audioEngineS.player.equalizer.equalizerValues.count)
        [self.effectDAO selectPresetAtIndex:self.effectDAO.selectedPresetIndex];
    
    [self updatePresetPicker];
    
	[self updateToggleButton];
	
	[self.equalizerView startEqDisplay];
	
	NSArray *detents = @[ @1.0f, @2.0f, @3.0f ];
	self.gainSlider.snapDistance = .13;
	self.gainSlider.detents = detents;
	self.gainSlider.value = settingsS.gainMultiplier;
	self.lastGainValue = self.gainSlider.value;
	self.gainBoostAmountLabel.text = [NSString stringWithFormat:@"%.1fx", self.gainSlider.value];
	
	if (IS_IPAD())
	{
		self.gainSlider.y += 7;
		self.gainBoostLabel.y += 7;
		self.gainBoostAmountLabel.y += 7;
		self.savePresetButton.y -= 10;
		self.deletePresetButton.y -= 10;
	}
    
    if (IS_TALL_SCREEN())
    {
        [self.controlsContainer bringSubviewToFront:self.savePresetButton];
        [self.controlsContainer bringSubviewToFront:self.deletePresetButton];
        
        self.savePresetButton.x -= 5.;
        self.deletePresetButton.x -= 5.;
    }
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && !IS_IPAD())
	{
		self.controlsContainer.alpha = 0.0;
		self.controlsContainer.userInteractionEnabled = NO;
		
		self.wasVisualizerOffBeforeRotation = (self.equalizerView.visualType == ISMSBassVisualType_none);
		if (self.wasVisualizerOffBeforeRotation)
		{
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
	
    if (!IS_IOS7())
    {
        self.gainSlider.y += 4.;
        self.presetLabel.superview.y -= 10.;
    }
    
	[Flurry logEvent:@"Equalizer"];
}

- (void)swipeLeft
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		[self.equalizerView nextType];
}

- (void)swipeRight
{
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		[self.equalizerView prevType];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
		
	[self createEqViews];
	
	if (!IS_IPAD() && UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
		self.equalizerPath.alpha = 0.0;
		
		for (EqualizerPointView *view in self.equalizerPointViews)
		{
			view.alpha = 0.0;
		}
	}

	self.navigationController.navigationBar.hidden = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createEqViews) name:ISMSNotification_BassEffectPresetLoaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissPicker) name:@"hidePresetPicker" object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
	if (settingsS.isShouldShowEQViewInstructions)
	{
		NSString *title = [NSString stringWithFormat:@"Instructions"];
		UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:title message:@"Double tap to create a new EQ point and double tap any existing EQ points to remove them." delegate:self cancelButtonTitle:@"Don't Show Again" otherButtonTitles:@"OK", nil];
		myAlertView.tag = 3;
		[myAlertView show];
	}
}

- (void)createAndDrawEqualizerPath
{	
	// Sort the points
	NSUInteger length = [self.equalizerPointViews count];
	CGPoint *points = malloc(sizeof(CGPoint) * [self.equalizerPointViews count]);
	//for (EqualizerPointView *eqView in equalizerPointViews)
	for (int i = 0; i < length; i++)
	{
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

- (void)createEqViews
{
	[self removeEqViews];
		
	self.equalizerPointViews = [[NSMutableArray alloc] initWithCapacity:audioEngineS.equalizer.equalizerValues.count];
	for (BassParamEqValue *value in audioEngineS.equalizer.equalizerValues)
	{
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

- (void)removeEqViews
{
    NSLog(@"removeEqViews");
	for (EqualizerPointView *eqView in self.equalizerPointViews)
	{
		[eqView removeFromSuperview];
	}
    self.equalizerPointViews = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[EX2Dispatch cancelTimerBlockWithName:hidePickerTimer];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassEffectPresetLoaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hidePresetPicker" object:nil];
	
	[self removeEqViews];
	
	[self.equalizerView stopEqDisplay];
	
	[self.equalizerView removeFromSuperview];
	self.equalizerView = nil;
	
	audioEngineS.visualizer.type = BassVisualizerTypeNone;
	
	self.navigationController.navigationBar.hidden = NO;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)hideSavePresetButton:(BOOL)animated
{	
	self.isSavePresetButtonShowing = NO;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	self.presetLabel.superview.width = 300.;
	self.savePresetButton.alpha = 0.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
	
	self.savePresetButton.enabled = NO;
}

- (void)showSavePresetButton:(BOOL)animated
{
    [self hideDeletePresetButton:NO];
    
	self.isSavePresetButtonShowing = YES;
	
	self.savePresetButton.enabled = YES;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	self.presetLabel.superview.width = 300. - 70.;
	self.savePresetButton.alpha = 1.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
}

- (void)hideDeletePresetButton:(BOOL)animated
{	
	self.isDeletePresetButtonShowing = NO;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	self.presetLabel.superview.width = 300.;
	self.deletePresetButton.alpha = 0.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
	
	self.deletePresetButton.enabled = NO;
}

- (void)showDeletePresetButton:(BOOL)animated
{
    [self hideSavePresetButton:NO];
    
	self.isDeletePresetButtonShowing = YES;
	
	self.deletePresetButton.enabled = YES;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	self.presetLabel.superview.width = 300. - 70.;
	self.deletePresetButton.alpha = 1.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
}

- (NSArray *)serializedEqPoints
{
	NSMutableArray *points = [NSMutableArray arrayWithCapacity:0];
	for (EqualizerPointView *pointView in self.equalizerPointViews)
	{
		[points addObject:NSStringFromCGPoint(pointView.position)];
	}
	return [NSArray arrayWithArray:points];
}

- (void)saveTempCustomPreset
{
	[self.effectDAO saveTempCustomPreset:[self serializedEqPoints]];
	
	[self updatePresetPicker];
}

- (void)promptToDeleteCustomPreset
{
	NSString *title = [NSString stringWithFormat:@"\"%@\"", [self.effectDAO.selectedPreset objectForKey:@"name"]];
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:title message:@"Are you sure you want to delete this preset?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
	myAlertView.tag = 1;
	[myAlertView show];
}

- (void)promptToSaveCustomPreset
{
	NSUInteger count = [self.effectDAO.userPresets count];
	if ([self.effectDAO.userPresets objectForKey:[@(BassEffectTempCustomPresetId) stringValue]])
		count--;
	
	if (count > 0)
	{
		self.saveDialog = [[DDSocialDialog alloc] initWithFrame:CGRectMake(0., 0., 300., 300.) theme:DDSocialDialogThemeISub];
		self.saveDialog.dialogDelegate = self;
		self.saveDialog.titleLabel.text = @"Choose Preset To Save";
		UITableView *saveTable = [[UITableView alloc] initWithFrame:self.saveDialog.contentView.frame style:UITableViewStylePlain];
		saveTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		saveTable.dataSource = self;
		saveTable.delegate = self;
		[self.saveDialog.contentView addSubview:saveTable];
		[self.saveDialog show];
	}
	else
	{
		[self promptForSavePresetName];
	}
}

- (void)promptForSavePresetName
{
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"New Preset Name:" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	myAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	myAlertView.tag = 2;
	[myAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		// Delete the preset
		if (buttonIndex)
		{
			[self.effectDAO deleteCustomPresetForId:self.effectDAO.selectedPresetId];
			[self updatePresetPicker];
            [self.presetPicker selectRow:0 inComponent:0 animated:NO];
            [self pickerView:self.presetPicker didSelectRow:0 inComponent:0];
		}
	}
	else if (alertView.tag == 2)
	{
		// Save the preset
		if (buttonIndex)
		{
			//DLog(@"Preset name: %@", presetNameTextField.text);
            NSString *text = [alertView textFieldAtIndex:0].text;
			[self.effectDAO saveCustomPreset:[self serializedEqPoints] name:text];
			[self.effectDAO deleteTempCustomPreset];
			[self updatePresetPicker];
		}
	}
	else if (alertView.tag == 3)
	{
		if (buttonIndex == 0)
		{
			settingsS.isShouldShowEQViewInstructions = NO;
		}
	}
}

- (IBAction)movedGainSlider:(id)sender
{
	CGFloat gainValue = self.gainSlider.value;
	CGFloat minValue = self.gainSlider.minimumValue;
	CGFloat maxValue = self.gainSlider.maximumValue;
	
	settingsS.gainMultiplier = gainValue;
	audioEngineS.equalizer.gain = gainValue;
	
	CGFloat difference = fabs(gainValue - self.lastGainValue);
	if (difference >= .1 || gainValue == minValue || gainValue == maxValue)
	{
		self.gainBoostAmountLabel.text = [NSString stringWithFormat:@"%.1fx", gainValue];
		self.lastGainValue = gainValue;
	}
}

#pragma mark Touch gestures interception

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	//DLog(@"touch began");
	
	//DLog(@"tap count: %i", [touch tapCount]);
	
	UIView *touchedView = [self.view hitTest:[touch locationInView:self.view] withEvent:nil];
	if ([touchedView isKindOfClass:[EqualizerPointView class]])
	{
		self.selectedView = (EqualizerPointView *)touchedView;
		
		if ([touch tapCount] == 2)
		{
			// remove the point
			//DLog(@"double tap, remove point");
			
			[audioEngineS.equalizer removeEqualizerValue:self.selectedView.eqValue];
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
	else if ([touchedView isKindOfClass:[EqualizerView class]])
	{
		/*if ([touch tapCount] == 1)
		{
			if (!IS_IPAD() && UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				[self showLandscapeVisualizerButtons];
			}
			
			// Only change visualizers in lanscape mode, when visualier is full screen
			//if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			//	[self performSelector:@selector(type:) withObject:nil afterDelay:0.25];
		}*/
		if ([touch tapCount] == 2)
		{
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(type:) object:nil];
			
			// Only create EQ points in portrait mode when EQ is visible
			if (IS_IPAD() || UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
			{
				// add a point
				//DLog(@"double tap, adding point");
				
				// Find the tap point
				CGPoint point = [touch locationInView:self.equalizerView];
				
				// Create the eq view
				EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithCGPoint:point parentSize:self.equalizerView.bounds.size];
				BassParamEqValue *value = [audioEngineS.equalizer addEqualizerValue:eqView.eqValue.parameters];
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

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.selectedView != nil)
	{
		UITouch *touch = [touches anyObject];
		
		CGPoint location = [touch locationInView:self.equalizerView];
		if (CGRectContainsPoint(self.equalizerView.frame, location))
		{
			self.selectedView.center = [touch locationInView:self.view];
			[audioEngineS.equalizer updateEqParameter:self.selectedView.eqValue];
			
			[self createAndDrawEqualizerPath];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Apply the EQ
	if (self.selectedView != nil)
	{
		[audioEngineS.equalizer updateEqParameter:self.selectedView.eqValue];
		self.selectedView = nil;
		
		[self saveTempCustomPreset];
	}
}

- (IBAction)dismiss:(id)sender
{
	//[UIApplication setStatusBarHidden:NO withAnimation:NO];
	[self.navigationController popViewControllerAnimated:YES];
	//[self dismissModalViewControllerAnimated:YES];
}

- (IBAction)toggle:(id)sender
{
	if ([audioEngineS.equalizer toggleEqualizer])
	{
		[self removeEqViews];
		[self createEqViews];
	}
	[self updateToggleButton];
	
	[self.equalizerPath setNeedsDisplay];
}

- (void)updateToggleButton
{
    NSLog(@"Update Toggle Button  %d",settingsS.isEqualizerOn);
	if(settingsS.isEqualizerOn)
	{
		[self.toggleButton setTitle:@"EQ is ON" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [UIColor colorWithWhite:1. alpha:.25];
	}
	else
	{
		[self.toggleButton setTitle:@"EQ is OFF" forState:UIControlStateNormal];
		self.toggleButton.backgroundColor = [UIColor clearColor];
	}
}

- (IBAction)type:(id)sender
{
	[self.equalizerView nextType];
}

#pragma mark -
#pragma mark Preset Picker
#pragma mark -

- (void)updatePresetPicker
{
    [self.presetPicker reloadAllComponents];
    [self.presetPicker selectRow:self.effectDAO.selectedPresetIndex inComponent:0 animated:YES];
    self.presetLabel.text = self.effectDAO.selectedPreset[@"name"];
    
    if (self.effectDAO.selectedPresetId == BassEffectTempCustomPresetId)
	{
		[self showSavePresetButton:NO];
	}
	else if (![[self.effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue])
	{
		[self showDeletePresetButton:NO];
	}
}

- (void)showPresetPicker:(id)sender
{
    self.overlay = [[UIView alloc] init];
	self.overlay.frame = self.view.frame;
	self.overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	self.overlay.alpha = 0.0;
	[self.view insertSubview:self.overlay belowSubview:self.controlsContainer];
	
	self.dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.dismissButton addTarget:self action:@selector(dismissPicker) forControlEvents:UIControlEventTouchUpInside];
	self.dismissButton.frame = self.view.bounds;
	self.dismissButton.enabled = NO;
	[self.overlay addSubview:self.dismissButton];
    
    if (!self.presetPicker)
    {
        self.presetPicker = [[UIPickerView alloc] init];
        self.presetPicker.dataSource = self;
        self.presetPicker.delegate = self;
        
        FXBlurView *blurView = [[FXBlurView alloc] initWithFrame:self.presetPicker.bounds];
        blurView.tintColor = [UIColor whiteColor];
        [blurView addSubview:self.presetPicker];
        blurView.height += IS_IOS7() ? 32. : 0.;
        blurView.y = self.view.height;
        
        [self.view addSubview:blurView];
        
        [self updatePresetPicker];
    }
    
    [UIView animateWithDuration:.3 delay:0. options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.overlay.alpha = 1;
        self.dismissButton.enabled = YES;
        self.presetPicker.superview.bottom = self.view.height;
    } completion:nil];
    
	self.isPresetPickerShowing = YES;
    
    /*[EX2Dispatch timerInMainQueueAfterDelay:hidePickerTimerDelay withName:hidePickerTimer repeats:NO performBlock:^{
        [self dismissPicker];
    }];*/
}

- (void)dismissPicker
{
	[self.presetPicker resignFirstResponder];
	
	[EX2Dispatch cancelTimerBlockWithName:hidePickerTimer];
    
    if (self.overlay)
	{
		[UIView animateWithDuration:.3 delay:0. options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.overlay.alpha = 0;
            self.dismissButton.enabled = NO;
            self.presetPicker.superview.y = self.view.height;
        } completion:^(BOOL finished) {
            [self.overlay removeFromSuperview];
            self.overlay = nil;
        }];
	}
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    [self.effectDAO selectPresetAtIndex:row];
	
	BOOL isDefault = [[self.effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue];
	
	if (self.effectDAO.selectedPresetId == BassEffectTempCustomPresetId && !self.isSavePresetButtonShowing)
	{
		[self showSavePresetButton:YES];
	}
	else if (self.effectDAO.selectedPresetId != BassEffectTempCustomPresetId && self.isSavePresetButtonShowing)
	{
		[self hideSavePresetButton:YES];
	}
	
	if (self.effectDAO.selectedPresetId != BassEffectTempCustomPresetId && !self.isDeletePresetButtonShowing && !isDefault)
	{
		[self showDeletePresetButton:YES];
	}
	else if ((self.effectDAO.selectedPresetId == BassEffectTempCustomPresetId || isDefault) && self.isDeletePresetButtonShowing)
	{
		[self hideDeletePresetButton:YES];
	}
    
    [EX2Dispatch cancelTimerBlockWithName:hidePickerTimer];
    /*[EX2Dispatch timerInMainQueueAfterDelay:hidePickerTimerDelay withName:hidePickerTimer repeats:NO performBlock:^{
        [self dismissPicker];
    }];*/
    
    [self updatePresetPicker];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [[self.effectDAO.presetsArray objectAtIndexSafe:row] objectForKey:@"name"];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.effectDAO.presets.count;
}

#pragma mark - TableView delegate for save dialog -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{	
	return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) 
	{
		case 0:
			return 1;
		case 1:
			return [self.effectDAO.userPresetsArrayMinusCustom count];
		default:
			return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"NoResuse";
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	
	NSDictionary *preset = nil;
	switch (indexPath.section) 
	{
		case 0:
			cell.textLabel.text = @"New Preset";
			break;
		case 1:
			preset = [self.effectDAO.userPresetsArrayMinusCustom objectAtIndexSafe:indexPath.row];
			cell.tag = [[preset objectForKey:@"presetId"] intValue];
			cell.textLabel.text = [preset objectForKey:@"name"];
			break;
		default:
			break;
	}
		
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) 
	{
		case 0:
			return @"";
		case 1:
			return @"Saved Presets";
		default:
			return @"";
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.section == 0)
	{
		// Save a new preset
		[self promptForSavePresetName];
	}
	else
	{
		// Save over an existing preset
		UITableViewCell *currentTableCell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
		[self.effectDAO saveCustomPreset:[self serializedEqPoints] name:currentTableCell.textLabel.text presetId:currentTableCell.tag];
		[self.effectDAO deleteTempCustomPreset];
		[self updatePresetPicker];
	}
	[self.saveDialog dismiss:YES];
}


@end
