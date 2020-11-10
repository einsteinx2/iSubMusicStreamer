//
//  Artist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@class RXMLElement;
@interface ISMSArtist : NSObject <NSCoding, NSCopying>

@property (copy) NSString *name;
@property (copy) NSString *artistId;

+ (ISMSArtist *) artistWithName:(NSString *)theName andArtistId:(NSString *)theId;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (instancetype)initWithCoder:(NSCoder *)decoder;

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict;

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;

@end
