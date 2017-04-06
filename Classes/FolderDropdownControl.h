//
//  FolderDropdownControl.h
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownDelegate.h"

@interface FolderDropdownControl : UIView <NSXMLParserDelegate>

@property (nonatomic, strong) CALayer *arrowImage;
@property (nonatomic) CGFloat sizeIncrease;
@property (nonatomic, strong) NSMutableDictionary *updatedfolders;	
@property (nonatomic, strong) UILabel *selectedFolderLabel;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableArray *labels;
@property (nonatomic, strong) NSDictionary *folders;
@property (nonatomic) BOOL isOpen;
@property (nonatomic, strong) NSNumber *selectedFolderId;
@property (nonatomic, strong) UIButton *dropdownButton;

// Colors
@property (nonatomic, strong) UIColor *borderColor;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *lightColor;
@property (nonatomic, strong) UIColor *darkColor;

@property (nonatomic, weak) id<FolderDropdownDelegate> delegate;

- (void)selectFolderWithId:(NSNumber *)folderId;
- (void)updateFolders;
- (void)closeDropdown;
- (void)closeDropdownFast;

@end
