//
//  Song.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSSong.h"
#import "RXMLElement.h"
#import "SavedSettings.h"
#import "EX2Kit.h"
#import "FMResultSet.h"
#import <sys/stat.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation ISMSSong

- (instancetype)initWithRXMLElement:(RXMLElement *)element {
    if (self = [super init]) {
        _songId = [[element attribute:@"id"] cleanString];
        _title = [[element attribute:@"title"] cleanString];
        _artist = [[element attribute:@"artist"] cleanString];
        _album = [[element attribute:@"album"] cleanString];
        _genre = [[element attribute:@"genre"] cleanString];
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        _parentId = [[element attribute:@"parent"] cleanString];
        _tagArtistId = [[element attribute:@"artistId"] cleanString];
        _tagAlbumId = [[element attribute:@"albumId"] cleanString];
        _path = [[element attribute:@"path"] cleanString];
        _suffix = [[element attribute:@"suffix"] cleanString];
        _transcodedSuffix = [[element attribute:@"transcodedSuffix"] cleanString];
        
        NSString *durationString = [element attribute:@"duration"];
        if(durationString) _duration = @(durationString.intValue);
        
        NSString *bitRateString = [element attribute:@"bitRate"];
        if(bitRateString) _bitRate = @(bitRateString.intValue);
        
        NSString *trackString = [element attribute:@"track"];
        if(trackString) _track = @(trackString.intValue);
        
        NSString *discNumberString = [element attribute:@"discNumber"];
        if (discNumberString) _discNumber = @(discNumberString.longLongValue);
        
        NSString *yearString = [element attribute:@"year"];
        if(yearString) _year = @(yearString.intValue);
        
        NSString *sizeString = [element attribute:@"size"];
        if (sizeString) _size = @(sizeString.longLongValue);
        
        _isVideo = [[element attribute:@"isVideo"] boolValue];
    }
    
    return self;
}

