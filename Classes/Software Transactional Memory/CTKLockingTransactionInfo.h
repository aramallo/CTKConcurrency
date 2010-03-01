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

typedef enum {
	CTKTransactionStatusRunning = 0,
	CTKTransactionStatusCommitting = 1,
	CTKTransactionStatusRetry = 2,
	CTKTransactionStatusKilled = 3,
	CTKTransactionStatusCommitted = 4
} CTKTransactionStatus;

/*
 Corresponds to Clojure's LockingTransaction.Info inner class
 */
@interface CTKLockingTransactionInfo : NSObject {
	@private
	NSUInteger startPoint;
	NSCondition *condition;
	volatile int64_t conditionCounter;
	volatile int64_t status;
}

@property (readwrite, assign) NSUInteger startPoint;
@property (readonly, assign) BOOL isRunning;
@property (readwrite, assign) volatile int64_t status;


+ (id) infoWithStatus:(CTKTransactionStatus)aStatus startPoint:(NSUInteger)aStartPoint;

- (id) initWithStatus:(CTKTransactionStatus)aStatus startPoint:(NSUInteger)aStartPoint;

- (BOOL) compareStatus:(CTKTransactionStatus)expectedStatus setStatus:(CTKTransactionStatus)updatedStatus;

- (BOOL) waitNanos:(NSUInteger)nanos;

- (void) broadcast;

@end
