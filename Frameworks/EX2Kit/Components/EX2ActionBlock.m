//
//  EX2ActionBlock.m
//  EX2Kit
//
//  Created by Benjamin Baron on 5/23/13.
//
//

#import "EX2ActionBlock.h"

@implementation EX2ActionBlock

+ (id)block:(void(^)(void))actionBlock
{
    return [[EX2ActionBlock alloc] initWithActionBlock:actionBlock];
}

- (id)initWithActionBlock:(void(^)(void))actionBlock
{
    if ((self = [super init]))
    {
        _actionBlock = [actionBlock copy];
    }
    return self;
}

- (void)runAction
{
    if (!self.actionBlock)
    {
        [self.actionQueue actionFailed:self];
        return;
    }
    
    switch (self.runType)
    {
        case EX2ActionBlockRunType_Sync:
        {
            self.actionBlock();
            [self.actionQueue actionFinished:self];
            break;
        }
        case EX2ActionBlockRunType_Async:
        {
            [EX2Dispatch runInMainThreadAsync:^
             {
                 self.actionBlock();
                 [self.actionQueue actionFinished:self];
             }];
            break;
        }
        case EX2ActionBlockRunType_Background:
        {
            [EX2Dispatch runInBackgroundAsync:^
             {
                 self.actionBlock();
                 [self.actionQueue actionFinished:self];
             }];
            break;
        }
        default: break;
    }
}

- (BOOL)cancelAction
{
    // Do nothing, we can't cancel the blocks
    return NO;
}

@end
