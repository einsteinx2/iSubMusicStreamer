//
//  UITableViewCell+TableView.m
//  EX2Kit
//
//  Created by Benjamin Baron on 12/7/14.
//
//

#import "UITableViewCell+TableView.h"

@implementation UITableViewCell (TableView)

// Recurse through superviews to find the table view. In iOS <7, the direct superview
// is the table view. In iOS 7+ there's a wrapper view in between. This may change even
// more in the future.
- (UITableView *)tableView
{
    UIView *superview = self.superview;
    while (superview)
    {
        if ([superview isKindOfClass:[UITableView class]])
        {
            return (UITableView *)superview;
        }
        
        superview = superview.superview;
    }
    
    return nil;
}

@end
