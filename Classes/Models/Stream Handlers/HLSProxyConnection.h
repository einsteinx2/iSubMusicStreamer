//
//  HTTPSProxyConnection.h
//  libSub
//
//  Created by Benjamin Baron on 1/5/13.
//  Copyright (c) 2013 Einstein Times Two Software. All rights reserved.
//

// This class is necessary to proxy HTTPS video plays becuase MPMoviePlayer doesn't like to play from self signed SSL connections.
// Instead, we'll have the player connect to our localhost proxy and hae the proxy download each chunk and pass it on.

#import "HTTPConnection.h"

@interface HLSProxyConnection : HTTPConnection

@end
