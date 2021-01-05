//
//  FolderDropdownControl.m
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownControl.h"
#import <QuartzCore/QuartzCore.h>
#import "Defines.h"
#import "SUSRootFoldersDAO.h"
#import "EX2Kit.h"
#import "Swift.h"

LOG_LEVEL_ISUB_DEFAULT

#define HEIGHT 40

@interface FolderDropdownControl() {
    NSArray<MediaFolder*> *_mediaFolders;
}
@property (nonatomic, strong) NSArray<MediaFolder*> *mediaFolders;
@property (nonatomic) NSInteger selectedFolderId;

@property (nonatomic, strong) CALayer *arrowImage;
@property (nonatomic) CGFloat sizeIncrease;
@property (nonatomic, strong) UILabel *selectedFolderLabel;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableArray *labels;
@property (nonatomic) BOOL isOpen;

@property (nonatomic, strong) UIButton *dropdownButton;

// Colors
@property (nonatomic, strong) UIColor *borderColor;
@property (nonatomic, strong) UIColor *labelTextColor;
@property (nonatomic, strong) UIColor *labelBackgroundColor;
@end

@implementation FolderDropdownControl

// TODO: Redraw border color after switching between light/dark mode
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _selectedFolderId = -1;
        _mediaFolders = [Store.shared mediaFolders];
        _labels = [[NSMutableArray alloc] init];
        _isOpen = NO;
        _borderColor = UIColor.systemGrayColor;
        _labelTextColor = UIColor.labelColor;
        _labelBackgroundColor = [UIColor colorNamed:@"isubBackgroundColor"];
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.userInteractionEnabled = YES;
        self.backgroundColor = UIColor.systemGray5Color;
        self.layer.borderColor = _borderColor.CGColor;
        self.layer.borderWidth = 2.0;
        self.layer.cornerRadius = 8;
        self.layer.masksToBounds = YES;
        
        _selectedFolderLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, self.frame.size.width - 10, HEIGHT)];
        _selectedFolderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _selectedFolderLabel.userInteractionEnabled = YES;
        _selectedFolderLabel.backgroundColor = [UIColor clearColor];
        _selectedFolderLabel.textColor = _labelTextColor;
        _selectedFolderLabel.textAlignment = NSTextAlignmentCenter;
        _selectedFolderLabel.font = [UIFont boldSystemFontOfSize:20];
        _selectedFolderLabel.text = @"All Media Folders";
        [self addSubview:_selectedFolderLabel];
        
        UIView *arrowImageView = [[UIView alloc] initWithFrame:CGRectMake(193, 12, 18, 18)];
        arrowImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self addSubview:arrowImageView];
        
        _arrowImage = [[CALayer alloc] init];
        _arrowImage.frame = CGRectMake(0, 0, 18, 18);
        _arrowImage.contentsGravity = kCAGravityResizeAspect;
        _arrowImage.contents = (id)[UIImage imageNamed:@"folder-dropdown-arrow"].CGImage;
        [[arrowImageView layer] addSublayer:_arrowImage];
        
        _dropdownButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 220, HEIGHT)];
        _dropdownButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_dropdownButton addTarget:self action:@selector(toggleDropdown:) forControlEvents:UIControlEventTouchUpInside];
        _dropdownButton.accessibilityLabel = _selectedFolderLabel.text;
        _dropdownButton.accessibilityHint = @"Switches folders";
        [self addSubview:_dropdownButton];
        
        [self updateFolders];
    }
    return self;
}

