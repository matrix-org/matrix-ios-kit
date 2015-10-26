/*
 Copyright 2015 OpenMarket Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MXKLRUCache.h"

@interface MXKLRUCacheItem : NSObject

/**
 The item counter
 */
@property NSUInteger refCount;

/**
 The cached object
 */
@property NSObject* object;

/**
 The object key
 */
@property NSString* key;

@end

@implementation MXKLRUCacheItem
@end


@interface MXKLRUCache ()
{
    // the cached objects list
    // sorted by regCount
    NSMutableArray<MXKLRUCacheItem *> *cachedObjects;
    
    /**
     The cached keys
     */
    NSMutableArray<NSString*> *cachedKeys;
}
@end

@implementation MXKLRUCache

- (id)initWith:(NSUInteger)aCount
{
    self = [super init];
    if (self)
    {
        _count = aCount;
        cachedObjects = [[NSMutableArray alloc] initWithCapacity:aCount];
        cachedKeys = [[NSMutableArray alloc] initWithCapacity:aCount];
    }
    return self;
}

- (void)sortCachedItems
{
    cachedObjects = [[cachedObjects sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
     {
         MXKLRUCacheItem* item1 = (MXKLRUCacheItem*)a;
         MXKLRUCacheItem* item2 = (MXKLRUCacheItem*)b;
         
         return item2.refCount - item1.refCount;
     }] mutableCopy];
    
    [cachedKeys removeAllObjects];
    
    for(MXKLRUCacheItem* item in cachedObjects)
    {
        [cachedKeys addObject:item.key];
    }
}


/**
 Retrieve an object from its key.
 @param key the object key
 @return the cached object if it is found else nil
 */
- (NSObject*)get:(NSString*)key
{
    NSObject* object = nil;
    
    if (key)
    {
        @synchronized(cachedObjects)
        {
            NSUInteger pos = [cachedKeys indexOfObject:key];
            
            if (pos != NSNotFound)
            {
                MXKLRUCacheItem* item = [cachedObjects objectAtIndex:pos];
                
                object = item.object;
                
                // update the count order
                item.refCount++;
                [self sortCachedItems];
            }
        }
    }
    
    return object;
}

/**
 Put an object from its key.
 @param key the object key
 @param object the object to store
 */
- (void)put:(NSString*)key object:(NSObject*)object
{
    if (key)
    {
        @synchronized(cachedObjects)
        {
            NSUInteger pos = [cachedKeys indexOfObject:key];
            
            if (pos == NSNotFound)
            {
                MXKLRUCacheItem* item = [[MXKLRUCacheItem alloc] init];
        
                item.object = object;
                item.refCount = 1;
                item.key = key;

                // remove the less used object
                if (cachedKeys.count >= _count)
                {
                    [cachedObjects removeLastObject];
                    [cachedKeys removeLastObject];
                    
                }
                
                [cachedObjects addObject:item];
                [cachedKeys addObject:key];
            }
        }
    }
}

/**
 Clear the LRU cache.
 */
- (void)clear
{
    @synchronized(cachedObjects)
    {
        [cachedObjects removeAllObjects];
        [cachedKeys removeAllObjects];
    }
}

@end
