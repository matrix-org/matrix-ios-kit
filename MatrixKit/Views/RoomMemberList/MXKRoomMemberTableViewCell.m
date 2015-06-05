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

#import "MXKRoomMemberTableViewCell.h"

#import "MXKRoomMemberCellDataStoring.h"

#import "MXKRoomMemberListDataSource.h"

#import "MXKMediaManager.h"
#import "MXKAccount.h"

@interface MXKRoomMemberTableViewCell ()
{
    NSRange lastSeenRange;
    
    MXKPieChartView* pieChartView;
}

@end

@implementation MXKRoomMemberTableViewCell

+ (UINib *)nib
{
    // By default, no nib is available.
    return nil;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    NSArray *nibViews = [[NSBundle bundleForClass:[MXKRoomMemberTableViewCell class]] loadNibNamed:NSStringFromClass([MXKRoomMemberTableViewCell class])
                                                                                             owner:nil
                                                                                           options:nil];
    self = nibViews.firstObject;
    return self;
}

- (void)render:(MXKCellData *)cellData
{
    // Sanity check: accept only object of MXKRoomMemberCellData classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKRoomMemberCellData class]]);
    
    MXKRoomMemberCellData *memberCellData = (MXKRoomMemberCellData*)cellData;
    if (memberCellData)
    {
        
        mxSession = memberCellData.mxSession;
        memberId = memberCellData.roomMember.userId;
        
        self.userLabel.text = memberCellData.memberDisplayName;
        
        // User thumbnail
        NSString *thumbnailURL = nil;
        if (memberCellData.roomMember.avatarUrl)
        {
            // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
            thumbnailURL = [mxSession.matrixRestClient urlOfContentThumbnail:memberCellData.roomMember.avatarUrl toFitViewSize:self.pictureView.frame.size withMethod:MXThumbnailingMethodCrop];
        }
        self.pictureView.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
        [self.pictureView setImageURL:thumbnailURL withImageOrientation:UIImageOrientationUp andPreviewImage:[UIImage imageNamed:@"default-profile"]];
        
        // Round image view
        [self.pictureView.layer setCornerRadius:self.pictureView.frame.size.width / 2];
        self.pictureView.clipsToBounds = YES;
        
        // Shade invited users
        if (memberCellData.roomMember.membership == MXMembershipInvite)
        {
            for (UIView *view in self.subviews)
            {
                view.alpha = 0.3;
            }
        }
        else
        {
            for (UIView *view in self.subviews)
            {
                view.alpha = 1;
            }
        }
        
        // Display the power level pie
        [self setPowerContainerValue:memberCellData.powerLevel];
        
        // Prepare presence string and thumbnail border color
        NSString* presenceText = nil;
        UIColor* thumbnailBorderColor = nil;
        
        // Customize banned and left (kicked) members
        if (memberCellData.roomMember.membership == MXMembershipLeave || memberCellData.roomMember.membership == MXMembershipBan)
        {
            self.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
            presenceText = (memberCellData.roomMember.membership == MXMembershipLeave) ? @"left" : @"banned";
        }
        else
        {
            self.backgroundColor = [UIColor whiteColor];
            
            // get the user presence and his thumbnail border color
            if (memberCellData.roomMember.membership == MXMembershipInvite)
            {
                thumbnailBorderColor = [UIColor lightGrayColor];
                presenceText = @"invited";
            }
            else
            {
                // Get the user that corresponds to this member
                MXUser *user = [mxSession userWithUserId:memberId];
                // existing user ?
                if (user)
                {
                    thumbnailBorderColor = [MXKAccount presenceColor:user.presence];
                    presenceText = [self lastActiveTime];
                    // Keep last seen range to update it
                    lastSeenRange = NSMakeRange(self.userLabel.text.length + 2, presenceText.length);
                    shouldUpdateActivityInfo = (presenceText.length != 0);
                }
            }
        }
        
        // if the thumbnail is defined
        if (thumbnailBorderColor)
        {
            self.pictureView.layer.borderWidth = 2;
            self.pictureView.layer.borderColor = thumbnailBorderColor.CGColor;
        }
        else
        {
            // remove the border
            // else it draws black border
            self.pictureView.layer.borderWidth = 0;
        }
        
        // and the presence text (if any)
        if (presenceText)
        {
            NSString* extraText = [NSString stringWithFormat:@"(%@)", presenceText];
            self.userLabel.text = [NSString stringWithFormat:@"%@ %@", self.userLabel.text, extraText];
            
            NSRange range = [self.userLabel.text rangeOfString:extraText];
            UIFont* font = self.userLabel.font;
            
            // Create the attributes
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                   font, NSFontAttributeName,
                                   self.userLabel.textColor, NSForegroundColorAttributeName, nil];
            
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                      font, NSFontAttributeName,
                                      [UIColor lightGrayColor], NSForegroundColorAttributeName, nil];
            
            // Create the attributed string (text + attributes)
            NSMutableAttributedString *attributedText =[[NSMutableAttributedString alloc] initWithString:self.userLabel.text attributes:attrs];
            [attributedText setAttributes:subAttrs range:range];
            
            // Set it in our UILabel and we are done!
            [self.userLabel setAttributedText:attributedText];
        }
    }
}

