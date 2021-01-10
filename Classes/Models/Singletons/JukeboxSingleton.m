//
//  JukeboxSingleton.m
//  iSub
//
//  Created by Ben Baron on 2/24/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "JukeboxSingleton.h"
#import "NSMutableURLRequest+SUS.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "DatabaseSingleton.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

@interface JukeboxXMLParserDelegate : NSObject <NSXMLParserDelegate>
@property NSUInteger currentIndex;
@property BOOL isPlaying;
@property float gain;
@property (strong) NSMutableArray *listOfSongs;
@end

@interface JukeboxSingleton()
@property (nonatomic, strong) NSURLSession *sharedSession;
@property (nonatomic, strong) SelfSignedCertURLSessionDelegate *sharedSessionDelegate;
@end

@implementation JukeboxSingleton

#pragma mark Jukebox Control methods

- (void)playSongAtPosition:(NSNumber *)position {
    [self queueDataTaskWithAction:@"skip" parameters:@{@"index": n2N(position.stringValue)}];
    PlayQueue.shared.currentIndex = position.intValue;
}


- (void)play {
    [self queueDataTaskWithAction:@"start" parameters:nil];
	self.isPlaying = YES;
}

- (void)stop {
    [self queueDataTaskWithAction:@"stop" parameters:nil];
    self.isPlaying = YES;
	self.isPlaying = NO;
}

- (void)skipPrev {
	NSInteger index = PlayQueue.shared.currentIndex - 1;
	if (index >= 0) {
		[self playSongAtPosition:@(index)];
		self.isPlaying = YES;
	}
}

- (void)skipNext {
	NSInteger index = PlayQueue.shared.currentIndex + 1;
	if (index <= ([databaseS.currentPlaylistDbQueue intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"] - 1)) {
		[self playSongAtPosition:@(index)];
		self.isPlaying = YES;
	} else {
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackEnded];
		[self stop];
		self.isPlaying = NO;
	}
}

- (void)setVolume:(float)level {
    NSString *gainString = [NSString stringWithFormat:@"%f", level];
    [self queueDataTaskWithAction:@"setGain" parameters:@{@"gain": n2N(gainString)}];
}

- (void)addSong:(NSString *)songId {
    [self queueDataTaskWithAction:@"add" parameters:@{@"id": n2N(songId)}];
}

- (void)addSongs:(NSArray *)songIds {
	if (songIds.count > 0) {
        [self queueDataTaskWithAction:@"add" parameters:@{@"id": n2N(songIds)}];
	}
}

- (void)replacePlaylistWithLocal {
	[self clearRemotePlaylist];
	
	__block NSMutableArray *songIds = [[NSMutableArray alloc] init];
	[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
        NSString *table = PlayQueue.shared.isShuffle ? @"jukeboxShufflePlaylist" : @"jukeboxCurrentPlaylist";
        FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT songId FROM %@", table]];
		while ([result next]) {
			@autoreleasepool {
				NSString *songId = [result stringForColumnIndex:0];
				if (songId) [songIds addObject:songId];
			}
		}
		[result close];
	}];
	
	[self addSongs:songIds];
}

- (void)removeSong:(NSString*)songId {
    [self queueDataTaskWithAction:@"remove" parameters:@{@"id": n2N(songId)}];
}

- (void)clearPlaylist {
    [self queueDataTaskWithAction:@"clear" parameters:nil];
    [databaseS resetJukeboxPlaylist];
}

- (void)clearRemotePlaylist {
    [self queueDataTaskWithAction:@"clear" parameters:nil];
}

- (void)shuffle {
    [self queueDataTaskWithAction:@"shuffle" parameters:nil];
    [databaseS resetJukeboxPlaylist];
}

- (void)jukeboxGetInfoInternal {
    if (settingsS.isJukeboxEnabled) {
        [self queueGetInfoDataTask];
        if (PlayQueue.shared.isShuffle) {
            [databaseS resetShufflePlaylist];
        } else {
            [databaseS resetJukeboxPlaylist];
        }
        
        // Keep reloading every 30 seconds if there is no activity so that the player stays updated if visible
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jukeboxGetInfoInternal) object:nil];
        [self performSelector:@selector(jukeboxGetInfoInternal) withObject:nil afterDelay:30.0];
    }
}

