//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class ISMSArtist;

@interface ISMSAlbum : NSObject <NSCoding, NSCopying> 

@property (copy) NSString *title;
@property (copy) NSString *albumId;
@property (copy) NSString *coverArtId;
@property (copy) NSString *artistName;
@property (copy) NSString *artistId;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (id)initWithCoder:(NSCoder *)decoder;

- (id)copyWithZone:(NSZone *)zone;

- (id)initWithPMSDictionary:(NSDictionary *)dictionary;

- (id)initWithAttributeDict:(NSDictionary *)attributeDict;
- (id)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist;
- (id)initWithTBXMLElement:(TBXMLElement *)element;
- (id)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
- (id)initWithRXMLElement:(RXMLElement *)element;
- (id)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
@end
