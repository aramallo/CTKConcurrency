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

/*
 * For an explanation of how Clojure's STM works please refer to the following materials:
 * http://clojure.org/concurrent_programming
 * http://clojure.org/state
 * http://clojure.org/refs
 * http://java.ociweb.com/mark/stm/ by Mark Volkmann
 * http://java.ociweb.com/mark/stm/article.html by Mark Volkmann
 * "Programming Clojure" book by Stuart Halloway
 */

#import "CTKLockingTransaction.h"
#import "CTKLockingTransactionInfo.h"
#import "CTKReference.h"
#import "CTKUtils.h"
#import "CTKLockingTransactionInfo.h"
#import "CTKLockingTransactionValue.h"
#include <libkern/OSAtomic.h>
#include <pthread.h>

// GLOBALS 
static NSUInteger const CTK_RETRY_LIMIT = 10000; // Clojure specifies 10000
static NSUInteger const CTK_LOCK_WAIT_MSECS = 100; // Clojure specifies 100.
static NSUInteger const CTK_BARGE_WAIT_NANOS = 10 * 1000000; //  Clojure specifies 10 * 1000000
static pthread_key_t CTKThreadTransactionKey; // The key used to store the transaction in each pthread

NSString * const CTKTransactionTimeoutExceptionName = @"CTKTransactionTimeoutException";
NSString * const CTKTransactionRetryExceptionName = @"CTKTransactionRetryException";
NSString * const CTKTransactionErrorDomain = @"CTKTransactionErrorDomain";

/**
 * Total order on transactions.
 * Transactions will consume a point for init, for each retry, and on commit if writing.
 */
static volatile int64_t lastPoint;

// FUNCTIONS

void CTKPthreadTransactionDestructor(void *txn)
{
	[(CTKLockingTransaction *)txn release];
}

// EXCEPTIONS

@implementation CTKTransactionRetryException
@end

#pragma mark -

@interface CTKLockingTransaction ()

@property (readwrite, retain, nonatomic) CTKLockingTransactionInfo *info; // should be nonatomic since only this thread accesses it
@property (readwrite, retain, nonatomic) NSMapTable *vals;
@property (readwrite, retain, nonatomic) NSMutableSet *sets;
@property (readwrite, retain, nonatomic) NSMapTable *commutes;
@property (readwrite, assign, nonatomic) NSUInteger startPoint;
@property (readwrite, assign, nonatomic) NSUInteger startTime;
@property (readwrite, assign, nonatomic) NSUInteger readPoint;
@property (readwrite, retain, nonatomic) NSMutableSet *ensures;
@property (readwrite, assign, nonatomic) BOOL bargeTimeElapsed;
//@property (readwrite, retain, nonatomic) NSMutableArray *actions;

@end

#pragma mark -

@interface CTKLockingTransaction (Private)

#pragma mark Class methods
+ (CTKLockingTransaction *) private_threadTransaction;
+ (BOOL) private_setThreadTransaction:(CTKLockingTransaction *)txn error:(NSError **)error;
#pragma mark Initialization and dealloc
- (void) private_resetState;
#pragma mark Operations
- (BOOL) private_canBargeIntoTransactionWithInfo:(CTKLockingTransactionInfo *)refInfo;
- (BOOL) private_releaseReferenceIfEnsured:(CTKReference *)aRef;
- (void) private_blockAndBailWithInfo:(CTKLockingTransactionInfo *)refInfo;
- (void) private_stopWithStatus:(CTKTransactionStatus)aStatus;
#pragma mark Operations (Commit steps)
- (BOOL) private_lockAndPerformCommutes:(NSMutableArray **)lockedRefs;
- (BOOL) private_validateAndEnqueueNotifications;
- (void) private_processChanges;
#pragma mark Properties
- (void) private_acquireReadPoint;
- (NSUInteger) private_commitPoint;

@end

#pragma mark -

@implementation CTKLockingTransaction

#pragma mark Class methods

+ (void) initialize
{
	if (self == [CTKLockingTransaction class])
	{
		pthread_key_create(&CTKThreadTransactionKey, CTKPthreadTransactionDestructor);
	}
}

+ (CTKLockingTransaction *) runningTransaction
{
	CTKLockingTransaction *txn = [self private_threadTransaction];
	return (txn == nil || txn.info == nil) ? nil : txn;
}

