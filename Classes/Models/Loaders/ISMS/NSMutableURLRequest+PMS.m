//
//  NSMutableURLRequest+PMS.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

@implementation NSMutableURLRequest (PMS)

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action urlString:(NSString *)url parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
	NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@/api/%@", url, action];
    
    NSMutableString *postString;
    if ([action isEqualToString:@"login"])
    {
        // Must have username and password
        if (![parameters objectForKey:@"u"] || ![parameters objectForKey:@"p"])
            return nil;
        
        NSString *version = @"1";
        postString = [NSMutableString stringWithFormat:@"v=%@&c=iSub", version];
    }
    else
    {
        postString = [NSMutableString stringWithFormat:@"s=%@", settingsS.sessionId];
    }
	
	// Setup the POST parameters
	if (parameters != nil)
	{
		for (NSString *key in [parameters allKeys])
		{
			if ((NSNull *)[parameters objectForKey:key] == [NSNull null])
			{
				if ([NSThread respondsToSelector:@selector(callStackSymbols)])
					DLog(@"Received a null parameter for key: %@ for action: %@  stack trace:\n%@", key, action, [NSThread callStackSymbols]);
			}
			else
			{
				id value = [parameters objectForKey:key];
				if ([value isKindOfClass:[NSArray class]])
				{
                    NSArray *array = (NSArray *)value;
                    if (array.count == 1)
                    {
                        id subValue = array.firstObject;
                        if ([subValue isKindOfClass:[NSString class]])
                        {
                            // handle single value for key
                            [postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString *)subValue URLEncodeString]];
                        }
                    }
                    else if (array.count > 1)
                    {
                        [postString appendFormat:@"&%@=", [key URLEncodeString]];
                        
                        // handle multiple values for key, comma separated
                        bool isFirst = YES;
                        for (id subValue in (NSArray*)value)
                        {
                            if ([subValue isKindOfClass:[NSString class]])
                            {
                                if (!isFirst)
                                {
                                    [postString appendString:@","];
                                }
                                isFirst = NO;
                                
                                // handle single value for key
                                [postString appendString:[(NSString*)subValue URLEncodeString]];
                            }
                        }
                    }					
				}
				else if ([value isKindOfClass:[NSString class]])
				{
					// handle single value for key
                    // if we're scrobbling, do not url encode the value, as we use commas in the event.
                    if ([action isEqualToString:@"scrobble"])
                    {
                        [postString appendFormat:@"&%@=%@", [key URLEncodeString], (NSString*)value];
                    }
                    else
                    {
                        [postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString*)value URLEncodeString]];
                    }
				}
			}
		}
	}
    NSLog(@" ");
    DLog(@"url string: %@", urlString);
	DLog(@"post string: %@", postString);
	NSLog(@" ");
    
	// Handle special case when loading playlists
	NSTimeInterval loadingTimeout = ISMSLoadingTimeout;
	
	// Create the request
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] 
														   cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
													   timeoutInterval:loadingTimeout];
	
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
	
	// Set the HTTP Basic Auth
	if (settingsS.isBasicAuthEnabled)
	{
		DLog(@"using basic auth!");
		NSString *authStr = [NSString stringWithFormat:@"%@:%@", settingsS.username, settingsS.password];
		NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
		NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:0]];
		[request setValue:authValue forHTTPHeaderField:@"Authorization"];
	}
	
	if (offset > 0)
	{
		NSString *rangeString = [NSString stringWithFormat:@"bytes=%lu-", (unsigned long)offset];
		[request setValue:rangeString forHTTPHeaderField:@"Range"];
	}
	
	//DLog(@"request: %@", request);
    
    return request;
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
	NSString *urlString = settingsS.urlString;
	if (settingsS.redirectUrlString)
	{
		// The redirect URL has been found, so use it
		urlString = settingsS.redirectUrlString;
	}
	DLog(@"settingsS.redirectUrlString = %@   urlString = %@", settingsS.redirectUrlString, urlString);
    
    //DLog(@"username: %@   password: %@", settingsS.username, settingsS.password);
	
	return [NSMutableURLRequest requestWithPMSAction:action urlString:urlString parameters:parameters byteOffset:offset];
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action parameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithPMSAction:action parameters:parameters byteOffset:0];
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action itemId:(NSString *)itemId
{
    if (!itemId)
        return nil;
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:itemId forKey:@"id"];
	return [NSMutableURLRequest requestWithPMSAction:action parameters:parameters];
}

+ (NSMutableURLRequest *)requestWithPMSAction:(NSString *)action
{
    return [NSMutableURLRequest requestWithPMSAction:action parameters:nil];
}

@end
