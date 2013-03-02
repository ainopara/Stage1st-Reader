//
//  UIControl+BlockWrapper.m
//  GSStaticTableViewController
//
//  Created by Suen Gabriel on 1/27/13.
//  Copyright (c) 2013 One Bit Army. All rights reserved.
//

#import "UIControl+BlockWrapper.h"
#import <objc/runtime.h>

@interface UIControlEventWrapper : NSObject

@property (nonatomic, assign) UIControlEvents controlEvent;
@property (nonatomic, copy) void (^eventHandler) (id sender, UIEvent *event);

- (void)sender:(id)sender forEvent:(UIEvent *)event;

@end

@implementation UIControlEventWrapper

- (void)sender:(id)sender forEvent:(UIEvent *)event
{
    if (self.eventHandler) {
        self.eventHandler(sender, event);
    }
}

@end

@implementation UIControl (BlockWrapper)

static char eventWrapperKey;

- (NSMutableArray *)eventWrappers
{
    NSMutableArray *eventWrappers = objc_getAssociatedObject(self, &eventWrapperKey);
    if (!eventWrappers) {
        eventWrappers = [NSMutableArray array];
        objc_setAssociatedObject(self, &eventWrapperKey, eventWrappers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return eventWrappers;
}

- (void)addEventHandler:(void (^)(id, UIEvent *))handler forControlEvent:(UIControlEvents)controlEvent
{
    UIControlEventWrapper *wrapper = [[UIControlEventWrapper alloc] init];
    wrapper.eventHandler = handler;
    wrapper.controlEvent = controlEvent;
    [self addTarget:wrapper action:@selector(sender:forEvent:) forControlEvents:controlEvent];
    [self.eventWrappers addObject:wrapper];
}

- (void)removeEventHandlerForControlEvent:(UIControlEvents)controlEvent
{
    __block typeof(self) myself = self;
    [self.eventWrappers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (((UIControlEventWrapper *)obj).controlEvent == controlEvent) {
            [myself.eventWrappers removeObject:obj];
        }
    }];
}


@end
