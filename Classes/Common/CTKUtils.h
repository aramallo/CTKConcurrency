//
//  QLUtils.h
//  PersistentData
//
//  Created by aramallo on 29/11/2009.
//  Copyright 2009 Alejandro M. Ramallo. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CTKUtils : NSObject {

}

- (BOOL) isObject:(id)anObject equivalentToObject:(id)anotherObject;

+ (NSUInteger) currentTimeInMillis;

+ (NSUInteger) currentTimeInNanos;

+ (NSUInteger) currentTimeInSecs;

@end
