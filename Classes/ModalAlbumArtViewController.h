//
//  ModalAlbumArtViewController.h
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface ModalAlbumArtViewController : UIViewController <AsynchronousImageViewDelegate>

@property (nonatomic, strong) IBOutlet AsynchronousImageView *albumArt;
@property (nonatomic, strong) IBOutlet UIImageView *albumArtReflection;
@property (nonatomic, strong) IBOutlet UIView *labelHolderView;
@property (nonatomic, strong) IBOutlet UILabel *artistLabel; 
@property (nonatomic, strong) IBOutlet UILabel *albumLabel;
@property (nonatomic, strong) IBOutlet UILabel *durationLabel;
@property (nonatomic, strong) IBOutlet UILabel *trackCountLabel;
@property (nonatomic, copy) ISMSAlbum *myAlbum;
@property (nonatomic) NSUInteger numberOfTracks;
@property (nonatomic) NSUInteger albumLength;

- (id)initWithAlbum:(ISMSAlbum *)theAlbum numberOfTracks:(NSUInteger)numTracks albumLength:(NSUInteger)length;
- (IBAction)dismiss:(id)sender;

@end
