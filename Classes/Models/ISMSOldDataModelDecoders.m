//
//  ISMSOldDataModelDecoders.m
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "ISMSOldDataModelDecoders.h"
#import "ISMSServer.h"
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSSong.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"

@implementation Server
- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
    return [[ISMSServer alloc] initWithCoder:aDecoder];
}
@end

@implementation Artist
- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
    return [[ISMSArtist alloc] initWithCoder:aDecoder];
}
@end

@implementation Album
- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
    return [[ISMSAlbum alloc] initWithCoder:aDecoder];
}
@end

@implementation Song
- (void)encodeWithCoder:(NSCoder *)aCoder { }
- (id)initWithCoder:(NSCoder *)aDecoder
{
    return [[ISMSSong alloc] initWithCoder:aDecoder];
}
@end

#pragma clang diagnostic pop
