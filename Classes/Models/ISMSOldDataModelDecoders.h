//
//  ISMSOldDataModelDecoders.h
//  iSub
//
//  Created by Ben Baron on 9/15/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

// Dirty hack to allow the old objects to be decoded since the class names were changed

@interface Server : NSObject <NSCoding>
@end

@interface Artist : NSObject <NSCoding>
@end

@interface Album : NSObject <NSCoding>
@end

@interface Song : NSObject <NSCoding>
@end


