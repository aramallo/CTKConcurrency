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
@class CTKPersistentHashMapEntry;
@class CTKPersistentHashMap;

@interface CTKPersistentHashMap : NSObject {
	NSUInteger count;
	id <CTKTrieNode> root;
}

@property (readonly, retain) id <CTKTrieNode> root;
@property (readonly, assign) NSUInteger count;


+ (id) emptyHashMap;

+ (id) hashMapWithRoot:(id <CTKTrieNode>)aNode count:(NSUInteger)value;

- (id) initWithRoot:(id <CTKTrieNode>)aNode count:(NSUInteger)value;

- (CTKPersistentHashMapEntry *) entryForKey:(id)aKey;

- (BOOL) containsObjectForKey:(id)aKey;

- (id) objectForKey:(id)aKey;

- (CTKPersistentHashMap *) mapBySettingObject:(id)anObject forKey:(id)aKey;

- (CTKPersistentHashMap *) mapByRemovingObjectForKey:(id)aKey;

- (NSArray *) allEntries;

- (NSArray *) allValues;

- (NSArray *) allKeys;

@end