- (void)getInfo {
	// Make sure this doesn't run a bunch of times in a row
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jukeboxGetInfoInternal) object:nil];
	[self performSelector:@selector(jukeboxGetInfoInternal) withObject:nil afterDelay:0.5];
}

- (void)handleConnectionError:(NSError *)error {
    [EX2Dispatch runInMainThreadAsync:^{
        NSString *message = [NSString stringWithFormat:@"There was an error controlling the Jukebox.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)queueDataTaskWithAction:(NSString *)action parameters:(NSDictionary *)parameters {
    NSMutableDictionary *mutParams = [@{@"action": action} mutableCopy];
    if (parameters) [mutParams addEntriesFromDictionary:parameters];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:mutParams];
    NSURLSessionDataTask *dataTask = [self.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [self handleConnectionError:error];
        } else {
            JukeboxXMLParserDelegate *parserDelegate = [[JukeboxXMLParserDelegate alloc] init];
            NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:data];
            [xmlParser setDelegate:parserDelegate];
            [xmlParser parse];
            
            [EX2Dispatch runInMainThreadAsync:^{
                [jukeboxS getInfo];
            }];
        }
    }];
    [dataTask resume];
}

- (void)queueGetInfoDataTask {
    NSURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"jukeboxControl" parameters:@{@"action": @"get"}];
    NSURLSessionDataTask *dataTask = [self.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [self handleConnectionError:error];
        } else {
            JukeboxXMLParserDelegate *parserDelegate = [[JukeboxXMLParserDelegate alloc] init];
            NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:data];
            [xmlParser setDelegate:parserDelegate];
            [xmlParser parse];
                    
            [EX2Dispatch runInMainThreadAsync:^{
                PlayQueue.shared.currentIndex = parserDelegate.currentIndex;
                jukeboxS.gain = parserDelegate.gain;
                jukeboxS.isPlaying = parserDelegate.isPlaying;
                
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_SongPlaybackStarted];
                [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_JukeboxSongInfo];
            }];
        }
    }];
    [dataTask resume];
}

#pragma mark Singleton methods

- (void)setup {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    configuration.HTTPMaximumConnectionsPerHost = 1;
    self.sharedSessionDelegate = [[SelfSignedCertURLSessionDelegate alloc] init];
    self.sharedSession = [NSURLSession sessionWithConfiguration:configuration
                                                       delegate:self.sharedSessionDelegate
                                                  delegateQueue:nil];
}

+ (instancetype)sharedInstance {
    static JukeboxSingleton *sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setup];
	});
    return sharedInstance;
}

@end

#pragma mark JukeboxXMLParserDelegate

@implementation JukeboxXMLParserDelegate

- (instancetype)init {
    if (self = [super init]) {
        _listOfSongs = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    DDLogError(@"[JukeboxSingleton] subsonic error %@: %@", errorCode, message);
    
    [EX2Dispatch runInMainThreadAsync:^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }];
    
    if ([errorCode isEqualToString:@"50"]) {
        settingsS.isJukeboxEnabled = NO;
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_JukeboxDisabled];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    [EX2Dispatch runInMainThreadAsync:^{
        NSString *message = @"There was an error parsing the Jukebox XML response.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"error"]) {
        [self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
    } else if ([elementName isEqualToString:@"jukeboxPlaylist"]) {
        self.currentIndex = [[attributeDict objectForKey:@"currentIndex"] intValue];
        self.isPlaying = [[attributeDict objectForKey:@"playing"] boolValue];
        self.gain = [[attributeDict objectForKey:@"gain"] floatValue];
        
        if (PlayQueue.shared.isShuffle) {
            [databaseS resetShufflePlaylist];
        } else {
            [databaseS resetJukeboxPlaylist];
        }
    } else if ([elementName isEqualToString:@"entry"]) {
//        ISMSSong *song = [[ISMSSong alloc] initWithServerId:settingsS.currentServerId attributeDict:attributeDict];
//        if (song.path.hasValue) {
//            if (PlayQueue.shared.isShuffle) {
//                [aSong insertIntoTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
//            } else {
//                [aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
//            }
//        }
    }
}

@end
