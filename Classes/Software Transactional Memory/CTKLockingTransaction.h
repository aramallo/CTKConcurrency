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
@class CTKLockingTransactionInfo;
@class CTKReference;

// Exceptions and Errors

extern NSString * const CTKTransactionTimeoutExceptionName;
extern NSString * const CTKTransactionRetryExceptionName;
extern NSString * const CTKTransactionErrorDomain;

enum {
	CTKTransactionInitializationError = 1000,
	CTKTransactionRetryError = 1001,
	CTKTransactionRetryLimitError = 1002
};


@interface CTKTransactionRetryException : NSException {}
@end

#pragma mark -

/*
 Corresponds to Clojure's LockingTransaction class.
 */

@interface CTKLockingTransaction : NSObject {
	@private
	CTKLockingTransactionInfo *info;
	NSUInteger readPoint;
	NSUInteger startPoint;
	NSUInteger startTime;
	NSMapTable *vals; // Holds an array of in-transaction values for references
	NSMutableSet *sets; // 
	NSMapTable *commutes;
	NSUInteger retryLimit;
	NSMutableSet *ensures;
	//NSMutableArray *actions;

}

@property (readonly, assign, nonatomic) BOOL isRunning;
@property (readwrite, assign, nonatomic) NSUInteger retryLimit;

#pragma mark Class methods

/**
 * \return the current thread's transaction or nil if there if one does not exists.
 */
+ (CTKLockingTransaction *) runningTransaction;

/**
 * \return the current thread's transaction, creating a new one if one does not exist.
 */
+ (CTKLockingTransaction *) transaction;

/**
 * \return YES if there is a transaction associated with the current thread.
 */
+ (BOOL) isRunning;

/**
 * \brief Performs the block passed as an argument in the current thread's transaction, creating a new transaction if one does not exist.
 */
+ (id) performBlock:(id (^)(void))aBlock error:(NSError **)error;

+ (id) performBlock:(id (^)(void))aBlock onError:(id (^)(NSError *))onErrorBlock;

/**
 * \brief This method executes begin on the current thread's transaction
 */
+ (void) begin;

/**
 * \brief This method executes commit on the current thread's transaction
 */
+ (BOOL) commit:(NSError **)error;

/**
 * \brief This method executes abort on the current thread's transaction
 */
+ (void) abort;

#pragma mark Operations

- (id) performBlock:(id (^)(void))aBlock error:(NSError **)error;

- (id) performBlock:(id (^)(void))aBlock onError:(id (^)(NSError *))anotherBlock;

//- (id) performBlock:(id (^)(void))aBlock error:(NSError **)error timeout:(NSUInteger)msecs;

/**
* \attention It is safe to call this method multiple times before committing
*/
- (void) begin;

- (BOOL) commit:(NSError **)error;

- (void) abort;

#pragma mark Operations with References

/**
 * \return The most recent value
 * \throws CTKTransactionRetryException
*/
- (id) lockReference:(CTKReference *)aRef;

/**
 * \brief Prevents other txns from modifying the reference. Must be called inside a transaction.
 * \detail The calling transaction can modify the reference unless another transaction has also called ensure on it.
 * This method is handy when one wants to modify a reference that depends on the value of another reference that will not modified (a constraint).
 * \throws CTKTransactionRetryException
 */
- (void) ensureReference:(CTKReference *)aRef;

/**
 * \throws CTKTransactionRetryException
 */
- (id) valueForReference:(CTKReference *)aRef;

/**
 * \throws CTKTransactionRetryException
 */
- (id) setValue:(id)aValue forReference:(CTKReference *)aRef;

/**
 * \throws CTKTransactionRetryException
 */
- (id) commuteReference:(CTKReference *)aRef block:(id (^)(id))aBlock;


@end


