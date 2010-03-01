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

#import "CTKReference.h"
#include <pthread.h>
#include <libkern/OSAtomic.h>
#import "CTKUtils.h"
#import "CTKLockingTransaction.h"
#import "CTKLockingTransactionValue.h"


@interface CTKReference ()
@property (readwrite, assign) NSUInteger identifier;
@property (readwrite, assign) BOOL isBound;
@end

@interface CTKReference (Private)
- (NSUInteger) private_historyCount;
@end


@implementation CTKReference

#pragma mark Class methods

+ (id) referenceWithValue:(id)aValue
{
	return [[[CTKReference alloc] initWithValue:aValue] autorelease];
}


#pragma mark Initializers and dealloc

- (id) initWithValue:(id)aValue
{	
	CTKLockingTransactionValue *tval = [CTKLockingTransactionValue transactionValueWithValue:aValue 
																					   point:0 
																					   msecs:[CTKUtils currentTimeInMillis]];
	return [self initWithTransactionValue:tval];	
}

- (id) initWithTransactionValue:(CTKLockingTransactionValue *)aTval
{
	static volatile int64_t CTKReference_identifiers;

	NSParameterAssert(aTval);

	self = [super init];
	
	if (self != nil)
	{
		self.identifier = OSAtomicIncrement64Barrier(&CTKReference_identifiers); 
		self.tvals = aTval;
		self.minHistory = 0;
		self.maxHistory = 10;
		pthread_rwlock_init(&rwlock, NULL);
	}

	return self;
}

- (void) dealloc
{	
	pthread_rwlock_destroy( &rwlock );
	[tvals release];
	[txnInfo release];
	
	[super dealloc];	
}


#pragma mark Equality

- (NSUInteger ) hash
{
	return self.identifier;
}

- (BOOL)isEqual:(id)object
{
	if (self == object)
		return YES;
	
	return ([self hash] == [object hash]);
}

- (NSComparisonResult)compare:(CTKReference *)anotherObject
{
	NSParameterAssert([anotherObject isKindOfClass:[CTKReference class]]);
	
	CTKReference *anotherRef = (CTKReference *)anotherObject;
	
	if (self.identifier == anotherRef.identifier)
		return NSOrderedSame;
	
	else if (self.identifier < anotherRef.identifier)
		return NSOrderedAscending;
	
	else
		return NSOrderedDescending;
}


#pragma mark Message Forwarding

- (id) forwardingTargetForSelector: (SEL)aSelector
{
    return [self dereference];
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)selector
{
	return [[self dereference] methodSignatureForSelector:selector];
}

- (void) forwardInvocation:(NSInvocation*)invocation
{
	id <NSObject> object = (id <NSObject>)[self dereference];
	
	if(object == nil)
		return;
	
	SEL aSelector = [invocation selector];
	
    if ([object respondsToSelector:aSelector])
        [invocation invokeWithTarget:object];
	
    else 
	{
		NSString *reason = [NSString stringWithFormat:@"CTKReference does not recognise selector: %@", 
							NSStringFromSelector(aSelector)];
		
		@throw [NSException exceptionWithName:NSInvalidArgumentException
									   reason:reason
									 userInfo:nil];
	}
}

#pragma mark Operations

- (void) trimHistory
{
	pthread_rwlock_wrlock( &rwlock );
	
	if (self.tvals != nil)
	{
		self.tvals.next = self.tvals;
		self.tvals.prior = self.tvals;
	}
	
	pthread_rwlock_unlock( &rwlock );
}

- (id) alterWithBlock:(id (^)(id))aBlock
{
	id value = [[CTKLockingTransaction transaction] valueForReference:self];
	
	value = aBlock(value);
	
	return [[CTKLockingTransaction transaction] setValue:value forReference:self];
}

- (id) commuteWithBlock:(id (^)(id))aBlock
{
	return [[CTKLockingTransaction transaction] commuteReference:self block:aBlock];

}

- (id) dereference
{
	CTKLockingTransaction *txn = [CTKLockingTransaction runningTransaction];
	return (txn == nil) ? self.value : [txn valueForReference:self];
}

- (void) touch
{
	[[CTKLockingTransaction transaction] ensureReference:self];
}

