/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 Copyright 2013 Medium Entertainment, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

 PHPublisherOpenRequest.m
 playhaven-sdk-ios

 Created by Jesus Fernandez on 3/30/11.
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#import "PHPublisherOpenRequest.h"
#import "PHConstants.h"
#import "SDURLCache.h"
#import "PHTimeInGame.h"
#import "PHNetworkUtil.h"
#import "PHResourceCacher.h"

static NSString *const kPHTimeZoneKey = @"tz";

@interface PHAPIRequest (Private)
- (void)finish;
+ (void)setSession:(NSString *)session;
@end

@implementation PHPublisherOpenRequest
@synthesize customUDID = _customUDID;

+ (void)initialize
{
    if (self == [PHPublisherOpenRequest class]) {
        // Initializes pre-fetching and webview caching
        PH_SDURLCACHE_CLASS *urlCache = [[PH_SDURLCACHE_CLASS alloc] initWithMemoryCapacity:PH_MAX_SIZE_MEMORY_CACHE
                                                                               diskCapacity:PH_MAX_SIZE_FILESYSTEM_CACHE
                                                                                   diskPath:[PH_SDURLCACHE_CLASS defaultCachePath]];
        [NSURLCache setSharedURLCache:urlCache];
        [urlCache release];
    }
}

- (NSDictionary *)additionalParameters
{
    NSMutableDictionary *additionalParameters = [NSMutableDictionary dictionary];

    if (!!self.customUDID) {
        [additionalParameters setValue:self.customUDID forKey:@"d_custom"];
    }

#if PH_USE_MAC_ADDRESS == 1
    if (![PHAPIRequest optOutStatus]) {
        PHNetworkUtil *netUtil = [PHNetworkUtil sharedInstance];
        CFDataRef macBytes = [netUtil newMACBytes];
        if (macBytes) {
            [additionalParameters setValue:[netUtil stringForMACBytes:macBytes] forKey:@"d_mac"];
            [additionalParameters setValue:[netUtil ODIN1ForMACBytes:macBytes] forKey:@"d_odin1"];
            CFRelease(macBytes);
        }
    }
#endif

    [additionalParameters setValue:[NSNumber numberWithInt:[[PHTimeInGame getInstance] getCountSessions]]
                            forKey:@"scount"];
    [additionalParameters setValue:[NSNumber numberWithInt:(int)floor([[PHTimeInGame getInstance] getSumSessionDuration])]
                            forKey:@"ssum"];
    [additionalParameters setObject:[self timeZoneOffsetFromGMTAsString] forKey:kPHTimeZoneKey];

    return  additionalParameters;
}

- (NSString *)urlPath
{
    return PH_URL(/v3/publisher/open/);
}

#pragma mark - PHAPIRequest response delegate
- (void)send
{
    [super send];
    [[PHTimeInGame getInstance] gameSessionStarted];
}

- (void)didSucceedWithResponse:(NSDictionary *)responseData
{
    id urlArray = [responseData valueForKey:@"precache"];

    if (urlArray && [urlArray isKindOfClass:[NSArray class]])
        for (id url in urlArray)
            if ([url isKindOfClass:[NSString class]])
                [PHResourceCacher prefetchObject:url];


    NSString *session = (NSString *)[responseData valueForKey:@"session"];
    if (!!session) {
        [PHAPIRequest setSession:session];
    }

    if ([self.delegate respondsToSelector:@selector(request:didSucceedWithResponse:)]) {
        [self.delegate performSelector:@selector(request:didSucceedWithResponse:) withObject:self withObject:responseData];
    }

    // Reset time in game counters;
    [[PHTimeInGame getInstance] resetCounters];

    [self finish];
}

#pragma mark - NSObject

- (void)dealloc
{
    [_customUDID release], _customUDID = nil;
    [super dealloc];
}

#pragma mark - Private

- (NSString *)timeZoneOffsetFromGMTAsString
{
    return [NSString stringWithFormat:@"%d.%d", [[NSTimeZone systemTimeZone] secondsFromGMT] / 3600,
                ([[NSTimeZone systemTimeZone] secondsFromGMT] % 3600) / 60];
}

@end
