//
//  EX2Macros.h
//  EX2Kit
//
//  Created by Ben Baron on 3/10/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef EX2Kit_Macros_h
#define EX2Kit_Macros_h

#define BytesFromKB(value) (value * 1000)
#define BytesFromMB(value) (BytesFromKB(value) * 1000)
#define BytesFromGB(value) (BytesFromMB(value) * 1000)

#define BytesFromKiB(value) (value * 1024)
#define BytesFromMiB(value) (BytesFromKiB(value) * 1024)
#define BytesFromGiB(value) (BytesFromMiB(value) * 1024)

// iPad hardware detection (will detect as iPad if running an iPhone only app on an iPad)
#define IS_IPAD_HW() ([[[UIDevice currentDevice] model] hasPrefix:@"iPad"])

// iPad app type detection (will detect as iPhone if running an iPhone only app on an iPad)
#define IS_IPAD() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

// Lite version build switch
#ifdef LITE
#define IS_LITE() (true)  // ENABLE  Lite version
#else
#define IS_LITE() (false) // DISABLE Lite version
#endif

// Beta version build switch
#ifdef BETA
#define IS_BETA() (true)
#else
#define IS_BETA() (false)
#endif

// Debug version build switch (activated only on debug builds)
#ifdef DEBUG
#define IS_DEBUG() (true)
#else
#define IS_DEBUG() (false)
#endif

// Adhoc version build switch (activated only on adhoc)
#ifdef ADHOC
#define IS_ADHOC() (true)
#else
#define IS_ADHOC() (false)
#endif

// Release version build switch
#ifdef RELEASE
#define IS_RELEASE() (true)
#else
#define IS_RELEASE() (false)
#endif

// Screen scale detection
#ifdef IOS
#define SCREEN_SCALE() ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f)
#else
#define SCREEN_SCALE() ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)] ? [[NSScreen mainScreen] backingScaleFactor] : 1.0f)
#endif

// Check if simulator
#if TARGET_IPHONE_SIMULATOR
#define IS_SIMULATOR() (true)
#else
#define IS_SIMULATOR() (false)
#endif

// DLog is almost a drop-in replacement for NSLog
// DLog();
// DLog(@"here");
// DLog(@"value: %d", x);
// Unfortunately this doesn't work DLog(aStringVariable); you have to do this instead DLog(@"%@", aStringVariable);
#ifdef DEBUG
#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define DLog(...)
#endif

// ALog always displays output regardless of the DEBUG setting
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#define n2N(value) (value ? value : [NSNull null])
#define N2n(value) (value == [NSNull null] ? nil : value)
#define n2blank(value) (value ? value : @"")
#define n2zero(value) (value ? value : @(0))

//static id n2N(id value) { return value ? value : [NSNull null]; }

#define NSStringFromBOOL(value) (value ? @"YES" : @"NO")

#define BytesForSecondsAtBitrate(seconds, bitrate) ((bitrate / 8) * 1024 * seconds)

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define IS_IOS7() (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7"))

// Shim to support @YES and @NO in Xcode 4.4
// From this SO answer: http://stackoverflow.com/a/11697204/299262
#ifndef __IPHONE_6_0
#if __has_feature(objc_bool)
#undef YES
#undef NO
#define YES __objc_yes
#define NO __objc_no
#endif
#endif

// Temporary hack, need a proper solution
#define IS_TALL_SCREEN() (CGSizeEqualToSize([[UIScreen mainScreen] preferredMode].size, CGSizeMake(640, 1136)))

#define NSIndexPathMake(section, row) ([NSIndexPath indexPathForRow:row inSection:section])

#endif
