//
//  Song.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ISMSTableCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@class RXMLElement;
NS_SWIFT_NAME(Song)
@interface ISMSSong : NSObject <ISMSTableCellModel, NSSecureCoding, NSCopying>

@property (nullable, copy) NSString *title;
@property (nullable, copy) NSString *songId;
@property (nullable, copy) NSString *parentId;
@property (nullable, copy) NSString *artist;
@property (nullable, copy) NSString *album;
@property (nullable, copy) NSString *genre;
@property (nullable, copy) NSString *coverArtId;
@property (nullable, copy) NSString *path;
@property (nullable, copy) NSString *suffix;
@property (nullable, copy) NSString *transcodedSuffix;
@property (nullable, copy) NSNumber *duration;
@property (nullable, copy) NSNumber *bitRate;
@property (nullable, copy) NSNumber *track;
@property (nullable, copy) NSNumber *year;
@property (nullable, copy) NSNumber *size;
@property (nullable, copy) NSNumber *discNumber;
@property BOOL isVideo;

- (nullable NSString *)localSuffix;
- (nullable NSString *)localPath;
- (nullable NSString *)localTempPath;
- (nullable NSString *)currentPath;
@property (readonly) BOOL isTempCached;
@property (readonly) unsigned long long localFileSize;
@property (readonly) NSUInteger estimatedBitrate;

- (void)encodeWithCoder:(NSCoder *)encoder;
- (instancetype)initWithCoder:(NSCoder *)decoder;

- (instancetype)copyWithZone:(nullable NSZone *)zone;

- (instancetype)initWithRXMLElement:(RXMLElement *)element;
- (instancetype)initWithAttributeDict:(NSDictionary *)attributeDict;

- (BOOL)isEqualToSong:(ISMSSong	*)otherSong;

@end

NS_ASSUME_NONNULL_END
