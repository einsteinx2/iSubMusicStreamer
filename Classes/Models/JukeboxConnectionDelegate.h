//
//  JukeboxConnectionDelegate.h
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class MusicSingleton;

@interface JukeboxConnectionDelegate : NSObject 

@property (strong) NSMutableData *receivedData;
@property BOOL isGetInfo;

@end
