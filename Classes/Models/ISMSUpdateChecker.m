//
//  ISMSUpdateChecker.m
//  iSub
//
//  Created by Ben Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSUpdateChecker.h"
#import "RXMLElement.h"
#import "EX2Kit.h"
#import "SUSLoader.h"

@interface ISMSUpdateChecker()
@property (strong) ISMSUpdateChecker *selfRef;
@end

@implementation ISMSUpdateChecker

- (void)checkForUpdate {
    NSURLSessionDataTask *dataTask = [SUSLoader.sharedSession dataTaskWithURL:[NSURL URLWithString:@"http://isubapp.com/update.xml"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            self.selfRef = nil;
        } else {
            BOOL showAlert = NO;
            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
            if (root.isValid) {
                if ([root.tag isEqualToString:@"update"]) {
                    NSString *currentVersion = [NSBundle.mainBundle.infoDictionary objectForKey:(NSString*)kCFBundleVersionKey];
                    self.theNewVersion = [root attribute:@"version"];
                    self.message = [root attribute:@"message"];
                    
                    NSArray *currentVersionSplit = [currentVersion componentsSeparatedByString:@"."];
                    NSArray *newVersionSplit = [self.theNewVersion componentsSeparatedByString:@"."];
                    
                    NSMutableArray *currentVersionPadded = [NSMutableArray arrayWithArray:currentVersionSplit];
                    NSMutableArray *newVersionPadded = [NSMutableArray arrayWithArray:newVersionSplit];
                    
                    if (currentVersionPadded.count < 3) {
                        for (NSInteger i = currentVersionPadded.count; i < 3; i++) {
                            [currentVersionPadded addObject:@"0"];
                        }
                    }
                    
                    if (newVersionPadded.count < 3) {
                        for (NSInteger i = newVersionPadded.count; i < 3; i++) {
                            [newVersionPadded addObject:@"0"];
                        }
                    }
                    
                    @try {
                        if (currentVersionSplit == nil || newVersionSplit == nil || currentVersionSplit.count == 0 || newVersionSplit.count == 0)
                            return;
                        
                        if ([newVersionPadded.firstObject intValue] > [currentVersionPadded.firstObject intValue]) {
                            // Major version number is bigger, update is available
                            showAlert = YES;
                        } else if ([newVersionPadded.firstObject intValue] == [currentVersionPadded.firstObject intValue]) {
                            if ([[newVersionPadded objectAtIndexSafe:1] intValue] > [[currentVersionPadded objectAtIndexSafe:1] intValue]) {
                                // Update is available
                                showAlert = YES;
                            } else if ([[newVersionPadded objectAtIndexSafe:1] intValue] == [[currentVersionPadded objectAtIndexSafe:1] intValue]) {
                                if ([[newVersionPadded objectAtIndexSafe:2] intValue] > [[currentVersionPadded objectAtIndexSafe:2] intValue]) {
                                    // Update is available
                                    showAlert = YES;
                                }
                            }
                        }
                    } @catch (NSException *exception) {
                    }
                }
            }
            if (showAlert) {
                [EX2Dispatch runInMainThreadAsync:^{
                    NSString *title = [NSString stringWithFormat:@"Free Update %@ Available", self.theNewVersion];
                    NSString *finalMessage = [self.message stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:finalMessage preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
                    [alert addAction:[UIAlertAction actionWithTitle:@"App Store" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.com/apps/isubmusicstreamer"] options:@{} completionHandler:nil];
                    }]];
                    [UIApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:^{
                        self.selfRef = nil;
                    }];
                }];
            } else {
                self.selfRef = nil;
            }
        }
    }];
    [dataTask resume];
    
	// Take ownership of self to allow connection to finish and alertview button to be pressed
    self.selfRef = self;
}

@end