- (BOOL) readLock
{
	NSUInteger result = pthread_rwlock_rdlock( &rwlock );
	
	/* if(result != 0){
			
			NSString *reason;
			
			switch (result) {
				case EBUSY:
					reason = @"Could not get reference read lock. The lock could not be acquired, because a writer holds the lock or was blocked on it.";
					break;
				case EAGAIN:
					reason = @"The lock could not be acquired, because the maximum number of read locks against lock has been exceeded.";
					break;
				case EDEADLK:
					reason = @"	 The current thread already owns rwlock for writing.";
					break;				
				case EINVAL:
					reason = @"Could not get reference read lock. The value specified by rwlock is invalid.";
					break;
				case ENOMEM:
					reason = @"Could not get reference read lock. Insufficient memory exists to initialize the lock (applies to statically initialized locks only).";
					break;
				default:
					reason = @"Could not get reference read lock. Unknown reason";
					break;
			}
			
			CTKErrorLog(@"%@", reason);
		} */
	
	return (result == 0);
}

- (BOOL) tryWriteLock
{
	NSUInteger result = pthread_rwlock_trywrlock( &rwlock );
	
	/*if(result != 0){
		
		NSString *reason;
		
		switch (result) {
			case EBUSY:
				reason = @"Could not get reference write lock. The calling thread is not able to acquire the lock without blocking.";
				break;
			case EDEADLK:
				reason = @"Could not get reference write lock. The calling thread already owns the read/write lock (for reading or writing).";
				break;
			case EINVAL:
				reason = @"Could not get reference write lock. The value specified by rwlock is invalid.";
				break;
			case ENOMEM:
				reason = @"Could not get reference write lock. Insufficient memory exists to initialize the lock (applies to statically initialized locks only).";
				break;
			default:
				reason = @"Could not get reference write lock. Unknown reason";
				break;
		}
		
		CTKErrorLog(@"%@", reason);
	}*/

	return (result == 0);
}

- (BOOL) unlock
{
	NSUInteger result = pthread_rwlock_unlock( &rwlock );
	
	/* if(result != 0){
		
		NSString *reason;
		
		switch (result) {
			case EPERM:
				reason = @"Could not unlock reference. The current thread does not own the read/write lock.";
				break;
			case EINVAL:
				reason = @"Could not unlock reference. The value specified by rwlock is invalid.";
				break;
			default:
				reason = @"Could not unlock reference. Unknown reason";
				break;
		}
		
		CTKErrorLog(@"%@", reason);
	} */
	
	return (result == 0);
}

- (void) incrementFaults
{
	OSAtomicIncrement64Barrier(&faults);
}

- (void) resetFaults
{
	self.faults = 0;
}

#pragma marl Properties

@synthesize identifier, tvals, txnInfo, faults, maxHistory, minHistory;
@dynamic value, isBound, historyCount;

- (id) value
{
	@try 
	{
		pthread_rwlock_rdlock( &rwlock );
		NSAssert(self.tvals != nil, @"The reference %@ is unbound.", [self description]);
		return self.tvals.value;
	}
	@finally 
	{
		pthread_rwlock_unlock( &rwlock );
	}
}

- (void) setValue:(id)aValue
{
	[[CTKLockingTransaction transaction] setValue:aValue forReference:self];
}


- (BOOL)isBound
{
	BOOL result;
	
	pthread_rwlock_rdlock( &rwlock );
	result = (self.tvals != nil);
	pthread_rwlock_unlock( &rwlock );	
	
	return result;
}


- (NSUInteger) historyCount
{
	NSUInteger count = 0;
	
	pthread_rwlock_rdlock( &rwlock );
	count = [self private_historyCount];
	pthread_rwlock_unlock( &rwlock );
	
	return count;
}

- (NSUInteger) private_historyCount
{
	
	if (self.tvals == nil)
		return 0;
	
	NSUInteger count = 0;

	for(CTKLockingTransactionValue *tval = self.tvals.next; tval != self.tvals; tval = tval.next){
		count++;
	}
	
	return count;
}


@end


//////////////////////////////////////////////////////////////////////////
// Categories
//////////////////////////////////////////////////////////////////////////


@implementation NSObject (CTKTransactionalMemoryAdditions)

- (CTKReference *) reference
{
	return [CTKReference referenceWithValue:self];
}

@end