+ (CTKLockingTransaction *) transaction
{
	CTKLockingTransaction *txn = [self private_threadTransaction];
	
	if (txn == nil)
	{
		NSError *error = nil;
		txn = [[CTKLockingTransaction new] autorelease];		
		
		if ([self private_setThreadTransaction:txn error:&error])
			[txn begin];
		
		else
			CTKErrorLog(@"%@", [error localizedDescription]);
		
	}
	
	return txn;
}

+ (CTKLockingTransaction *) private_threadTransaction
{
	CTKLockingTransaction *value = pthread_getspecific(CTKThreadTransactionKey);
	return (value != NULL) ? value : nil;
}

+ (BOOL) private_setThreadTransaction:(CTKLockingTransaction *)txn error:(NSError **)error
{
	NSInteger result = pthread_setspecific(CTKThreadTransactionKey, [txn retain]);
	
	if (result != 0)
	{
		NSString *reason = (result == EINVAL) 
		? NSLocalizedString(@"The key value is invalid", @"")
		: NSLocalizedString(@"Insufficient memory exists to associate the value with the key", @"");
		
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  reason, NSLocalizedDescriptionKey,
								  nil];
		
		if(error != NULL)
			*error = [NSError errorWithDomain:CTKTransactionErrorDomain
										 code:CTKTransactionInitializationError 
									 userInfo:userInfo];
	}
	
	return (result == 0);
}

+ (BOOL) isRunning
{
	return ([self runningTransaction] != nil);
}

+ (id) performBlock:(id (^)(void))aBlock error:(NSError **)error
{
	return [[CTKLockingTransaction transaction] performBlock:aBlock error:error];
}

+ (id) performBlock:(id (^)(void))aBlock onError:(id (^)(NSError *))anotherBlock
{
	return [[CTKLockingTransaction transaction] performBlock:aBlock onError:anotherBlock];
}

+ (void) begin
{
	[[CTKLockingTransaction transaction] begin];
}

+ (BOOL) commit:(NSError **)error
{
	return [[CTKLockingTransaction runningTransaction] commit:error];
}

+ (void) abort
{
	[[CTKLockingTransaction transaction] abort];
}

#pragma mark Initializers and dealloc

- (id) init
{
	self = [super init];
	
	if (self != nil) 
	{
		self.retryLimit = CTK_RETRY_LIMIT;
		self.info = nil;
		self.vals = [NSMapTable mapTableWithStrongToStrongObjects];
		self.sets = [NSMutableSet set];
		self.commutes = [NSMapTable mapTableWithStrongToStrongObjects];
		self.ensures = [NSMutableSet set];
		//self.actions = [NSMutableArray array];
	}
	
	return self;
}

- (void) private_resetState
{
	self.info = nil;
	self.vals = [NSMapTable mapTableWithStrongToStrongObjects];
	self.sets = [NSMutableSet set];
	self.commutes = [NSMapTable mapTableWithStrongToStrongObjects];
	self.ensures = [NSMutableSet set];
	//self.actions = [NSMutableArray array];
}

- (void) dealloc
{
	[info release];
	[vals release];
	[sets release];
	[commutes release];
	[ensures release];
	//[actions release]; // not implemented yet
	
	[super dealloc];
}

#pragma mark Operations

- (id) performBlock:(id (^)(void))aBlock onError:(id (^)(NSError *))anotherBlock
{
	NSError *error = nil;
	id (^onError)(NSError *) = [anotherBlock copy];		
	id result = [self performBlock:aBlock error:&error];
	
	if(result == nil && onError != nil)
		result = onError(error);
	
	[onError release];
	
	return result;
}

