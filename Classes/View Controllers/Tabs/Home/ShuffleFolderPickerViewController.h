//
//  ShuffleFolderPickerViewController.h
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "FolderPickerDialog.h"
#import "NewHomeViewController.h"

@interface ShuffleFolderPickerViewController : CustomUITableViewController 

@property (strong) NSMutableArray *sortedFolders;
@property (weak) FolderPickerDialog *myDialog;

@end