+ (CGFloat)heightForCellData:(MXKCellData *)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    return 50;
}

- (NSString*)lastActiveTime
{
    NSString* lastActiveTime = nil;
    
    // Get the user that corresponds to this member
    MXUser *user = [mxSession userWithUserId:memberId];
    if (user)
    {
        // Prepare last active ago string
        NSUInteger lastActiveAgoInSec = user.lastActiveAgo / 1000;
        if (lastActiveAgoInSec < 60)
        {
            lastActiveTime = [NSString stringWithFormat:@"%lus", (unsigned long)lastActiveAgoInSec];
        }
        else if (lastActiveAgoInSec < 3600)
        {
            lastActiveTime = [NSString stringWithFormat:@"%lum", (unsigned long)(lastActiveAgoInSec / 60)];
        }
        else if (lastActiveAgoInSec < 86400)
        {
            lastActiveTime = [NSString stringWithFormat:@"%luh", (unsigned long)(lastActiveAgoInSec / 3600)];
        }
        else
        {
            lastActiveTime = [NSString stringWithFormat:@"%lud", (unsigned long)(lastActiveAgoInSec / 86400)];
        }
        
        // Check presence
        switch (user.presence)
        {
            case MXPresenceOffline:
            {
                lastActiveTime = @"offline";
                break;
            }
            case MXPresenceHidden:
            case MXPresenceUnknown:
            case MXPresenceFreeForChat:
            {
                lastActiveTime = nil;
                break;
            }
            case MXPresenceOnline:
            case MXPresenceUnavailable:
            default:
                break;
        }
        
    }
    
    return lastActiveTime;
}

- (void)setPowerContainerValue:(CGFloat)progress
{
    // no power level -> hide the pie
    if (0 == progress)
    {
        self.powerContainer.hidden = YES;
        return;
    }
    
    // display it
    self.powerContainer.hidden = NO;
    self.powerContainer.backgroundColor = [UIColor clearColor];
    
    if (!pieChartView)
    {
        pieChartView = [[MXKPieChartView alloc] initWithFrame:self.powerContainer.bounds];
        [self.powerContainer addSubview:pieChartView];
    }
    
    pieChartView.progress = progress;
}

- (void)updateActivityInfo
{
    // Check whether update is required.
    if (shouldUpdateActivityInfo)
    {
        
        NSString *lastSeen = [self lastActiveTime];
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithAttributedString:self.userLabel.attributedText];
        if (lastSeen.length)
        {
            
            [attributedText replaceCharactersInRange:lastSeenRange withString:lastSeen];
            
            // Update last seen range
            lastSeenRange.length = lastSeen.length;
        }
        else
        {
            
            // remove presence info
            lastSeenRange.location -= 1;
            lastSeenRange.length += 2;
            [attributedText deleteCharactersInRange:lastSeenRange];
            
            shouldUpdateActivityInfo = NO;
        }
        
        [self.userLabel setAttributedText:attributedText];
    }
}

@end
