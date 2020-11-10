//
//  IntroViewController.h
//  iSub
//
//  Created by Ben Baron on 1/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//



@interface IntroViewController : UIViewController 

@property (nonatomic, strong) IBOutlet UIButton *introVideo;
@property (nonatomic, strong) IBOutlet UIButton *testServer;
@property (nonatomic, strong) IBOutlet UIButton *ownServer;
@property (nonatomic, strong) IBOutlet UIImageView *sunkenLogo;

- (IBAction)buttonPress:(id)sender;

@end
