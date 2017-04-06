//
//  FolderDropdownControl.m
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownControl.h"
#import <QuartzCore/QuartzCore.h>

@interface FolderDropdownControl ()
{
    __strong NSDictionary *_folders;
}
@end

@implementation FolderDropdownControl

- (id)initWithFrame:(CGRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		_selectedFolderId = @-1;
		_folders = [SUSRootFoldersDAO folderDropdownFolders];
		_labels = [[NSMutableArray alloc] init];
		_isOpen = NO;
		_borderColor = ISMSHeaderTextColor;
		_textColor   = ISMSHeaderTextColor;
		_lightColor  = [UIColor whiteColor];
		_darkColor   = [UIColor whiteColor];
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.userInteractionEnabled = YES;
		self.backgroundColor = [UIColor clearColor];
		self.layer.borderColor = _borderColor.CGColor;
		self.layer.borderWidth = 2.0;
		self.layer.cornerRadius = 8;
		self.layer.masksToBounds = YES;
		
		_selectedFolderLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, self.frame.size.width - 10, 30)];
		_selectedFolderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_selectedFolderLabel.userInteractionEnabled = YES;
		_selectedFolderLabel.backgroundColor = [UIColor clearColor];
		_selectedFolderLabel.textColor = _borderColor;
		_selectedFolderLabel.textAlignment = NSTextAlignmentCenter;
		_selectedFolderLabel.font = ISMSBoldFont(20);
		_selectedFolderLabel.text = @"All Folders";
		[self addSubview:_selectedFolderLabel];
		
		UIView *arrowImageView = [[UIView alloc] initWithFrame:CGRectMake(193, 7, 18, 18)];
		arrowImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self addSubview:arrowImageView];
		
		_arrowImage = [[CALayer alloc] init];
		_arrowImage.frame = CGRectMake(0, 0, 18, 18);
		_arrowImage.contentsGravity = kCAGravityResizeAspect;
		_arrowImage.contents = (id)[UIImage imageNamed:@"folder-dropdown-arrow.png"].CGImage;
		[[arrowImageView layer] addSublayer:_arrowImage];
		
		_dropdownButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 220, 30)];
		_dropdownButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[_dropdownButton addTarget:self action:@selector(toggleDropdown:) forControlEvents:UIControlEventTouchUpInside];
        _dropdownButton.accessibilityLabel = _selectedFolderLabel.text;
        _dropdownButton.accessibilityHint = @"Switches folders";
		[self addSubview:_dropdownButton];
		
		[self updateFolders];
		
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFolders) name:ISMSNotification_ServerCheckPassed object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched object:nil];
    }
    return self;
}

/*- (void)serverSwitched
{
	[self selectFolderWithId:@-1];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
}*/

NSInteger folderSort2(id keyVal1, id keyVal2, void *context)
{
    NSString *folder1 = [(NSArray*)keyVal1 objectAtIndexSafe:1];
	NSString *folder2 = [(NSArray*)keyVal2 objectAtIndexSafe:1];
	return [folder1 caseInsensitiveCompare:folder2];
}

- (NSDictionary *)folders
{
	return _folders;
}

