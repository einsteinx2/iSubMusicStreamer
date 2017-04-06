//
//  IDTwitterAccountChooserViewController.h
//  AngelFon
//
//  Created by Carlos Oliva on 05-12-12.
//  Copyright (c) 2012 iDev Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IDTwitterAccountChooserViewController, ACAccount;

typedef void (^IDTwitterAccountChooserViewControllerCompletionHandler)(ACAccount *account);

@protocol IDTwitterAccountChooserViewControllerDelegate <NSObject>

@optional

// if the user hits 'cancel' on the chooser then 'account' will be set to nil
- (void)twitterAccountChooserViewController:(IDTwitterAccountChooserViewController *)controller didChooseTwitterAccount:(ACAccount *)account;

@end


@interface IDTwitterAccountChooserViewController : UINavigationController

- (void)setTwitterAccounts:(NSArray *)twitterAccounts;
- (void)setAccountChooserDelegate:(id <IDTwitterAccountChooserViewControllerDelegate>)delegate;
- (void)setCompletionHandler:(IDTwitterAccountChooserViewControllerCompletionHandler)completionHandler;


@end
