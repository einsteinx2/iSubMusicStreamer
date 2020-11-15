//
//  SearchSongsViewController.h
//  iSub
//
//  Created by bbaron on 10/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//
//  ---------------
//	searchType:
//
//	0 = artist
//	1 = album
//	2 = song
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
	ISMSSearchSongsSearchType_Artists = 0,
	ISMSSearchSongsSearchType_Albums,
	ISMSSearchSongsSearchType_Songs
} ISMSSearchSongsSearchType;

@class ISMSArtist, ISMSAlbum, ISMSSong;
@interface SearchSongsViewController : UITableViewController 

@property (nullable, copy) NSString *query;
@property ISMSSearchSongsSearchType searchType;
@property (nullable, strong) NSMutableArray<ISMSArtist*> *listOfArtists;
@property (nullable, strong) NSMutableArray<ISMSAlbum*> *listOfAlbums;
@property (nullable, strong) NSMutableArray<ISMSSong*> *listOfSongs;
@property NSUInteger offset;
@property BOOL isMoreResults;
@property BOOL isLoading;
@property (nullable, strong) NSURLConnection *connection;
@property (nullable, strong) NSMutableData *receivedData;	

@end

NS_ASSUME_NONNULL_END