- (NSUInteger)indexOfMediaFolderId:(NSInteger)mediaFolderId {
    return [self.mediaFolders indexOfObjectWithOptions:NSEnumerationConcurrent passingTest:^BOOL(MediaFolder * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.mediaFolderId == mediaFolderId) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
}

- (NSArray<MediaFolder*> *)mediaFolders {
    return _mediaFolders;
}

- (void)setMediaFolders:(NSArray<MediaFolder*> *)mediaFolders {
    // Set the property
    _mediaFolders = mediaFolders;
    
    // Remove old labels
    for (UILabel *label in self.labels) {
        [label removeFromSuperview];
    }
    [self.labels removeAllObjects];
    
    self.sizeIncrease = mediaFolders.count * HEIGHT;
    
    // Process the names and create the labels/buttons
    for (int i = 0; i < mediaFolders.count; i++) {
        MediaFolder *mediaFolder = mediaFolders[i];
        CGRect labelFrame  = CGRectMake(0, (i + 1) * HEIGHT, self.frame.size.width, HEIGHT);
        CGRect buttonFrame = CGRectMake(0, 0, labelFrame.size.width, labelFrame.size.height);
        
        UILabel *folderLabel = [[UILabel alloc] initWithFrame:labelFrame];
        folderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        folderLabel.userInteractionEnabled = YES;
        folderLabel.backgroundColor = self.labelBackgroundColor;
        folderLabel.textColor = self.labelTextColor;
        folderLabel.textAlignment = NSTextAlignmentCenter;
        folderLabel.font = [UIFont boldSystemFontOfSize:20];
        folderLabel.text = mediaFolder.name;
        folderLabel.tag = mediaFolder.mediaFolderId;
        folderLabel.isAccessibilityElement = NO;
        [self addSubview:folderLabel];
        [self.labels addObject:folderLabel];
        
        UIButton *folderButton = [UIButton buttonWithType:UIButtonTypeCustom];
        folderButton.frame = buttonFrame;
        folderButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        folderButton.accessibilityLabel = folderLabel.text;
        [folderButton addTarget:self action:@selector(selectFolder:) forControlEvents:UIControlEventTouchUpInside];
        [folderLabel addSubview:folderButton];
        folderButton.isAccessibilityElement = self.isOpen;
    }
    
    NSUInteger index = [self indexOfMediaFolderId:self.selectedFolderId];
    if (index != NSNotFound) {
        self.selectedFolderLabel.text = mediaFolders[index].name;
    }
}

- (void)toggleDropdown:(id)sender {
    if (self.isOpen) {
        // Close it
        [UIView animateWithDuration:.25 animations:^{
            self.height -= self.sizeIncrease;
            if ([self.delegate respondsToSelector:@selector(folderDropdownMoveViewsY:)]) {
                [self.delegate folderDropdownMoveViewsY:-self.sizeIncrease];
            }
         } completion:^(BOOL finished) {
             if ([self.delegate respondsToSelector:@selector(folderDropdownViewsFinishedMoving)]) {
                 [self.delegate folderDropdownViewsFinishedMoving];
             }
         }];
        
        [CATransaction begin];
        [CATransaction setAnimationDuration:.25];
        self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
        [CATransaction commit];
    } else {
        // Open it
        [UIView animateWithDuration:.25 animations:^{
            self.height += self.sizeIncrease;
            if ([self.delegate respondsToSelector:@selector(folderDropdownMoveViewsY:)]) {
                [self.delegate folderDropdownMoveViewsY:self.sizeIncrease];
            }
        } completion:^(BOOL finished) {
            if ([self.delegate respondsToSelector:@selector(folderDropdownViewsFinishedMoving)]) {
                [self.delegate folderDropdownViewsFinishedMoving];
            }
        }];
                
        [CATransaction begin];
        [CATransaction setAnimationDuration:.25];
        self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * -60.0f, 0.0f, 0.0f, 1.0f);
        [CATransaction commit];
    }
    
    self.isOpen = !self.isOpen;
    
    // Remove accessibility when not visible
    for (UILabel *label in self.labels) {
        for (UIView *subview in label.subviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                subview.isAccessibilityElement = self.isOpen;
            }
        }
    }
    
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)closeDropdown {
    if (self.isOpen) {
        [self toggleDropdown:nil];
    }
}

- (void)closeDropdownFast {
    if (self.isOpen) {
        self.isOpen = NO;
        
        self.height -= self.sizeIncrease;
        if ([self.delegate respondsToSelector:@selector(folderDropdownMoveViewsY:)]) {
            [self.delegate folderDropdownMoveViewsY:-self.sizeIncrease];
        }
        
        self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
        
        if ([self.delegate respondsToSelector:@selector(folderDropdownViewsFinishedMoving)]) {
            [self.delegate folderDropdownViewsFinishedMoving];
        }
    }
}

- (void)selectFolder:(id)sender {
    UIButton *button = (UIButton *)sender;
    UILabel  *label  = (UILabel *)button.superview;
    NSUInteger index = [self indexOfMediaFolderId:label.tag];
    if (index == NSNotFound) {
        return;
    }
    
    //DLog(@"Folder selected: %@ -- %i", label.text, label.tag);
    
    self.selectedFolderId = label.tag;
    self.selectedFolderLabel.text = self.mediaFolders[index].name;
    self.dropdownButton.accessibilityLabel = self.selectedFolderLabel.text;
    //[self toggleDropdown:nil];
    [self closeDropdownFast];
    
    // Call the delegate method
    if ([self.delegate respondsToSelector:@selector(folderDropdownSelectFolder:)]) {
        [self.delegate folderDropdownSelectFolder:self.selectedFolderId];
    }
}

- (void)selectFolderWithId:(NSInteger)folderId {
    NSUInteger index = [self indexOfMediaFolderId:folderId];
    if (index == NSNotFound) {
        return;
    }
    
    self.selectedFolderId = folderId;
    self.selectedFolderLabel.text = self.mediaFolders[index].name;
    self.dropdownButton.accessibilityLabel = self.selectedFolderLabel.text;
}

- (void)updateFolders {
    DropdownFolderLoader *loader = [[DropdownFolderLoader alloc] init];
    __weak DropdownFolderLoader *weakLoader = loader;
    loader.callback = ^(BOOL success, NSError * _Nullable error) {
        if (success) {
            self.mediaFolders = weakLoader.mediaFolders;
            [Store.shared addWithMediaFolders:self.mediaFolders];
        } else {
            // TODO: Handle error
            // failed.  how to report this to the user?
            DDLogError(@"[FolderDropdownControl] failed to update folders: %@", error.localizedDescription);
        }
    };
    [loader startLoad];
}

- (BOOL)hasMultipleMediaFolders {
    // There will always be "All Media Folders" and at least one folder, so just check if there are more than 2 items in the array
    return self.mediaFolders.count > 2;
}

@end
