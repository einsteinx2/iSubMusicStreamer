//
//  Album.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSAlbum.h"
#import "RXMLElement.h"
#import "ISMSArtist.h"
#import "EX2Kit.h"
#import "DatabaseSingleton.h"

@implementation ISMSAlbum

- (instancetype)initWithRXMLElement:(RXMLElement *)element {
    NSString *artistId = [[element attribute:@"parent"] cleanString];
    NSString *artistName = [[element attribute:@"artist"] cleanString];
    
    return [self initWithRXMLElement:element artistId:artistId artistName:artistName];
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet {
    if (self = [super init]) {
        _title = [[element attribute:@"title"] cleanString];
        _albumId = [[element attribute:@"id"] cleanString];
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        _artistId = [artistIdToSet cleanString];
        _artistName = [artistNameToSet cleanString];
    }
    
    return self;
}

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict {
	if (self = [super init]) {
		_title = [[attributeDict objectForKey:@"title"] cleanString];
		_albumId = [[attributeDict objectForKey:@"id"] cleanString];
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		_artistName = [[attributeDict objectForKey:@"artist"] cleanString];
		_artistId = [[attributeDict objectForKey:@"parent"] cleanString];
	}
	
	return self;
}


- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist {
	if (self = [super init]) {
		_title = [[attributeDict objectForKey:@"title"] cleanString];
		_albumId = [[attributeDict objectForKey:@"id"] cleanString];
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		
		if (myArtist) {
			_artistName = myArtist.name;
			_artistId = myArtist.artistId;
		}
	}
	
	return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:self.title];
	[encoder encodeObject:self.albumId];
	[encoder encodeObject:self.coverArtId];
	[encoder encodeObject:self.artistName];
	[encoder encodeObject:self.artistId];
}


- (instancetype)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		_title = [[decoder decodeObject] copy];
		_albumId = [[decoder decodeObject] copy];
		_coverArtId = [[decoder decodeObject] copy];
		_artistName = [[decoder decodeObject] copy];
		_artistId = [[decoder decodeObject] copy];
	}
	
	return self;
}


- (instancetype)copyWithZone:(NSZone *)zone {
	ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
	anAlbum.title = [self.title copy];
	anAlbum.albumId = [self.albumId copy];
	anAlbum.coverArtId = [self.coverArtId copy];
	anAlbum.artistName = [self.artistName copy];
	anAlbum.artistId = [self.artistId copy];
	return anAlbum;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@: title: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], self.title, self.self.albumId, self.coverArtId, self.artistName, self.artistId];
}

- (ISMSArtist *)artist {
    return [ISMSArtist artistWithName:self.artistName andArtistId:self.artistId];
}

#pragma mark Table Cell Model

- (NSString *)primaryLabelText { return self.title; }
- (NSString *)secondaryLabelText { return self.artistName; }
- (NSString *)durationLabelText { return nil; }
- (void)download { [databaseS downloadAllSongs:self.albumId artist:[self artist]]; }
- (void)queue { [databaseS queueAllSongs:self.albumId artist:[self artist]]; }

@end
