/*
 * Author: Alejandro M. Ramallo
 * Copyright (c) Alejandro M. Ramallo. All rights reserved.
 *
 * The use and distribution terms for this software are covered by the
 * Eclipse Public License 1.0 <http://opensource.org/licenses/eclipse-1.0.php>
 * which can be found in the file epl-v10.html at the root of this distribution.
 * By using this software in any fashion, you are agreeing to be bound by
 * the terms of this license.
 * You must not remove this notice, or any other, from this software.
 *
 * The work contained herein is derived from and in many places is a direct translation 
 * of Clojure distribution <http://clojure.org/>. That work contains the following notice:
 *
 *   -----------------------------------------------------------------------------
 *   Clojure
 *   Copyright (c) Rich Hickey. All rights reserved.
 *   The use and distribution terms for this software are covered by the
 *   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
 *   which can be found in the file epl-v10.html at the root of this distribution.
 *   By using this software in any fashion, you are agreeing to be bound by
 *   the terms of this license.
 *   You must not remove this notice, or any other, from this software.
 *   -----------------------------------------------------------------------------
 */


#import "CTKLockingTransactionInfo.h"
#include <libkern/OSAtomic.h>
#include <dispatch/dispatch.h>

@interface CTKLockingTransactionInfo ()
@property (readwrite, assign) volatile int64_t conditionCounter;
@end


@implementation CTKLockingTransactionInfo

#pragma mark Class methods

+ (id) infoWithStatus:(CTKTransactionStatus)aStatus startPoint:(NSUInteger)aStartPoint
{
	return [[[self alloc] initWithStatus:aStatus startPoint:aStartPoint] autorelease];
}

#pragma mark Initializers and dealloc

- (id) initWithStatus:(CTKTransactionStatus)aStatus startPoint:(NSUInteger)aStartPoint
{
	self = [super init];
	
	if (self != nil) {
		status = aStatus;
		self.startPoint = aStartPoint;
		condition = [NSCondition new];
		self.conditionCounter = 1;		
	}
	
	return self;
}

- (void) dealloc
{
	[condition release];
	[super dealloc];
}

#pragma mark Operations

- (BOOL) compareStatus:(CTKTransactionStatus)expectedStatus setStatus:(CTKTransactionStatus)updatedStatus
{
	return OSAtomicCompareAndSwap64Barrier(expectedStatus, updatedStatus, &status);  
}


- (BOOL) waitNanos:(NSUInteger)nanos
{	
	if (self.conditionCounter < 1)
		return YES;
	
	[condition lock];	
	BOOL result = [condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:(nanos / 1000000)]];
	[condition unlock];
	
	return result;
}

- (void) broadcast
{
	OSAtomicDecrement64Barrier(&conditionCounter);
	[condition lock];
	[condition broadcast];	
	[condition unlock];
}

#pragma mark Overriden Properties

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ startPoint:%U status:%U", [super description], self.startPoint, self.status];
}


#pragma mark Properties

@synthesize status, startPoint, conditionCounter;
@dynamic isRunning;

- (BOOL) isRunning
{		
	NSUInteger theStatus = self.status;
	return (theStatus == CTKTransactionStatusRunning || theStatus == CTKTransactionStatusCommitting);
}


@end
