//
//  ArtistUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface GenresArtistUITableViewCell : CustomUITableViewCell 

@property (copy) NSString *genre;

@property (strong) UIScrollView *artistNameScrollView;
@property (strong) UILabel *artistNameLabel;

@end