- (id) performBlock:(id (^)(void))aBlock error:(NSError **)error
{	
	NSParameterAssert(aBlock);
	BOOL done = NO;
	NSError *commitError = nil;
	NSError *savedError = nil;
	NSException *savedException = nil;
	id (^operation)(void) = [aBlock copy];
	id result = nil;
	NSUInteger retries = 0;
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	@try {
		
		for(retries; !done && retries < self.retryLimit; retries++) {
			done = NO;
			
			//CTKConditionalLog(retries == self.retryLimit / 2, @"Retries %U", retries);
			
			NSAutoreleasePool *innerPool = [NSAutoreleasePool new];
			
			@try {
				
				// We need to call begin each time since we might be recovering from a retry exception.
				[self begin];
				
				result = operation();
				[result retain];

				done = [self commit:&commitError];
				
				// We ignore CTKTransactionRetryError(s) so that we retry
				if (!done && [commitError code] != CTKTransactionRetryError)
				{
					savedError = [commitError retain];
					break;
				}
				
			}
			@catch (CTKTransactionRetryException *re){
				done = NO;
				/* This is an exception that occurred during the execution of the provided block
				 and not within the commit invocation, therefore we need to terminate the 
				 transaction, otherwise I will not be able to retry. 
				 We swallow CTKTransactionRetryException(s) to retry.
				 */				
				[self private_stopWithStatus:CTKTransactionStatusRetry];
			}
			@catch (NSException * e) {
				done = NO;
				savedException = [e retain];
				@throw savedException; // This will break the loop and jump into outer exception handler
			}
			@finally {	
				[innerPool drain];	
				[savedException autorelease];
			}
			
		}
	}
	@catch (NSException * e) {
		savedException = [e retain];
		@throw savedException;
	}
	@finally {
		
		[pool drain];
		[operation release];
		
		if(savedError != nil)
		{
			[savedError autorelease];
		}
		
		if(result != nil)
			[result autorelease];
		
		if (!done && error != nil)
		{
			NSMutableDictionary *userInfo = [NSMutableDictionary new];
			
			if (retries == self.retryLimit) 
			{
				NSString *description = [NSString stringWithFormat:@"Failed after %U retries", retries];
				
				[userInfo setObject:NSLocalizedString(description, @"") 
							 forKey:NSLocalizedDescriptionKey];
			}
			
			if (savedError != nil)
			{				
				[userInfo setObject:savedError forKey:NSUnderlyingErrorKey];
			}
			
			*error = [NSError errorWithDomain:CTKTransactionErrorDomain
										 code:CTKTransactionRetryLimitError
									 userInfo:userInfo];
			
			[userInfo release];
		}
		
		return result;
	}
	
}

- (void) begin
{
	if (self.info == nil)
	{
		[self private_acquireReadPoint];
		self.startPoint = self.readPoint;
		self.startTime = [CTKUtils currentTimeInNanos];
		self.info = [[[CTKLockingTransactionInfo alloc] 
					  initWithStatus:CTKTransactionStatusRunning startPoint:self.startPoint] autorelease];
	}
	
	else if (!self.info.isRunning)
	{		
		// We probably want to retry since we still have info assigned
		[self private_acquireReadPoint];
		self.info = [[[CTKLockingTransactionInfo alloc] initWithStatus:CTKTransactionStatusRunning startPoint:self.startPoint] autorelease];
	}
}

