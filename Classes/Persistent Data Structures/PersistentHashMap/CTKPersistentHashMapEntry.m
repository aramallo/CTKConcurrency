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

#import "CTKPersistentHashMapEntry.h"

@interface CTKPersistentHashMapEntry ()

@property (readwrite, copy) id key;
@property (readwrite, retain) id object;

@end


@implementation CTKPersistentHashMapEntry

+ (id) entryWithObject:(id)anObject forKey:(id)aKey
{
	return [[[CTKPersistentHashMapEntry alloc] initWithObject:anObject forKey:aKey] autorelease];
}


@synthesize key, object;


- (id) initWithObject:(id)anObject forKey:(id)aKey
{
	//NSParameterAssert([aKey conformsToProtocol:@protocol(NSCopying)]);
	
	self = [super init];
	
	if (self != nil) {
		self.object = anObject;
		self.key = aKey;
	}
	return self;
}

- (void) dealloc
{
	[key release];
	[object release];
	
	[super dealloc];
}

- (id) objectAtIndex:(NSUInteger)anIndex
{
	if(anIndex == 0)
		return self.key;
	
	else if(anIndex == 1)
		return self.object;
	
	else {
		
		NSException *e = [NSException exceptionWithName:NSRangeException
												 reason:@"Index out of bounds"
											   userInfo:nil];
		[e raise];
	}
	
	return nil;
}

@end
