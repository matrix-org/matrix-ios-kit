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

#import <UIKit/UIKit.h>

#import "MXKImageView.h"
#import "MXKPieChartView.h"

#import "MXKCellRendering.h"

#import "MXUser.h"

/**
 `MXKRoomMemberTableViewCell` instances display a user in the context of the room member list.
 */
@interface MXKRoomMemberTableViewCell : UITableViewCell <MXKCellRendering> {

@protected
    /**
     Timer used to update presence information
     */
    NSTimer* presenceTimer;
    
    /**
     */
    MXSession *mxSession;
    
    /**
     */
    NSString *memberId;
}

@property (strong, nonatomic) IBOutlet MXKImageView *pictureView;
@property (weak, nonatomic) IBOutlet UILabel *userLabel;
@property (weak, nonatomic) IBOutlet UIView *powerContainer;
@property (weak, nonatomic) IBOutlet UIImageView *typingBadge;

/**
 Describe matrix user's presence by taking into account his presence and his last activity date.
 
 @param user a matrix user.
 @return a string which described user's presence.
 */
- (NSString*)getLastPresenceText:(MXUser*)user;

/**
 Get the color code related to a specific presence.
 
 @param presence
 @return color defined for the provided presence (nil if no color is defined).
 */
- (UIColor*)presenceColor:(MXPresence)presence;

@end