- (BOOL) commit:(NSError **)error
{	
	BOOL done = NO;
	NSMutableArray *lockedRefs = [NSMutableArray array];
	
	@try {
				
		if ([self.info compareStatus:CTKTransactionStatusRunning setStatus:CTKTransactionStatusCommitting]) 
		{
			// Other transactions will not be able to stop us now
						
			if(![self private_lockAndPerformCommutes:&lockedRefs])
			{
				return NO; // This will force a retry
			}
			
			// Acquire write locks for all refs modified in txn so there can be no readers
			for(CTKReference *ref in self.sets){
				
				if (![ref tryWriteLock])
				{
					return done; // This will force a retry
				}
				
				[lockedRefs addObject:ref];
				
			}
			
			if(![self private_validateAndEnqueueNotifications])
			{
				return done; // This will force a retry
			}
			
			/* 
			 * At this point, all values calculated, all refs to be written locked
			 * no more client code to be called
			 */
			[self private_processChanges];
			done = YES; 
			self.info.status = CTKTransactionStatusCommitted;
			
		}
		
	}
	@catch (CTKTransactionRetryException *re){
		done = NO;
		// We will return a CTKTransactionRetryError
	}
	@catch (NSException * e) {
		done = NO;
		CTKWarningLog(@"%@", e);
		@throw e;
	}
	@finally {
		
		// Unlock all refs and cleanup
		for(CTKReference *ref in lockedRefs){
			[ref unlock];
		}
		
		[lockedRefs removeAllObjects];
		lockedRefs = nil;
		
		// Unlock ensured
		for(CTKReference *ref in self.ensures){
			[ref unlock];
		}
		
		//[ensures removeAllObjects];		
		
		[self private_stopWithStatus:(done) ? CTKTransactionStatusCommitted : CTKTransactionStatusRetry];
		
		if (!done && error != nil)
			*error = [NSError errorWithDomain:CTKTransactionErrorDomain 
										 code:CTKTransactionRetryError
									 userInfo:nil];
		return done;
	}
	

}
- (BOOL) private_lockAndPerformCommutes:(NSMutableArray **)lockedRefs
{
	NSArray *orderedKeys = [[[self.commutes keyEnumerator] allObjects] sortedArrayUsingSelector:@selector(compare:)];
	
	for(CTKReference *ref in orderedKeys){
		
		if ([self.sets containsObject:ref])
			continue;
		
		BOOL wasEnsured = [self private_releaseReferenceIfEnsured:ref];
		
		if (![ref tryWriteLock])
		{				
			return NO; // This will force a retry
		}
		
		[*lockedRefs addObject:ref];
		
		if (wasEnsured && ref.tvals != nil && ref.tvals.point > self.readPoint)
		{
			return NO; // This will force a retry
		}
		
		CTKLockingTransactionInfo *refInfo = ref.txnInfo;
		
		if (refInfo != nil && refInfo != self.info && refInfo.isRunning)
		{
			if (![self private_canBargeIntoTransactionWithInfo:refInfo])
			{
				return NO; // This will force a retry
			}
			
		}
		
		id value = ref.tvals == nil ? nil : ref.tvals.value;
		[self.vals setObject:value forKey:ref];
		
		for(id (^operation)(id) in (NSArray *)[self.commutes objectForKey:ref]){
			id value = [self.vals objectForKey:ref];
			id result = operation(value);
			[self.vals setObject:result forKey:ref];
		}
	}
	
	return YES;
}

- (BOOL) private_validateAndEnqueueNotifications
{
	return YES; // Not implemented yet
}

- (void) private_processChanges
{
	/*
	 When a change to a Ref is committed:
	 - a new node is added to its history list if
	 - history list length < minHistory OR 
	 - a fault has occurred since the last commit of the Ref and history list length < maxHistory 
	 - otherwise the oldest node is modified to become the newest node
	 
	 With minHistory the history list of each Ref grows according to how the Ref is actually used. If a Ref never has a 
	 fault, its history list never needs to grow.
	 */
	
	NSUInteger msecs = [CTKUtils currentTimeInMillis];
	NSUInteger txnCommitPoint = [self private_commitPoint];
	
	for(CTKReference *ref in [self.vals keyEnumerator]){
		
		//id oldValue = (ref.tvals == nil) ? nil : ref.tvals.value;
		id newValue = [self.vals objectForKey:ref];
		NSUInteger hcount = (NSUInteger)[ref private_historyCount]; // ref is locked so it is safe to call
		
		if (ref.tvals == nil)
		{
			ref.tvals = [CTKLockingTransactionValue transactionValueWithValue:newValue
																		point:txnCommitPoint
																		msecs:msecs];
		}
		
		else if ((ref.faults > 0 && hcount < ref.maxHistory ) || hcount < ref.minHistory)
		{
			ref.tvals = [CTKLockingTransactionValue transactionValueWithValue:newValue
																		point:txnCommitPoint
																		msecs:msecs
																		prior:ref.tvals];
			[ref resetFaults];
		}
		
		else {
			// We will modify the oldest node to become the newest node
			ref.tvals = ref.tvals.next;
			ref.tvals.value = newValue;
			ref.tvals.point = txnCommitPoint;
			ref.tvals.msecs = msecs;
		}
		
	}
}

// @TODO Elminate exception here
- (void) abort
{
	[self private_stopWithStatus:CTKTransactionStatusKilled];
	
	@throw [NSException exceptionWithName:@"CTKTransactionAbortException"
								   reason:@"Transaction was aborted."
								 userInfo:nil];
}

