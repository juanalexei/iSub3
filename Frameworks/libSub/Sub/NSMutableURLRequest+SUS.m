//
//  NSMutableURLRequest+SUS.m
//  iSub
//
//  Created by Benjamin Baron on 10/31/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+URLEncode.h"

@implementation NSMutableURLRequest (SUS)

static NSArray *ver1_0_0 = nil;
static NSArray *ver1_2_0 = nil;
static NSArray *ver1_3_0 = nil;
static NSArray *ver1_4_0 = nil;
static NSArray *ver1_5_0 = nil;
static NSArray *ver1_6_0 = nil;
static NSArray *ver1_8_0 = nil;
static NSSet *setOfVersions = nil;

+ (void)initialize
{
//DLog(@"NSMutableURLRequest initialize called");
    ver1_0_0 = @[@"ping", @"getLicense", @"getMusicFolders", @"getNowPlaying", @"getIndexes", @"getMusicDirectory", @"search", @"getPlaylists", @"getPlaylist", @"download", @"stream", @"getCoverArt", @"1.0.0"];
    ver1_2_0 = @[@"createPlaylist", @"deletePlaylist", @"getChatMessages", @"addChatMessage", @"getAlbumList", @"getRandomSongs", @"getLyrics", @"jukeboxControl", @"1.2.0"];
    ver1_3_0 = @[@"getUser", @"deleteUser", @"1.3.0"];
    ver1_4_0 = @[@"search2", @"1.4.0"];
    ver1_5_0 = @[@"scrobble", @"1.5.0"];
    ver1_6_0 = @[@"getPodcasts", @"getShares", @"createShare", @"updateShare", @"deleteShare", @"setRating", @"1.6.0"];
    ver1_8_0 = @[@"hls", @"getAlbumList2", @"1.8.0"];
    setOfVersions = [[NSSet alloc] initWithObjects:ver1_0_0, ver1_2_0, ver1_3_0, ver1_4_0, ver1_5_0, ver1_6_0, ver1_8_0, nil];
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
    NSMutableString *urlString = [url isEqualToString:@"https://one.ubuntu.com/music"] ? [NSMutableString stringWithFormat:@"%@/api/1.0/%@.view", url, action] :
                                                                                         [NSMutableString stringWithFormat:@"%@/rest/%@.view", url, action];
    if ([action isEqualToString:@"hls"])
        urlString = [NSMutableString stringWithFormat:@"%@/rest/%@.m3u8", url, action];
	NSString *username = [user URLEncodeString];
	NSString *password = [pass URLEncodeString];
	NSString *version = nil;
	
	// Set the API version for this call by checking the arrays
	for (NSArray *versionArray in setOfVersions)
	{
		if ([versionArray containsObject:action])
		{
			version = [versionArray lastObject];
			break;
		}
	}
	NSAssert(version != nil, @"SUS URL API version not set!");
	
	// Setup the POST parameters
	//NSMutableString *postString = [NSMutableString stringWithFormat:@"v=%@&c=iSub", version];
	NSMutableString *postString = [NSMutableString stringWithFormat:@"v=%@&c=iSub&u=%@&p=%@", version, username, password];
	if (parameters != nil)
	{
		for (NSString *key in [parameters allKeys])
		{
			if ((NSNull *)[parameters objectForKey:key] == [NSNull null])
			{
				//if ([NSThread respondsToSelector:@selector(callStackSymbols)])
                    //DLog(@"Received a null parameter for key: %@ for action: %@  stack trace:\n%@", key, action, [NSThread callStackSymbols]);
			}
			else
			{
				id value = [parameters objectForKey:key];
				if ([value isKindOfClass:[NSArray class]])
				{
					// handle multiple values for key
					for (id subValue in (NSArray*)value)
					{
						if ([subValue isKindOfClass:[NSString class]])
						{
							// handle single value for key
							[postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString*)subValue URLEncodeString]];
						}
                        else if ([subValue isKindOfClass:[NSNumber class]])
                        {
                            // Convert numbers to strings
							[postString appendFormat:@"&%@=%@", [key URLEncodeString], [[(NSNumber *)subValue stringValue] URLEncodeString]];
                        }
					}
				}
				else if ([value isKindOfClass:[NSString class]])
				{
					// handle single value for key
					[postString appendFormat:@"&%@=%@", [key URLEncodeString], [(NSString*)value URLEncodeString]];
				}
			}
		}
	}
	//DLog(@"post string: %@", postString);
	
	// Handle special case when loading playlists
	NSTimeInterval loadingTimeout = ISMSLoadingTimeout;
	if ([action isEqualToString:@"getPlaylist"])
	{
		loadingTimeout = 3600.0; // Timeout set to 60 mins to prevent timeout errors
	}
	else if ([action isEqualToString:@"ping"])
	{
		loadingTimeout = ISMSServerCheckTimeout;
	}
	
	if ([url isEqualToString:@"https://one.ubuntu.com/music"])
	{
		// This is Ubuntu One, send as GET request
		[urlString appendFormat:@"?%@", postString];
	}
	
	// Create the request
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString] 
									  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
								  timeoutInterval:loadingTimeout];
	
	if ([url isEqualToString:@"https://one.ubuntu.com/music"])
	{
		[request setHTTPMethod:@"GET"]; 
	}
	else
	{
		[request setHTTPMethod:@"POST"]; 
		[request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	}
	
	// Set the HTTP Basic Auth
	if (settingsS.isBasicAuthEnabled)
	{
		//DLog(@"using basic auth!");
		NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
		NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
		NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:0]];
		[request setValue:authValue forHTTPHeaderField:@"Authorization"];
	}
	
	if (offset > 0)
	{
		NSString *rangeString = [NSString stringWithFormat:@"bytes=%ld-", (long)offset];
		[request setValue:rangeString forHTTPHeaderField:@"Range"];
	}
    
    // Turn off request caching
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
	
	//DLog(@"request: %@", request);
    
    return request;
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action urlString:(NSString *)url username:(NSString *)user password:(NSString *)pass parameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithSUSAction:action urlString:url username:user password:pass parameters:nil byteOffset:0];
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters byteOffset:(NSUInteger)offset
{
	NSString *urlString = settingsS.urlString;
	if (settingsS.redirectUrlString)
	{
		// The redirect URL has been found, so use it
		urlString = settingsS.redirectUrlString;
	}
	
//DLog(@"username: %@   password: %@", settingsS.username, settingsS.password);
	
	return [NSMutableURLRequest requestWithSUSAction:action 
										urlString:urlString 
											username:settingsS.username
											password:settingsS.password 
									   parameters:parameters 
										  byteOffset:offset];
}

+ (NSMutableURLRequest *)requestWithSUSAction:(NSString *)action parameters:(NSDictionary *)parameters
{
	return [NSMutableURLRequest requestWithSUSAction:action parameters:parameters byteOffset:0];
}

@end
