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

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (UIDevice.isIPad) return;
        
        if (UIInterfaceOrientationIsPortrait(UIApplication.orientation)) {
            self.albumArt.width = 320;
            self.albumArt.height = 320;
            self.labelHolderView.alpha = 1.0;
        } else {
            self.albumArt.width = 480;
            self.albumArt.height = 320;
            self.labelHolderView.alpha = 0.0;
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
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
	if (UIDevice.isIPad) {
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
}

- (IBAction)dismiss:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView {
    self.albumArtReflection.image = [self.albumArt reflectedImageWithHeight:self.albumArtReflection.height];
}

@end
