//
//  Album.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

NS_ASSUME_NONNULL_BEGIN

@class ISMSArtist, RXMLElement;
NS_SWIFT_NAME(Album)
@interface ISMSAlbum : NSObject <NSSecureCoding, NSCopying> 

@property (nullable, copy) NSString *title;
@property (nullable, copy) NSString *albumId;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, copy) NSString *artistName;
@property (nullable, copy) NSString *artistId;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (instancetype)initWithCoder:(NSCoder *)decoder;

- (instancetype)copyWithZone:(nullable NSZone *)zone;

- (instancetype)initWithPMSDictionary:(NSDictionary *)dictionary;

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict;
- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict artist:(ISMSArtist *)myArtist;
- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithTBXMLElement:(TBXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element artistId:(NSString *)artistIdToSet artistName:(NSString *)artistNameToSet;
@end

NS_ASSUME_NONNULL_END
