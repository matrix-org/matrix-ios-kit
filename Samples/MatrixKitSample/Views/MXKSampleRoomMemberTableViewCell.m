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

#import "MXKSampleRoomMemberTableViewCell.h"

#import "NSBundle+MatrixKit.h"

@interface MXKSampleRoomMemberTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *presenceLabel;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *powerlevelTopConstraint;
@property (weak, nonatomic) IBOutlet UIView *powerLevel;

@end

@implementation MXKSampleRoomMemberTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    // Check whether a xib is defined
    if ([NSBundle bundleForClass:[MXKSampleRoomMemberTableViewCell class]])
    {
        NSArray *nibViews = [[NSBundle bundleForClass:[MXKSampleRoomMemberTableViewCell class]] loadNibNamed:NSStringFromClass([MXKSampleRoomMemberTableViewCell class])
                                                                                                       owner:nil
                                                                                                     options:nil];
        self = nibViews.firstObject;
    }
    else
    {
        self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    }
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.powerContainer.layer.borderWidth = 1;
    self.powerContainer.layer.borderColor = [UIColor lightGrayColor].CGColor;
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
        self.pictureView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        [self.pictureView setImageURI:memberCellData.roomMember.avatarUrl
                         withType:nil
              andImageOrientation:UIImageOrientationUp
                     previewImage:nil
                     mediaManager:mxSession.mediaManager];
        
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
        
        // Prepare presence string, and name color
        NSString* presenceText = nil;
        UIColor* presenceColor = nil;
        
        // Customize banned and left (kicked) members
        if (memberCellData.roomMember.membership == MXMembershipLeave || memberCellData.roomMember.membership == MXMembershipBan)
        {
            presenceColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
            presenceText = (memberCellData.roomMember.membership == MXMembershipLeave) ? @"left" : @"banned";
        }
        else
        {
            
            // get the user presence
            if (memberCellData.roomMember.membership == MXMembershipInvite)
            {
                presenceColor = [UIColor lightGrayColor];
                presenceText = @"invited";
            }
            else
            {
                // Get the user that corresponds to this member
                MXUser *user = [mxSession userWithUserId:memberId];
                // existing user ?
                if (user)
                {
                    presenceColor = [self presenceColor:user.presence];
                    presenceText = [self lastActiveTime];
                    shouldUpdateActivityInfo = YES;
                }
            }
        }
        
        self.presenceLabel.text = presenceText;
        if (presenceColor)
        {
            self.presenceLabel.backgroundColor = presenceColor;
        }
        else
        {
            self.presenceLabel.backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)setPowerContainerValue:(CGFloat)progress
{
    // no power level -> hide the item
    if (0 == progress)
    {
        self.powerContainer.hidden = YES;
        self.powerLevel.hidden = YES;
        return;
    }
    
    // display it
    self.powerContainer.hidden = NO;
    self.powerLevel.hidden = NO;
    self.powerlevelTopConstraint.constant = 4 + ((1 - progress) * self.powerContainer.frame.size.height);
}

- (UIColor*)presenceColor:(MXPresence)presence
{
    switch (presence)
    {
        case MXPresenceOnline:
            return [UIColor colorWithRed:0.1 green:0.8 blue:0.1 alpha:1.0];
        case MXPresenceUnavailable:
            return [UIColor colorWithRed:1.0 green:0.6 blue:0.1 alpha:1.0];
        case MXPresenceOffline:
            return [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
        case MXPresenceUnknown:
        default:
            return nil;
    }
}

- (void)updateActivityInfo
{
    if (shouldUpdateActivityInfo)
    {
        self.presenceLabel.text = [self lastActiveTime];
    }
}

@end
