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

#import "CTKLockingTransactionValue.h"


@implementation CTKLockingTransactionValue


#pragma mark Class methods

+ (id) transactionValueWithValue:(id)aValue point:(NSUInteger)aPoint msecs:(NSUInteger)timeInMillis prior:(CTKLockingTransactionValue *)aPriorValue
{
	CTKLockingTransactionValue *instance = [CTKLockingTransactionValue new];
	instance.value = aValue;
	instance.point = aPoint;
	instance.msecs = timeInMillis;
	instance.prior = aPriorValue;
	instance.next = aPriorValue.next;
	instance.prior.next = instance;
	instance.next.prior = instance;
	
	return [instance autorelease];
}


+ (id) transactionValueWithValue:(id)aValue point:(NSUInteger)aPoint msecs:(NSUInteger)timeInMillis
{
	CTKLockingTransactionValue *instance = [CTKLockingTransactionValue new];
	instance.value = aValue;
	instance.point = aPoint;
	instance.msecs = timeInMillis;
	instance.prior = instance;
	instance.next = instance;
	
	return [instance autorelease];
}

#pragma mark Initializers and dealloc

- (void) dealloc
{
	[value release];
	[prior release];
	
	[super dealloc];
}

#pragma mark Properties

@synthesize value, prior, next, point, msecs;


@end
