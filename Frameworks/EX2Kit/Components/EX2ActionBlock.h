//
//  EX2ActionBlock.h
//  EX2Kit
//
//  Created by Benjamin Baron on 5/23/13.
//
//

#import "EX2Action.h"

typedef enum
{
    EX2ActionBlockRunType_Sync, // Main thread, blocking
    EX2ActionBlockRunType_Async, // Main thread, non-blocking
    EX2ActionBlockRunType_Background // Background thread, non-blocking
} EX2ActionBlockRunType;

@interface EX2ActionBlock : NSObject <EX2Action>

@property (copy) void(^actionBlock)(void);

@property EX2ActionBlockRunType runType;

// EX2Action protocol
@property (weak) EX2ActionQueue *actionQueue;
@property EX2ActionState actionState;
- (void)runAction;

+ (id)block:(void(^)(void))actionBlock;
- (id)initWithActionBlock:(void(^)(void))actionBlock;

@end