// @TODO how to maintain API and also eliminate exceptions here? I would need some way of breaking the transaction using an ivar which I check? info.status = RETRY ?
- (void) ensureReference:(CTKReference *)aRef
{
	if (self.info.isRunning == NO)
		@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
														reason:@"Current transaction is not running."
													  userInfo:nil];
	
	if ([self.ensures containsObject:aRef])
		return;
	
	[aRef readLock];
	
	// Check if someone completed a write after our snapshot
	if (aRef.tvals != nil && aRef.tvals.point > self.readPoint)
	{
		[aRef unlock];
		@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
														reason:@"Another transaction completed a write after this transation snapshot."
													  userInfo:nil];
		
	}
	
	CTKLockingTransactionInfo *refInfo = aRef.txnInfo;
	
	/*
	 If a writer exists and is not this transaction then we should stop.
	 */
	if (refInfo != nil && refInfo.isRunning)
	{
		[aRef unlock];
		
		if (refInfo != self.info)
		{
			[self private_blockAndBailWithInfo:refInfo];
		}
	}
	
	else {
		[self.ensures addObject:aRef];
	}
}

// @TODO how to maintain API and also eliminate exceptions here? I would need some way of breaking the transaction using an ivar which I check? info.status = RETRY ?
- (id) lockReference:(CTKReference *)aRef
{
	BOOL unlocked = YES;

	[self private_releaseReferenceIfEnsured:aRef];
	
	@try {
		
		unlocked = ([aRef tryWriteLock] == NO);
		
		if (unlocked)
		{
			@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
															reason:@"Could not get reference write lock"
														  userInfo:nil];
		}
		
		if (aRef.tvals != nil && aRef.tvals.point > self.readPoint)
		{	
			@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
															reason:@"The reference last known value commit point is higher than this transaction readpoint."
														  userInfo:nil];
		}
		
		CTKLockingTransactionInfo *refInfo = aRef.txnInfo;
		
		if (refInfo != nil && refInfo != self.info && refInfo.isRunning)
		{
			// There is a write lock conflict
			if (![self private_canBargeIntoTransactionWithInfo:refInfo])
			{
				unlocked = [aRef unlock];
				[self private_blockAndBailWithInfo:refInfo]; // throws exception
			}
		}
		
		aRef.txnInfo = self.info;
		return (aRef.tvals == nil) ? nil : aRef.tvals.value;
		
	}
	@finally {
		if (!unlocked)
			[aRef unlock];
	}
}

// @TODO how to maintain API and also eliminate exceptions here? I would need some way of breaking the transaction using an ivar which I check? info.status = RETRY ?
- (id) valueForReference:(CTKReference *)aRef
{
	if (self.info.isRunning == NO)
		@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
														reason:@"Transaction is not running."
													  userInfo:nil];
	
	// Return the in-transaction value if there is one
	id value = [self.vals objectForKey:aRef];
	
	if (value != nil)
		return value;
	
	BOOL locked = NO;
	
	// Find a previously committed value
	@try {
		
		locked = [aRef readLock];
		
		if (!locked)
		{
			CTKWarningLog(@"Could not get reference read lock!");
		}
		
		CTKLockingTransactionValue *version = aRef.tvals;
		
		NSAssert(version != nil, @"The reference is unbound.");
		
		do {
			if (version.point <= self.readPoint)
				return version.value;
			
		} while ((version = version.prior) != aRef.tvals);
		
	}
	@finally {
		if(locked)
			[aRef unlock];
	}
	
	// No version of value preceeds the read point
	[aRef incrementFaults];
	
	NSString *reason = [NSString stringWithFormat:
						@"No version of value preceeds this transaction readPoint (%U).", self.readPoint];
	@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
													reason:reason
												  userInfo:nil];
	
}

// @TODO eliminate retry exception add error
- (id) setValue:(id)aValue forReference:(CTKReference *)aRef
{
	if (self.info.isRunning == NO)
	{
		
		@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
														reason:@"The current thread has no running transaction."
													  userInfo:nil];
		
	}
	
	if ([self.commutes objectForKey:aRef] != nil)
		@throw [NSException exceptionWithName:NSInternalInconsistencyException
									   reason:@"Cannot perform a set after a commute"
									 userInfo:nil];
	
	if (![self.sets containsObject:aRef])
	{
		[self.sets addObject:aRef];
		[self lockReference:aRef]; // throws exception
	}
	
	[self.vals setObject:aValue forKey:aRef];
	
	return aValue;
	
}

