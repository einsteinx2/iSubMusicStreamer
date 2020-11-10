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
- (instancetype)initWithCoder:(NSCoder *)decoder;

- (instancetype)copyWithZone:(NSZone *)zone;

- (instancetype)initWithPMSDictionary:(NSDictionary *)dictionary;

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict;
- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist;
- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
@end
