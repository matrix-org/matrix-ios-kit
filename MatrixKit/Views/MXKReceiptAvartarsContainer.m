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

#import "MXKReceiptAvartarsContainer.h"

#import "MXSession.h"
#import "MXKImageView.h"


#define MAX_NBR_USERS 3

@interface MXKReceiptAvartarsContainer ()
{
    NSMutableArray* avatarViews;
    UIView* moreView;
    
}
@end

@implementation MXKReceiptAvartarsContainer

- (void)setUserIds:(NSArray*)userIds roomState:(MXRoomState*)roomState session:(MXSession*)session placeholder:(UIImage*)placeHolder
{
    CGRect globalFrame = self.frame;
    CGFloat side = globalFrame.size.height;
    int count = MIN(userIds.count, MAX_NBR_USERS);
    int index;
    
    MXRestClient* restclient = session.matrixRestClient;
    
    CGFloat xOff = 0;
    
    for(index = 0; index < count; )
    {
        NSString* userId = [userIds objectAtIndex:index];
        
        // Compute the member avatar URL
        MXRoomMember *roomMember = [roomState memberWithUserId:userId];
        
        if (roomMember)
        {
            NSString *avatarUrl = [restclient urlOfContentThumbnail:roomMember.avatarUrl toFitViewSize:CGSizeMake(side, side) withMethod:MXThumbnailingMethodCrop];
            
            if (!avatarUrl)
            {
                avatarUrl = roomMember.avatarUrl;
            }
            
            MXKImageView *imageView = [[MXKImageView alloc] initWithFrame:CGRectMake(xOff, 0, side, side)];
            xOff += side + 2;
            [self addSubview:imageView];
            [avatarViews addObject:imageView];
            
            [imageView setImageURL:avatarUrl withType:nil andImageOrientation:UIImageOrientationUp previewImage:placeHolder];
            [imageView.layer setCornerRadius:imageView.frame.size.width / 2];
            imageView.clipsToBounds = YES;
            imageView.backgroundColor = [UIColor yellowColor];
            
            index ++;
        }
    }
    
    // more than expected read receipts
    if (index > (MAX_NBR_USERS+1))
    {
        // add a more indicator

        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(xOff, 0, side, side)];
        label.text = @"...";
        label.font = [UIFont systemFontOfSize:11];
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.6;
        
        label.textColor = [UIColor blackColor];
        moreView = label;
        [self addSubview:label];;
    }
}

- (void)dealloc
{
    if (avatarViews)
    {
        for(UIView* view in avatarViews)
        {
            [view removeFromSuperview];
        }
        
        avatarViews = NULL;
    }
    
    if (moreView)
    {
        [moreView removeFromSuperview];
        moreView = NULL;
    }
}

@end