- (void)setFolders:(NSDictionary *)namesAndIds
{
	// Set the property
	_folders = namesAndIds;
	
	// Remove old labels
	for (UILabel *label in self.labels)
	{
		[label removeFromSuperview];
	}
	[self.labels removeAllObjects];
	
	self.sizeIncrease = _folders.count * 30.0f;
	
	NSMutableArray *sortedValues = [NSMutableArray arrayWithCapacity:_folders.count];
	for (NSNumber *key in _folders.allKeys)
	{
		if ([key intValue] != -1)
		{
			NSArray *keyValuePair = @[ key, _folders[key] ];
			[sortedValues addObject:keyValuePair];
		}
	}
	
	/*// Sort by folder name - iOS 4.0+ only
	 [sortedValues sortUsingComparator: ^NSComparisonResult(id keyVal1, id keyVal2) {
	 NSString *folder1 = [(NSArray*)keyVal1 objectAtIndexSafe:1];
	 NSString *folder2 = [(NSArray*)keyVal2 objectAtIndexSafe:1];
	 return [folder1 caseInsensitiveCompare:folder2];
	 }];*/
	
	// Sort by folder name
	[sortedValues sortUsingFunction:folderSort2 context:NULL];
	
	// Add All Folders again
	NSArray *keyValuePair = @[@"-1", @"All Folders"];
	[sortedValues insertObject:keyValuePair atIndex:0];
	
	//DLog(@"keys: %@", [folders allKeys]);
	//NSMutableArray *keys = [NSMutableArray arrayWithArray:[[folders allKeys] sortedArrayUsingSelector:@selector(compare:)]];
	//DLog(@"sorted keys: %@", keys);
	
	// Process the names and create the labels/buttons
	for (int i = 0; i < [sortedValues count]; i++)
	{
		NSString *folder   = [[sortedValues objectAtIndexSafe:i] objectAtIndexSafe:1];
		NSUInteger tag     = [[[sortedValues objectAtIndexSafe:i] objectAtIndexSafe:0] intValue];
		CGRect labelFrame  = CGRectMake(0, (i + 1) * 30, self.frame.size.width, 30);
		CGRect buttonFrame = CGRectMake(0, 0, labelFrame.size.width, labelFrame.size.height);
		
		UILabel *folderLabel = [[UILabel alloc] initWithFrame:labelFrame];
		folderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		folderLabel.userInteractionEnabled = YES;
		//folderLabel.alpha = 0.0;
		if (i % 2 == 0)
			folderLabel.backgroundColor = self.lightColor;
		else
			folderLabel.backgroundColor = self.darkColor;
		folderLabel.textColor = self.textColor;
		folderLabel.textAlignment = NSTextAlignmentCenter;
		folderLabel.font = ISMSBoldFont(20);
		folderLabel.text = folder;
		folderLabel.tag = tag;
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
}

- (void)toggleDropdown:(id)sender
{
	if (self.isOpen)
	{
        // Close it
        [UIView animateWithDuration:.25 animations:^
         {
             self.height -= self.sizeIncrease;
             [self.delegate folderDropdownMoveViewsY:-self.sizeIncrease];
         }
        completion:^(BOOL finished)
         {
             [self.delegate folderDropdownViewsFinishedMoving];
         }];
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:.25];
		self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
    }
    else
    {
        // Open it
		[UIView animateWithDuration:.25 animations:^
		{
			self.height += self.sizeIncrease;
			[self.delegate folderDropdownMoveViewsY:self.sizeIncrease];
		} 
		completion:^(BOOL finished)
		{
			[self.delegate folderDropdownViewsFinishedMoving];
		}];
				
		[CATransaction begin];
		[CATransaction setAnimationDuration:.25];
		self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * -60.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	
	self.isOpen = !self.isOpen;
    
    // Remove accessibility when not visible
    for (UILabel *label in self.labels)
    {
        for (UIView *subview in label.subviews)
        {
            if ([subview isKindOfClass:[UIButton class]])
            {
                subview.isAccessibilityElement = self.isOpen;
            }
        }
    }
    
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)closeDropdown
{
	if (self.isOpen)
	{
		[self toggleDropdown:nil];
	}
}

- (void)closeDropdownFast
{
	if (self.isOpen)
	{
		self.isOpen = NO;
		
		self.height -= self.sizeIncrease;
		[self.delegate folderDropdownMoveViewsY:-self.sizeIncrease];
		
		self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
		
		[self.delegate folderDropdownViewsFinishedMoving];
	}
}

- (void)selectFolder:(id)sender
{
	UIButton *button = (UIButton *)sender;
	UILabel  *label  = (UILabel *)button.superview;
	
	//DLog(@"Folder selected: %@ -- %i", label.text, label.tag);
	
	self.selectedFolderId = @(label.tag);
	self.selectedFolderLabel.text = [self.folders objectForKey:self.selectedFolderId];
    self.dropdownButton.accessibilityLabel = self.selectedFolderLabel.text;
	//[self toggleDropdown:nil];
	[self closeDropdownFast];
	
	// Call the delegate method
	[self.delegate folderDropdownSelectFolder:self.selectedFolderId];	
}

- (void)selectFolderWithId:(NSNumber *)folderId
{
	self.selectedFolderId = folderId;
	self.selectedFolderLabel.text = [self.folders objectForKey:self.selectedFolderId];
    self.dropdownButton.accessibilityLabel = self.selectedFolderLabel.text;
}

- (void)updateFolders
{    
	//[self.connection cancel];
	//self.connection = nil;
    
    ISMSDropdownFolderLoader *loader = [ISMSDropdownFolderLoader loaderWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *loader)
    {
        ISMSDropdownFolderLoader *theLoader = (ISMSDropdownFolderLoader *)loader;
        if (success)
        {
            self.folders = theLoader.updatedfolders;
            ALog(@"%@", self.folders);
            ALog(@"%@", theLoader.updatedfolders);
            [SUSRootFoldersDAO setFolderDropdownFolders:self.folders];
        }
        else
        {
            // failed.  how to report this to the user?
        }
    }];
    [loader startLoad];
    
    // Save the default
    [SUSRootFoldersDAO setFolderDropdownFolders:self.folders];
}

@end
