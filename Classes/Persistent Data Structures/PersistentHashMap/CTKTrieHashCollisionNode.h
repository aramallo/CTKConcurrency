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
#import "CTKTrieNode.h"

@interface CTKTrieHashCollisionNode : NSObject <CTKTrieNode> {
	NSUInteger hashValue;
	NSArray *leaves;
}

@property (readonly, retain) NSArray *leaves;


+ (id) hashCollisionNodeWithLeaves:(NSArray *)anArray hash:(NSUInteger)aHashValue;

- (id) initWithLeaves:(NSArray *)anArray hash:(NSUInteger)aHashValue;

- (NSUInteger) indexOfObjectForKey:(id)aKey hash:(NSUInteger)aHashValue;

@end
