//
//  ModalAlbumArtViewController.m
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ModalAlbumArtViewController.h"
#import "SavedSettings.h"
#import "EX2Kit.h"
 
@implementation ModalAlbumArtViewController

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	if (!IS_IPAD()) {
		[UIView beginAnimations:@"rotate" context:nil];
		//[UIView setAnimationDelegate:self];
		//[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:duration];
		
		if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            self.albumArt.width = 480;
            self.albumArt.height = 320;
            self.labelHolderView.alpha = 0.0;
		} else {
            self.albumArt.width = 320;
            self.albumArt.height = 320;
            self.labelHolderView.alpha = 1.0;
		}
		
		[UIView commitAnimations];
		
		[[UIApplication sharedApplication] setStatusBarHidden:UIInterfaceOrientationIsLandscape(toInterfaceOrientation) 
												withAnimation:UIStatusBarAnimationSlide];
	}
}

- (instancetype)initWithAlbum:(ISMSAlbum *)theAlbum numberOfTracks:(NSUInteger)tracks albumLength:(NSUInteger)length {
	if ((self = [super initWithNibName:@"ModalAlbumArtViewController" bundle:nil])) {
        if ([self respondsToSelector:@selector(setModalPresentationStyle:)]) {
			self.modalPresentationStyle = UIModalPresentationFormSheet;
        }
		
        self.myAlbum = [theAlbum copy];
        self.numberOfTracks = tracks;
        self.albumLength = length;
	}
	
	return self;
}

- (void)viewDidLoad {
	if (IS_IPAD()) {
		// Fix album art size for iPad
        self.albumArt.width = 540;
        self.albumArt.height = 540;
        self.albumArtReflection.y = 540;
        self.albumArtReflection.width = 540;
        self.labelHolderView.height = 125;
        self.labelHolderView.y = 500;
	}
	
    self.albumArt.isLarge = YES;
    self.albumArt.delegate = self;
	
	//[UIApplication setStatusBarHidden:YES withAnimation:YES];
	
    self.artistLabel.text = self.myAlbum.artistName;
    self.albumLabel.text = self.myAlbum.title;
    self.durationLabel.text = [NSString formatTime:self.albumLength];
    self.trackCountLabel.text = [NSString stringWithFormat:@"%lu Tracks", (unsigned long)self.numberOfTracks];
    if (self.numberOfTracks == 1) {
        self.trackCountLabel.text = [NSString stringWithFormat:@"%lu Track", (unsigned long)self.numberOfTracks];
    }
    
    self.albumArt.coverArtId = self.myAlbum.coverArtId;
	
    self.albumArtReflection.image = [self.albumArt reflectedImageWithHeight:self.albumArtReflection.height];
	
	if (!IS_IPAD()) {
		if (UIInterfaceOrientationIsLandscape([UIApplication orientation])) {
			[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
            self.albumArt.width = 480;
        } else {
			[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
		}
	}
}

- (BOOL)shouldAutorotate {
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait) {
        return NO;
    }
    
    return YES;
}

- (IBAction)dismiss:(id)sender {
    if (!IS_IPAD()) {
		[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    }
    
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView {
    self.albumArtReflection.image = [self.albumArt reflectedImageWithHeight:self.albumArtReflection.height];
}

@end
