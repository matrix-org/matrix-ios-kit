/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
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

#import "MXKCollectionViewCell.h"

@implementation MXKCollectionViewCell

+ (UINib *)nib
{
    NSParameterAssert(NSThread.isMainThread);

    // Nib cache lives forever. UINibs release resources on demand. Null means there is no nib.
    static NSMutableDictionary<Class, id> *nibs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nibs = [[NSMutableDictionary alloc] init];
    });

    id result = nibs[(id)self];
    if (!result)
    {
        NSString *className = NSStringFromClass(self);
        NSString *path = [mainBundle pathForResource:className ofType:@"nib"];
        if (path)
        {
            result = [UINib nibWithNibName:className bundle:[NSBundle bundleForClass:self]];
        }
        nibs[(id)self] = result ?: [NSNull null];
    }
    return result == [NSNull null] ? nil : result;
}

+ (NSString*)defaultReuseIdentifier
{
    return NSStringFromClass([self class]);
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self customizeCollectionViewCellRendering];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self customizeCollectionViewCellRendering];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    // Check whether a xib is defined
    UINib *nib = [self.class nib];
    if (nib)
    {
        self = [nib instantiateWithOwner:nil options:nil].firstObject;
        self.frame = frame;
    }
    else
    {
        self = [super initWithFrame:frame];
        [self customizeCollectionViewCellRendering];
    }
    
    return self;
}

- (void)customizeCollectionViewCellRendering
{
    // Do nothing by default.
}

@end