- (instancetype)initWithResult:(FMResultSet *)result {
    if (self = [super init]) {
        _songId = [result stringForColumn:@"songId"];
        _title = [result stringForColumn:@"title"];
        _artist = [result stringForColumn:@"artist"];
        _album = [result stringForColumn:@"album"];
        _genre = [result stringForColumn:@"genre"];
        _coverArtId = [result stringForColumn:@"coverArtId"];
        _parentId = [result stringForColumn:@"parentId"];
        _tagArtistId = [result stringForColumn:@"tagArtistId"];
        _tagAlbumId = [result stringForColumn:@"tagAlbumId"];
        _path = [result stringForColumn:@"path"];
        _suffix = [result stringForColumn:@"suffix"];
        _transcodedSuffix = [result stringForColumn:@"transcodedSuffix"];
        _duration = @([result intForColumn:@"duration"]);
        _bitRate = @([result intForColumn:@"bitRate"]);
        _track = @([result intForColumn:@"track"]);
        if ([result stringForColumn:@"discNumber"]) {
            _discNumber = @([result intForColumn:@"discNumber"]);
        }
        _year = @([result intForColumn:@"year"]);
        _size = @([result intForColumn:@"size"]);
        _isVideo = [result boolForColumn:@"isVideo"];
    }
    return self;
}

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict {
	if (self = [super init]) {
        _songId = [[attributeDict objectForKey:@"id"] cleanString];
		_title = [[attributeDict objectForKey:@"title"] cleanString];
        _artist = [[attributeDict objectForKey:@"artist"] cleanString];
        _album = [[attributeDict objectForKey:@"album"] cleanString];
        _genre = [[attributeDict objectForKey:@"genre"] cleanString];
        _coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
        _parentId = [[attributeDict objectForKey:@"parent"] cleanString];
        _tagArtistId = [[attributeDict objectForKey:@"artistId"] cleanString];
        _tagAlbumId = [[attributeDict objectForKey:@"albumId"] cleanString];
        _path = [[attributeDict objectForKey:@"path"] cleanString];
        _suffix = [[attributeDict objectForKey:@"suffix"] cleanString];
        _transcodedSuffix = [[attributeDict objectForKey:@"transcodedSuffix"] cleanString];
        
        NSString *durationString = [attributeDict objectForKey:@"duration"];
        if(durationString) _duration = @(durationString.intValue);
        
        NSString *bitRateString = [attributeDict objectForKey:@"bitRate"];
        if(bitRateString) _bitRate = @(bitRateString.intValue);
		
        NSString *trackString = [attributeDict objectForKey:@"track"];
        if(trackString) _track = @(trackString.intValue);
        
        NSString *discNumberString = [attributeDict objectForKey:@"discNumber"];
        if(discNumberString) _discNumber = @(discNumberString.intValue);
        
        NSString *yearString = [attributeDict objectForKey:@"year"];
		if(yearString) _year = @(yearString.intValue);
        
        NSString *sizeString = [attributeDict objectForKey:@"size"];
        if (sizeString) _size = @(sizeString.longLongValue);
		
        _isVideo = [[attributeDict objectForKey:@"isVideo"] boolValue];
	}
	
	return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.songId forKey:@"songId"];
	[encoder encodeObject:self.title forKey:@"title"];
    [encoder encodeObject:self.artist forKey:@"artist"];
    [encoder encodeObject:self.album forKey:@"album"];
    [encoder encodeObject:self.genre forKey:@"genre"];
    [encoder encodeObject:self.coverArtId forKey:@"coverArtId"];
    [encoder encodeObject:self.parentId forKey:@"parentId"];
    [encoder encodeObject:self.tagArtistId forKey:@"tagArtistId"];
    [encoder encodeObject:self.tagAlbumId forKey:@"tagAlbumId"];
	[encoder encodeObject:self.path forKey:@"path"];
	[encoder encodeObject:self.suffix forKey:@"suffix"];
	[encoder encodeObject:self.transcodedSuffix forKey:@"transcodedSuffix"];
	[encoder encodeObject:self.duration forKey:@"duration"];
	[encoder encodeObject:self.bitRate forKey:@"bitRate"];
	[encoder encodeObject:self.track forKey:@"track"];
    [encoder encodeObject:self.discNumber forKey:@"discNumber"];
	[encoder encodeObject:self.year forKey:@"year"];
	[encoder encodeObject:self.size forKey:@"size"];
    [encoder encodeBool:self.isVideo forKey:@"isVideo"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
        _songId = [decoder decodeObjectForKey:@"songId"];
        _title = [decoder decodeObjectForKey:@"title"];
        _artist = [decoder decodeObjectForKey:@"artist"];
        _album = [decoder decodeObjectForKey:@"album"];
        _genre = [decoder decodeObjectForKey:@"genre"];
        _coverArtId = [decoder decodeObjectForKey:@"coverArtId"];
        _parentId = [decoder decodeObjectForKey:@"parentId"];
        _tagArtistId = [decoder decodeObjectForKey:@"tagArtistId"];
        _tagAlbumId = [decoder decodeObjectForKey:@"tagAlbumId"];
        _path = [decoder decodeObjectForKey:@"path"];
        _suffix = [decoder decodeObjectForKey:@"suffix"];
        _transcodedSuffix = [decoder decodeObjectForKey:@"transcodedSuffix"];
        _duration = [decoder decodeObjectForKey:@"duration"];
        _bitRate = [decoder decodeObjectForKey:@"bitRate"];
        _track = [decoder decodeObjectForKey:@"track"];
        _discNumber = [decoder decodeObjectForKey:@"discNumber"];
        _year = [decoder decodeObjectForKey:@"year"];
        _size = [decoder decodeObjectForKey:@"size"];
        _isVideo = [decoder decodeBoolForKey:@"isVideo"];
	}
	return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
	ISMSSong *newSong = [[ISMSSong alloc] init];

	// Can directly assign because properties have "copy" type
    newSong.songId = self.songId;
	newSong.title = self.title;
	newSong.artist = self.artist;
	newSong.album = self.album;
    newSong.genre = self.genre;
	newSong.coverArtId = self.coverArtId;
    newSong.parentId = self.parentId;
    newSong.tagArtistId = self.tagArtistId;
    newSong.tagAlbumId = self.tagAlbumId;
	newSong.path = self.path;
	newSong.suffix = self.suffix;
	newSong.transcodedSuffix = self.transcodedSuffix;
	newSong.duration = self.duration;
	newSong.bitRate = self.bitRate;
	newSong.track = self.track;
    newSong.discNumber = self.discNumber;
	newSong.year = self.year;
	newSong.size = self.size;
    newSong.isVideo = self.isVideo;
	return newSong;
}

- (NSString *)description {
	//return [NSString stringWithFormat:@"%@: title: %@, songId: %@", [super description], title, songId];
	return [NSString stringWithFormat:@"%@  title: %@", [super description], self.title];
}

- (NSUInteger)hash {
	return self.songId.hash;
}