// @TODO eliminate retry exception add error
- (id) commuteReference:(CTKReference *)aRef block:(id (^)(id))aBlock
{
	
	id result;
	
	if (self.info.isRunning == NO)
		@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
														reason:@"The current thread has no running transaction."
													  userInfo:nil];
	
	if ([self.vals objectForKey:aRef] == nil)
	{
		
		id value = nil;
		
		@try {
			[aRef readLock];
			value = (aRef.tvals == nil) ? nil : aRef.tvals.value;
		}
		@finally {
			[aRef unlock];
		}
		
		[self.vals setObject:value forKey:aRef];
		
	}
	
	NSMutableArray *operations = [self.commutes objectForKey:aRef];
	
	if (operations == nil)
	{
		operations = [NSMutableArray array];
		[self.commutes setObject:operations forKey:aRef];
	}
	
	[operations addObject:[[aBlock copy] autorelease]];
	
	result = aBlock([self.vals objectForKey:aRef]);
	[self.vals setObject:result forKey:aRef];
	
	return result;
}

- (BOOL) private_canBargeIntoTransactionWithInfo:(CTKLockingTransactionInfo *)refInfo
{	
	BOOL barged = NO;
	
	/*
	 We will determine whether the other transaction should retry while this one continues
	 
	 Condition 1.		This transaction must have been running for at least BARGE_WAIT_NANOS
	 Condition 2.		This transaction must have started before the transaction to be barged
	 
	 */
	
	if ([self bargeTimeElapsed] && self.startPoint < refInfo.startPoint)
	{
		CTKWarningLog(@"Trying to barged txn: %@", refInfo);
		
		/*
		 Condition 3.	The status of the other transaction must be RUNNING and must be successfully changed to KILLED. 
		 The check of the transaction status and changing it are done atomically. 
		 This means that if the other transaction is in the process of committing (status = COMMITTING) its changes, 
		 it will not be barged.
		 */
		
		// We do not @synchronized(refInfo){} since compareStatusToStatus uses an atomic op
		barged = [refInfo compareStatus:CTKTransactionStatusRunning setStatus:CTKTransactionStatusKilled];
		
		if (barged)
		{
			CTKWarningLog(@"Barged txn: %@", refInfo);
			[refInfo broadcast];
		}
	}
	
	return barged;
}

// @TODO eliminate retry exception add error?
- (void) private_blockAndBailWithInfo:(CTKLockingTransactionInfo *)refInfo
{
	[self private_stopWithStatus:CTKTransactionStatusRetry];
	
	@try {
		[refInfo waitNanos:(uint64_t)CTK_LOCK_WAIT_MSECS * 1000000];		
	}
	@catch (NSException * e) {
		// swallow
		CTKErrorLog(@"%@", e);
	}
	
	@throw [CTKTransactionRetryException exceptionWithName:CTKTransactionRetryExceptionName
													reason:@"Transaction was bailed."
												  userInfo:nil];
	
}

- (BOOL) private_releaseReferenceIfEnsured:(CTKReference *)aRef
{
	BOOL wasEnsured = [self.ensures containsObject:aRef];
	
	if (wasEnsured)
	{
		[self.ensures removeObject:aRef];
		[aRef unlock];
	}
	
	return wasEnsured;
}

- (void) private_stopWithStatus:(CTKTransactionStatus)aStatus
{
	BOOL shouldReset = NO;
	NSUInteger numStatus = (NSUInteger)aStatus;
	
	if (self.info != nil)
	{
		@synchronized(info)
		{
			NSAssert(self.info.status <= numStatus, @"Transaction status cannot be demoted.");
			
			if (self.info.status == CTKTransactionStatusRetry)
			{
				CTKWarningLog(@"We are trying to assign the same status!");
				//return;				
			}
				
			self.info.status = numStatus;
			[self.info broadcast];
			shouldReset = YES;
			
		
		}
		if(shouldReset)
			[self private_resetState];
	}
	
}

#pragma mark Properties
//@synthesize actions;
@synthesize info, vals, sets, commutes, startPoint, readPoint, startTime, retryLimit, ensures;
@dynamic bargeTimeElapsed, isRunning;


- (BOOL) bargeTimeElapsed
{
	return ([CTKUtils currentTimeInNanos] - self.startTime > CTK_BARGE_WAIT_NANOS);
}

- (BOOL) isRunning
{
	return (self.info != nil) ? self.info.isRunning : NO;
}

- (void) private_acquireReadPoint
{
	readPoint = OSAtomicIncrement64Barrier(&lastPoint);
}

- (NSUInteger) private_commitPoint
{
	return OSAtomicIncrement64Barrier(&lastPoint);
}


@end



