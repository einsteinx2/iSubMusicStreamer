//
//  Artist.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

NS_ASSUME_NONNULL_BEGIN

@class RXMLElement;
NS_SWIFT_NAME(Artist)
@interface ISMSArtist : NSObject <NSSecureCoding, NSCopying>

@property (nullable, copy) NSString *name;
@property (nullable, copy) NSString *artistId;

+ (ISMSArtist *)artistWithName:(NSString *)theName andArtistId:(NSString *)theId;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (instancetype)initWithCoder:(NSCoder *)decoder;

- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict;

- (instancetype)initWithTBXMLElement:(TBXMLElement *)element;
- (instancetype)initWithRXMLElement:(RXMLElement *)element;

@end

NS_ASSUME_NONNULL_END
