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

#import <Cocoa/Cocoa.h>

/*
 This is a circular coubly-linked list.
 In order to avoid retain cycles we have a weak link to next. 
 Corresponds to Clojures' TVal class
 */
@interface CTKLockingTransactionValue : NSObject
{
	@private
	NSUInteger point;
	NSUInteger msecs;
	id value;
	CTKLockingTransactionValue *prior;
	CTKLockingTransactionValue *next;
}

@property (readwrite, assign) NSUInteger point;
@property (readwrite, assign) NSUInteger msecs;
@property (readwrite, retain) id value;
@property (readwrite, retain) CTKLockingTransactionValue *prior; 
@property (readwrite, assign) CTKLockingTransactionValue *next;

#pragma mark Class methods

+ (id) transactionValueWithValue:(id)aValue 
						   point:(NSUInteger)aPoint 
						   msecs:(NSUInteger)timeInMillis 
						   prior:(CTKLockingTransactionValue *)aPriorValue;

+ (id) transactionValueWithValue:(id)aValue point:(NSUInteger)aPoint msecs:(NSUInteger)timeInMillis;

@end
