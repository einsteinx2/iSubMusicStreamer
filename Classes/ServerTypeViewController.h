//
//  ServerTypeViewController.h
//  iSub
//
//  Created by Ben Baron on 1/13/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

@interface ServerTypeViewController : UIViewController 

@property (nonatomic, strong) IBOutlet UIButton *subsonicButton;
@property (nonatomic, strong) IBOutlet UIButton *ubuntuButton;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) UIViewController *serverEditViewController;

@property (nonatomic, strong) IBOutlet UIButton *pmsButton;

- (IBAction) buttonAction:(id)sender;

@end
