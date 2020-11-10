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

@implementation ISMSAlbum

- (instancetype)initWithPMSDictionary:(NSDictionary *)dictionary
{
	if ((self = [super init]))
	{
		// NOTE: IDs are apparantly stored as NSNumbers when deserialized because
        // they are integer strings
        
		_title = N2n([dictionary objectForKey:@"folderName"]);
		
        id albumId = N2n([dictionary objectForKey:@"folderId"]);
        _albumId = albumId ? [NSString stringWithFormat:@"%@", albumId] : nil;
		
        id coverArtId = N2n([dictionary objectForKey:@"artId"]);
        _coverArtId = coverArtId ? [NSString stringWithFormat:@"%@", coverArtId] : nil;
		
        _artistName = N2n([dictionary objectForKey:@"artistName"]);
		
        id artistId = N2n([dictionary objectForKey:@"artistId"]);
        _artistId = artistId ? [NSString stringWithFormat:@"%@", artistId] : nil;
	}
	return self;
}

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element
{
    NSString *artistId = [[TBXML valueOfAttributeNamed:@"parent" forElement:element] cleanString];
    NSString *artistName = [[TBXML valueOfAttributeNamed:@"artist" forElement:element] cleanString];
    
	return [self initWithTBXMLElement:element artistId:artistId artistName:artistName];
}

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet
{
	if ((self = [super init]))
	{
		_title = [[TBXML valueOfAttributeNamed:@"title" forElement:element] cleanString];
		_albumId = [[TBXML valueOfAttributeNamed:@"id" forElement:element] cleanString];
		_coverArtId = [[TBXML valueOfAttributeNamed:@"coverArt" forElement:element] cleanString];
		_artistId = [artistIdToSet cleanString];
		_artistName = [artistNameToSet cleanString];
	}
	
	return self;
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element
{
    NSString *artistId = [[element attribute:@"parent"] cleanString];
    NSString *artistName = [[element attribute:@"artist"] cleanString];
    
    return [self initWithRXMLElement:element artistId:artistId artistName:artistName];
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet
{
    if ((self = [super init]))
    {
        _title = [[element attribute:@"title"] cleanString];
        _albumId = [[element attribute:@"id"] cleanString];
        _coverArtId = [[element attribute:@"coverArt"] cleanString];
        _artistId = [artistIdToSet cleanString];
        _artistName = [artistNameToSet cleanString];
    }
    
    return self;
}

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		_title = [[attributeDict objectForKey:@"title"] cleanString];
		_albumId = [[attributeDict objectForKey:@"id"] cleanString];
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		_artistName = [[attributeDict objectForKey:@"artist"] cleanString];
		_artistId = [[attributeDict objectForKey:@"parent"] cleanString];
	}
	
	return self;
}


- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist
{
	if ((self = [super init]))
	{
		_title = [[attributeDict objectForKey:@"title"] cleanString];
		_albumId = [[attributeDict objectForKey:@"id"] cleanString];
		_coverArtId = [[attributeDict objectForKey:@"coverArt"] cleanString];
		
		if (myArtist)
		{
			_artistName = myArtist.name;
			_artistId = myArtist.artistId;
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.title];
	[encoder encodeObject:self.albumId];
	[encoder encodeObject:self.coverArtId];
	[encoder encodeObject:self.artistName];
	[encoder encodeObject:self.artistId];
}


- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		_title = [[decoder decodeObject] copy];
		_albumId = [[decoder decodeObject] copy];
		_coverArtId = [[decoder decodeObject] copy];
		_artistName = [[decoder decodeObject] copy];
		_artistId = [[decoder decodeObject] copy];
	}
	
	return self;
}


- (instancetype)copyWithZone:(NSZone *)zone
{
	ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
	
	anAlbum.title = [self.title copy];
	anAlbum.albumId = [self.albumId copy];
	anAlbum.coverArtId = [self.coverArtId copy];
	anAlbum.artistName = [self.artistName copy];
	anAlbum.artistId = [self.artistId copy];
	
	return anAlbum;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: title: %@, albumId: %@, coverArtId: %@, artistName: %@, artistId: %@", [super description], self.title, self.self.albumId, self.coverArtId, self.artistName, self.artistId];
}



@end
