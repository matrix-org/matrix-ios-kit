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

#import "MXKReceiptSendersContainer.h"

#import "MXKImageView.h"

@implementation MXKReceiptSendersContainer

- (instancetype)initWithFrame:(CGRect)frame andRestClient:(MXRestClient*)restclient
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _restClient = restclient;
        _maxDisplayedAvatars = 3;
        _avatarMargin = 2.0;
        _moreLabel = nil;
    }
    return self;
}

- (void)refreshReceiptSenders:(NSArray<MXRoomMember*>*)roomMembers withPlaceHolders:(NSArray<UIImage*>*)placeHolders andAlignment:(ReadReceiptsAlignment)alignment
{
    // Remove all previous content
    for (UIView* view in self.subviews)
    {
        [view removeFromSuperview];
    }
    if (_moreLabel)
    {
        [_moreLabel removeFromSuperview];
        _moreLabel = nil;
    }
    
    CGRect globalFrame = self.frame;
    CGFloat side = globalFrame.size.height;
    unsigned long count;
    unsigned long maxDisplayableItems = ((int)globalFrame.size.width / side) - 1;
    
    maxDisplayableItems = MIN(maxDisplayableItems, _maxDisplayedAvatars);
    count = MIN(roomMembers.count, maxDisplayableItems);
    
    int index;
    
    CGFloat xOff = 0;
    
    if (alignment == ReadReceiptAlignmentRight)
    {
        xOff = globalFrame.size.width - (side + _avatarMargin);
    }
    
    for (index = 0; index < count; index++)
    {
        MXRoomMember *roomMember = [roomMembers objectAtIndex:index];
        UIImage *preview = index < placeHolders.count ? placeHolders[index] : nil;
        
        // Compute the member avatar URL
        NSString *avatarUrl = roomMember.avatarUrl;
        if (_restClient && avatarUrl)
        {
            avatarUrl = [_restClient urlOfContentThumbnail:avatarUrl toFitViewSize:CGSizeMake(side, side) withMethod:MXThumbnailingMethodCrop];
        }
        
        MXKImageView *imageView = [[MXKImageView alloc] initWithFrame:CGRectMake(xOff, 0, side, side)];
        
        if (alignment == ReadReceiptAlignmentRight)
        {
            xOff -= side + _avatarMargin;
        }
        else
        {
            xOff += side + _avatarMargin;
        }
        
        [self addSubview:imageView];
        imageView.enableInMemoryCache = YES;
        
        [imageView setImageURL:avatarUrl withType:nil andImageOrientation:UIImageOrientationUp previewImage:preview];
        
        [imageView.layer setCornerRadius:imageView.frame.size.width / 2];
        imageView.clipsToBounds = YES;
    }
    
    // more than expected read receipts
    if (roomMembers.count > maxDisplayableItems)
    {
        // add a more indicator

        _moreLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOff, 0, side, side)];
        _moreLabel.text = [NSString stringWithFormat:(alignment == ReadReceiptAlignmentRight) ? @"%tu+" : @"+%tu", roomMembers.count - maxDisplayableItems];
        _moreLabel.font = [UIFont systemFontOfSize:11];
        _moreLabel.adjustsFontSizeToFitWidth = YES;
        _moreLabel.minimumScaleFactor = 0.6;
        
        _moreLabel.textColor = [UIColor blackColor];
        [self addSubview:_moreLabel];
    }
}

- (void)dealloc
{
    NSArray* subviews = self.subviews;
    for (UIView* view in subviews)
    {
        [view removeFromSuperview];
    }
    
    if (_moreLabel)
    {
        [_moreLabel removeFromSuperview];
        _moreLabel = nil;
    }
    
    _restClient = nil;
}

@end