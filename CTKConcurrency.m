#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#import "CTKLockingTransaction.h"
#import "CTKReference.h"
#import "CTKPersistentHashMap.h"
#include <libkern/OSAtomic.h>
#import "CTKUtils.h"
#include <stdlib.h>

@interface MockPersistentCollection : NSObject{
	NSArray *array;
}

- (id) initWithArray:(NSArray *)anArray;
- (NSUInteger) count;
- (MockPersistentCollection *) addObject:(id)anObject;
- (NSArray *) array;

@end

@implementation MockPersistentCollection

- (id) init
{
	return [self initWithArray:nil];
}

- (id) initWithArray:(NSArray *)anArray
{
	self = [super init];
	
	if (self != nil) 
	{
		array = (anArray) ? anArray : [NSArray array];
		[array retain];
	}
	return self;
}

- (void) dealloc
{
	[array release];
	[super dealloc];
}

- (NSArray *) array
{
	@synchronized(self){
		return array;
	}
}

- (NSUInteger) count
{
	@synchronized(self){
		return [array count];
	}
}

- (MockPersistentCollection *) addObject:(id)anObject
{
	@synchronized(self){
		return [[[MockPersistentCollection alloc] initWithArray:[array arrayByAddingObject:anObject]] autorelease];
	}
}

@end



int main (int argc, const char * argv[]) {
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	int maxTransactions = 100;

	NSLog(@"Readers and Writers");
	// Readers-Writers
	for (int i = 0; i < 10; i++) 
	{
		NSAutoreleasePool * inner = [[NSAutoreleasePool alloc] init];
		
		MockPersistentCollection *collection = [MockPersistentCollection new];
		CTKReference *ref = [collection reference];
		[collection release];
		
		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_group_t group = dispatch_group_create();
		
		NSUInteger t0 = [CTKUtils currentTimeInMillis];

		for(int i = 0; i < maxTransactions; i++){

			dispatch_group_async(group, queue, ^{
				
				NSError *error = nil;
				
				id (^doSet)(void) = ^ id (void) {
					
					BOOL isWriter = (arc4random() % 2) == 1;
					
					if(isWriter)
					{
						MockPersistentCollection *collection = (MockPersistentCollection *)[ref dereference];
						collection = [collection addObject:[NSNumber numberWithInt:i]];
						[ref setValue:collection];
						return collection;
					}
					else {
						MockPersistentCollection *collection = (MockPersistentCollection *)[ref dereference];
						return collection;
					}
					
					
				};
				
				MockPersistentCollection* result = [CTKLockingTransaction performBlock:doSet error:&error];
			
				if(result == nil && error != nil)
				{
					NSLog(@"Failed with error %@", [error localizedDescription]);
				}
				else 
				{
					//CTKLog(@"OK");

				}
			});
			
		}
			
		
		int result = dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
		dispatch_release(group);
		
		if(result != 0) 
			NSLog(@"Error, dispatch did not work or timeout");
		else {
			collection = [ref dereference];
			NSLog(@"Processed %U operations asynchronously in %U ms. Count is %U.",
				  maxTransactions, 
				  [CTKUtils currentTimeInMillis] - t0,
				  [collection count]);
			
		}
		
		[inner drain];
		
	}
	
	NSLog(@"Writers only (count should be %U)", maxTransactions);
	// Writers
	for (int i = 0; i < 10; i++) 
	{
		NSAutoreleasePool * inner = [[NSAutoreleasePool alloc] init];
		
		MockPersistentCollection *collection = [MockPersistentCollection new];
		CTKReference *ref = [collection reference];
		[collection release];
		
		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		dispatch_group_t group = dispatch_group_create();
		
		NSUInteger t0 = [CTKUtils currentTimeInMillis];
		
		for(int i = 0; i < maxTransactions; i++){
			
			dispatch_group_async(group, queue, ^{
				
				NSError *error = nil;
				
				id (^doSet)(void) = ^ id (void) {
					
					MockPersistentCollection *collection = (MockPersistentCollection *)[ref dereference];
					collection = [collection addObject:[NSNumber numberWithInt:i]];
					[ref setValue:collection];
					return collection;
					
					
				};
				
				MockPersistentCollection* result = [CTKLockingTransaction performBlock:doSet error:&error];
				
				if(result == nil && error != nil)
				{
					NSLog(@"Failed with error %@", [error localizedDescription]);
				}
				else 
				{
					//CTKLog(@"OK");
					
				}
			});
			
		}
		
		
		int result = dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
		dispatch_release(group);
		
		if(result != 0) 
			NSLog(@"Error, dispatch did not work or timeout");
		else {
			collection = [ref dereference];
			NSLog(@"Processed %U operations asynchronously in %U ms. Count is %U.",
				  maxTransactions, 
				  [CTKUtils currentTimeInMillis] - t0,
				  [collection count]);
			
		}
		
		[inner drain];
		
	}
	
	[pool drain];

    return 0;
}
