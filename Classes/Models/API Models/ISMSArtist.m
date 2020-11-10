//
//  Artist.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSArtist.h"

@implementation ISMSArtist

+ (ISMSArtist *)artistWithName:(NSString *)theName andArtistId:(NSString *)theId
{
	ISMSArtist *anArtist = [[ISMSArtist alloc] init];
	anArtist.name = theName;
	anArtist.artistId = theId;
	
	return anArtist;
}

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict
{
	if ((self = [super init]))
	{
		_name = [[attributeDict objectForKey:@"name"] cleanString];
		_artistId = [[attributeDict objectForKey:@"id"] cleanString];
	}
	
	return self;
}

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element
{
	if ((self = [super init]))
	{
		_name = [[TBXML valueOfAttributeNamed:@"name" forElement:element] cleanString];
		_artistId = [[TBXML valueOfAttributeNamed:@"id" forElement:element] cleanString];
	}
	
	return self;
}

- (instancetype)initWithRXMLElement:(RXMLElement *)element
{
    if ((self = [super init]))
    {
        _name = [[element attribute:@"name"] cleanString];
        _artistId = [[element attribute:@"id"] cleanString];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.name];
	[encoder encodeObject:self.artistId];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		_name = [[decoder decodeObject] copy];
		_artistId = [[decoder decodeObject] copy];
	}
	
	return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	ISMSArtist *anArtist = [[ISMSArtist alloc] init];
	
	anArtist.name = self.name;
	anArtist.artistId = self.artistId;
	
	return anArtist;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: name: %@, artistId: %@", [super description], self.name, self.artistId];
}


@end
