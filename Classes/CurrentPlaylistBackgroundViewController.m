//
//  CurrentPlaylistBackgroundViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistBackgroundViewController.h"
#import "CurrentPlaylistViewController.h"

@implementation CurrentPlaylistBackgroundViewController

- (void)viewDidLoad 
{
	self.playlistView = [[CurrentPlaylistViewController alloc] initWithNibName:@"CurrentPlaylistViewController" bundle:nil];
	[self.view addSubview:self.playlistView.view];
		
    [super viewDidLoad];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[self.playlistView viewDidDisappear:NO];
	self.playlistView = nil;
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


@end
