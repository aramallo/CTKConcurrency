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
#import "CTKLockingTransactionValue.h"
@class CTKLockingTransactionInfo;


/*
 * \class CTKReference CTKReference.h
 * \defgroup STM Software Transactional Memory
 * \author Alejandro M. Ramallo
 * \brief Corresponds to Clojure's Ref class, its superclasses and adopted interfaces.
 * \details CTKReference objects represent a single value that is shared across threads. 
 * Any writes must be performed inside an a transaction. 
 * While reads are not required to be performed inside a transaction, doing so provides access to a consistent snapshot of the set of references accessed inside the transaction.
 * The in-transaction values of references are maintained by each txn, as such they are only visible to code running in the transaction. Those values will be committed at the end of the transaction if successful, otherwise all values are cleared (after each transaction retry attempt).
 * A CTKReference maintains its committed values in a circular doubly-linked list rpresented by CTKLockingTransactionValue instance stored in the tvals property. Each CTKLockingTransactionValue has a commit timestamp represented by its point property.
 * \par Changing a reference:
 * There a three ways of changing a CTKReference's value, an all must be perfomed inside a transaction:
 * - set
 * - alter
 * - commute
 * \example
 * \code
 * MyObjectClass *myObject = ...; // here you initialize your object which ideally should be persistent
 * CTKReference *ref = [CTKReference referenceWithValue:myObject];
 * \endcode
 * Alternatively you can use the reference method of NSObject
 * \code CTKReference *ref = [myObject reference];
 * In order to change the value of reference we need to use a transaction:
 * \code
 * CTKReference *ref; // assuming we have a reference already
 * MyObjectClass *myOtherObject = ...;
 * [CTKLockingTransaction begin]; // this will create a transaction if the current thread does not have one, and begin.
 * MyObjectClass *myObject = [ref dereference]; // to ensure I get the last commited value as other threads are working with the ref
 * [ref setValue:myOtherObject];
 * BOOL done = [CTKLockingtransaction commit:&error];
 * if(!done)
 *{ 
 * // the ref has not been set to the new value
 * // doSomething with error
 *} else {
 * // the ref now has myOtherObject as its committed value
 *}
 * \endcode
 */

@interface CTKReference : NSObject {
	@private
	NSUInteger identifier;
	NSUInteger minHistory;
	NSUInteger maxHistory;
	CTKLockingTransactionValue *tvals;
	CTKLockingTransactionInfo *txnInfo;
	volatile int64_t faults;
	pthread_rwlock_t rwlock; /**< Use to read all and to write txnInfo and tvals to this reference*/
}

/**
 * \return the unique identifier for this reference
 * 
 * The unique identifier consists of an sequential integer obtained on instance initialization.
 */
@property (readonly, assign) NSUInteger identifier;
/**
 \return Returns whether this reference has any value associated with it.
 */
@property (readonly, assign) BOOL isBound;
/**
 * \return Returns the commit history count for this reference.
 * 
 * It is safe to call this property in a multi-threaded environment as the reference will obtain a read lock in order to return its historyCount.
 */
@property (readonly, assign) NSUInteger historyCount;
/**
 * \return Returns the last committed value for this reference.
 */
@property (readwrite, retain) CTKLockingTransactionValue *tvals;
/**
 * An info object marks this reference as having an in-transaction value for a given transaction.
 * \attention It is an alternative to having this reference locked for the duration of a transaction.
 */
@property (readwrite, retain) CTKLockingTransactionInfo *txnInfo;
/**
 * \return the minimum number of commit values the reference should keep
 * \see CTKLockingTransactionValue class to understand how the reference keeps its history of committed values.
 */
@property (readwrite, assign) NSUInteger minHistory;
/**
 * \return the maximum number of commit values the reference should keep
 * \see CTKLockingTransactionValue class to understand how the reference keeps its history of committed values.
*/
@property (readwrite, assign) NSUInteger maxHistory;
/**
 * \return Returns the last known value for this reference. 
 * \attention It is safe to call this property in a multi-threaded environment as the reference will obtain a read lock in order to return its current value.
 */
@property (readwrite, retain) id value;
/**
 * \return Returns the number of faults that occurred for this reference
 * 
 * A fault occur when there is an attempt to read a CTKReference in a txn and there is no in-txn value in the txn and
 * all values in the history list for the Ref were committed after the txn started. Thus it means the reference has not been
 * modified in the transaction. Faults cause teh transaction to stop with a retry status and the history chain to grow until it
 * reaches the maxHistory count.
 */
@property (readwrite, assign) volatile int64_t faults;

#pragma mark Class methods
/**
 * \return A new CTKReference object holding the given value.
 * \param aValue  the value this reference is referencing.
 *
 * \brief Creates and returns an CTKReference object holding the given value.
 * \detail This method invoques the instance method -initWithValue:
 */
+ (id) referenceWithValue:(id)aValue;

#pragma mark Initialization
/**
 * \return A new CTKReference object holding the given value.
 * \param aValue  the value this reference is referencing.
 * \brief Creates and returns an CTKReference object holding the given value.
 * \detail This method invoques the instance method -initWithTransactionValue: creating a CTKLockingTransactionValue with the given value.
 */
- (id) initWithValue:(id)aValue;
/**
 * \return A new CTKReference object holding the given value.
 * \param aTval The number with which to compare the receiver. This value must not be nil. If the value is nil, the behavior is undefined.
 * \brief Creates and returns an CTKReference object holding the given value.
 */
- (id) initWithTransactionValue:(CTKLockingTransactionValue *)aTval;

#pragma mark Equality
/**
 * \return Returns an NSComparisonResult value that indicates whether the receiver is greater than, equal to, or less than a given number.
 * \param anotherObject  an instance of CTKLockingTransactionValue this reference is referencing.
 * \brief Compares the identifier property of the the receiver with the one of anotherObject.
 */
- (NSComparisonResult)compare:(CTKReference *)anotherObject;


#pragma mark Operations

/**
* \return The current in-transaction value for this reference or the last known commited value for the reference if there is no running transaction.
*/
- (id) dereference;

/**
 * \details This methods calls the current transaction's ensureReference: with self as a value.
 * \throws CTKTransactionRetryException
 */
- (void) touch;

/**
 * \throws CTKTransactionRetryException
 */
- (id) alterWithBlock:(id (^)(id))aBlock;

/**
 * \throws CTKTransactionRetryException
 */
- (id) commuteWithBlock:(id (^)(id))aBlock;

- (void) trimHistory;

#pragma mark Private Operations

/**
 * \warning You should not call this method directly.
 */
- (BOOL) readLock;

/**
 * \warning You should not call this method directly.
 */
- (BOOL) tryWriteLock;

/**
 * \warning You should not call this method directly.
 */
- (BOOL) unlock;

/**
 * \warning You should not call this method directly.
 */
- (void) incrementFaults;

/**
 * \warning You should not call this method directly.
 */
- (void) resetFaults;


@end


//////////////////////////////////////////////////////////////////////////
// Categories
//////////////////////////////////////////////////////////////////////////


@interface NSObject (CTKTransactionalMemoryAdditions)

/*!
    \brief This is a utility method to construct a reference from an object.
    \details Returns an instance of CTKReference by calling [[self alloc] initWithValue:aValue]
 	\return An instance of CTKReference with self as its value.
*/
- (CTKReference *) reference;

@end