- (BOOL)isEqualToSong:(ISMSSong *)otherSong {
    if (self == otherSong) return YES;
	if (!self.songId || !otherSong.songId || !self.path || !otherSong.path) return NO;
	
	if (([self.songId isEqualToString:otherSong.songId] || (self.songId == nil && otherSong.songId == nil)) &&
		([self.path isEqualToString:otherSong.path] || (self.path == nil && otherSong.path == nil)) &&
		([self.title isEqualToString:otherSong.title] || (self.title == nil && otherSong.title == nil)) &&
		([self.artist isEqualToString:otherSong.artist] || (self.artist == nil && otherSong.artist == nil)) &&
		([self.album isEqualToString:otherSong.album] || (self.album == nil && otherSong.album == nil)) &&
		([self.genre isEqualToString:otherSong.genre] || (self.genre == nil && otherSong.genre == nil)) &&
		([self.coverArtId isEqualToString:otherSong.coverArtId] || (self.coverArtId == nil && otherSong.coverArtId == nil)) &&
		([self.suffix isEqualToString:otherSong.suffix] || (self.suffix == nil && otherSong.suffix == nil)) &&
		([self.transcodedSuffix isEqualToString:otherSong.transcodedSuffix] || (self.transcodedSuffix == nil && otherSong.transcodedSuffix == nil)) &&
		([self.duration isEqualToNumber:otherSong.duration] || (self.duration == nil && otherSong.duration == nil)) &&
		([self.bitRate isEqualToNumber:otherSong.bitRate] || (self.bitRate == nil && otherSong.bitRate == nil)) &&
		([self.track isEqualToNumber:otherSong.track] || (self.track == nil && otherSong.track == nil)) &&
		([self.year isEqualToNumber:otherSong.year] || (self.year == nil && otherSong.year == nil)) &&
		([self.size isEqualToNumber:otherSong.size] || (self.size == nil && otherSong.size == nil)) &&
        self.isVideo == otherSong.isVideo)
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other  {
    if (other == self) return YES;
    if (!other || ![other isKindOfClass:[self class]]) return NO;
    return [self isEqualToSong:other];
}

- (NSString *)localSuffix {
    return self.transcodedSuffix ? self.transcodedSuffix : self.suffix;
}

- (NSString *)localPath {
    NSString *fileName = self.path.md5;    
    return fileName ? [settingsS.songCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)localTempPath {
    NSString *fileName = self.path.md5;
	return fileName ? [settingsS.tempCachePath stringByAppendingPathComponent:fileName] : nil;
}

- (NSString *)currentPath {
	return self.isTempCached ? self.localTempPath : self.localPath;
}

- (BOOL)isTempCached {
	// If the song is fully cached, then it doesn't matter if there is a temp cache file
	//if (self.isFullyCached)
	//	return NO;
	
	// Return YES if the song exists in the temp folder
	return [[NSFileManager defaultManager] fileExistsAtPath:self.localTempPath];
}

- (unsigned long long)localFileSize {
    // NOTE: This is almost certainly no longer the case
	// Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
	// Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
	// Still waiting for an answer on what the crash could be, so this is my temporary "solution"
	struct stat st;
	stat([self.currentPath cStringUsingEncoding:NSUTF8StringEncoding], &st);
	return st.st_size;
	
	//return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.currentPath error:NULL] fileSize];
}

- (NSUInteger)estimatedBitrate {
	NSInteger currentMaxBitrate = settingsS.currentMaxBitrate;
	
	// Default to 128 if there is no bitrate for this song object (should never happen)
	NSUInteger rate = (!self.bitRate || [self.bitRate intValue] == 0) ? 128 : [self.bitRate intValue];
	
	// Check if this is being transcoded to the best of our knowledge
	if (self.transcodedSuffix) {
		// This is probably being transcoded, so attempt to determine the bitrate
        if (rate > 128 && currentMaxBitrate == 0) {
			rate = 128; // Subsonic default transcoding bitrate
        } else if (rate > currentMaxBitrate && currentMaxBitrate != 0) {
			rate = currentMaxBitrate;
        }
	} else {
		// This is not being transcoded between formats, however bitrate limiting may be active
        if (rate > currentMaxBitrate && currentMaxBitrate != 0) {
			rate = currentMaxBitrate;
        }
	}

	return rate;
}

#pragma mark Table Cell Model

- (NSString *)primaryLabelText { return self.title; }
- (NSString *)secondaryLabelText { return self.artist; }
- (NSString *)durationLabelText { return [NSString formatTime:[self.duration floatValue]]; }
- (BOOL)isCached { return self.isFullyCached; }
- (void)download { [self addToDownloadQueue]; }
- (void)queue { [self addToCurrentPlaylistDbQueue]; }

@end
