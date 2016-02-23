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

#import "MXKRoomMemberDetailsViewController.h"

#import "MXKTableViewCellWithButtons.h"

#import "MXKMediaManager.h"
#import "MXKAlert.h"
#import "NSBundle+MatrixKit.h"

#import "MXKAppSettings.h"

#import "MXKConstants.h"

@interface MXKRoomMemberDetailsViewController ()
{
    id membersListener;
    
    NSMutableArray* buttonsTitles;
    
    // mask view while processing a request
    UIView* pendingRequestMask;
    UIActivityIndicatorView * pendingMaskSpinnerView;
    
    // Observe left rooms
    id leaveRoomNotificationObserver;
}

@property (strong, nonatomic) MXKAlert *actionMenu;

@end

@implementation MXKRoomMemberDetailsViewController
@synthesize mxRoom;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomMemberDetailsViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRoomMemberDetailsViewController class]]];
}

+ (instancetype)roomMemberDetailsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRoomMemberDetailsViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRoomMemberDetailsViewController class]]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!self.tableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    buttonsTitles = [[NSMutableArray alloc] init];
    
    // ignore useless update
    if (_mxRoomMember)
    {
        [self updateMemberInfo];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateMemberInfo];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self removeObservers];
}

- (void)destroy
{
    // close any pending actionsheet
    if (self.actionMenu)
    {
        [self.actionMenu dismiss:NO];
        self.actionMenu = nil;
    }
    
    [self removeObservers];
    
    self.delegate = nil;
    
    [super destroy];
}

#pragma mark -

- (void)displayRoomMember:(MXRoomMember*)roomMember withMatrixRoom:(MXRoom*)room
{
    [self removeObservers];
    
    mxRoom = room;
    
    // Update matrix session associated to the view controller
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions) {
        [self removeMatrixSession:mxSession];
    }
    [self addMatrixSession:room.mxSession];
    
    _mxRoomMember = roomMember;
    [self updateMemberInfo];
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setEnableVoipCall:(BOOL)enableVoipCall
{
    if (_enableVoipCall != enableVoipCall)
    {
        _enableVoipCall = enableVoipCall;
        [self updateMemberInfo];
    }
}

- (IBAction)onActionButtonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        // already a pending action
        if ([self hasPendingAction])
        {
            return;
        }
        
        NSString* action = ((UIButton*)sender).titleLabel.text;
        
        if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"leave"]])
        {
            [self addPendingActionMask];
            [self.mxRoom leave:^{
                
                [self removePendingActionMask];
                [self withdrawViewControllerAnimated:YES completion:nil];
                
            } failure:^(NSError *error) {
                
                [self removePendingActionMask];
                NSLog(@"[MXKMemberVC] Leave room %@ failed: %@", mxRoom.state.roomId, error);
                // Notify MatrixKit user
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                
            }];
        }
        else if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"set_power_level"]])
        {
            [self updateUserPowerLevel:_mxRoomMember];
        }
        else if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"kick"]])
        {
            [self addPendingActionMask];
            [mxRoom kickUser:_mxRoomMember.userId
                      reason:nil
                     success:^{
                         
                         [self removePendingActionMask];
                         // Pop/Dismiss the current view controller if the left members are hidden
                         if (![[MXKAppSettings standardAppSettings] showLeftMembersInRoomMemberList])
                         {
                             [self withdrawViewControllerAnimated:YES completion:nil];
                         }
                         
                     } failure:^(NSError *error) {
                         
                         [self removePendingActionMask];
                         NSLog(@"[MXKMemberVC] Kick %@ failed: %@", _mxRoomMember.userId, error);
                         // Notify MatrixKit user
                         [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                         
                     }];
        }
        else if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"ban"]])
        {
            [self addPendingActionMask];
            [mxRoom banUser:_mxRoomMember.userId
                     reason:nil
                    success:^{
                        
                        [self removePendingActionMask];
                        
                    } failure:^(NSError *error) {
                        
                        [self removePendingActionMask];
                        NSLog(@"[MXKMemberVC] Ban %@ failed: %@", _mxRoomMember.userId, error);
                        // Notify MatrixKit user
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                        
                    }];
        }
        else if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"invite"]])
        {
            [self addPendingActionMask];
            [mxRoom inviteUser:_mxRoomMember.userId
                       success:^{
                           
                           [self removePendingActionMask];
                           
                       } failure:^(NSError *error) {
                           
                           [self removePendingActionMask];
                           NSLog(@"[MXKMemberVC] Invite %@ failed: %@", _mxRoomMember.userId, error);
                           // Notify MatrixKit user
                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                           
                       }];
        }
        else if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"unban"]])
        {
            [self addPendingActionMask];
            [mxRoom unbanUser:_mxRoomMember.userId
                      success:^{
                          
                          [self removePendingActionMask];
                          
                      } failure:^(NSError *error) {
                          
                          [self removePendingActionMask];
                          NSLog(@"[MXKMemberVC] Unban %@ failed: %@", _mxRoomMember.userId, error);
                          // Notify MatrixKit user
                          [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                          
                      }];
        }
        else if ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"start_chat"]])
        {
            if (self.delegate)
            {
                [self addPendingActionMask];
                
                [self.delegate roomMemberDetailsViewController:self startChatWithMemberId:_mxRoomMember.userId];
                
                [self removePendingActionMask];
            }
        }
        else if (([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"start_voice_call"]]) || ([action isEqualToString:[NSBundle mxk_localizedStringForKey:@"start_video_call"]]))
        {
            BOOL isVideoCall = [action isEqualToString:[NSBundle mxk_localizedStringForKey:@"start_video_call"]];
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(roomMemberDetailsViewController:placeVoipCallWithMemberId:andVideo:)])
            {
                [self addPendingActionMask];
                
                [self.delegate roomMemberDetailsViewController:self placeVoipCallWithMemberId:_mxRoomMember.userId andVideo:isVideoCall];
                
                [self removePendingActionMask];
            }
            else
            {
                [self addPendingActionMask];
                
                MXRoom* oneToOneRoom = [self.mainSession privateOneToOneRoomWithUserId:_mxRoomMember.userId];
                
                // Place the call directly if the room exists
                if (oneToOneRoom)
                {
                    [self.mainSession.callManager placeCallInRoom:oneToOneRoom.state.roomId withVideo:isVideoCall];
                    [self removePendingActionMask];
                }
                else
                {
                    // Create a new room
                    [self.mainSession createRoom:nil
                                      visibility:kMXRoomVisibilityPrivate
                                       roomAlias:nil
                                           topic:nil
                                         success:^(MXRoom *room) {
                                             
                                             // Add the user
                                             [room inviteUser:_mxRoomMember.userId success:^{
                                                 
                                                 // Delay the call in order to be sure that the room is ready
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     [self.mainSession.callManager placeCallInRoom:room.state.roomId withVideo:isVideoCall];
                                                     [self removePendingActionMask];
                                                 });
                                                 
                                             } failure:^(NSError *error) {
                                                 
                                                 NSLog(@"[MXKMemberVC] %@ invitation failed (roomId: %@): %@", _mxRoomMember.userId, room.state.roomId, error);
                                                 [self removePendingActionMask];
                                                 // Notify MatrixKit user
                                                 [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                                                 
                                             }];
                                             
                                         } failure:^(NSError *error) {
                                             
                                             NSLog(@"[MXKMemberVC] Create room failed: %@", error);
                                             [self removePendingActionMask];
                                             // Notify MatrixKit user
                                             [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                                             
                                         }];
                }
            }
        }
    }
}

#pragma mark - Internals

- (void)removeObservers
{
    if (leaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:leaveRoomNotificationObserver];
        leaveRoomNotificationObserver = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (membersListener && mxRoom)
    {
        [mxRoom.liveTimeline removeListener:membersListener];
        membersListener = nil;
    }
}

- (void)updateMemberInfo
{
    // Remove any pending observers
    [self removeObservers];
    
    self.title = _mxRoomMember.displayname ? _mxRoomMember.displayname : _mxRoomMember.userId;
    
    // set the thumbnail info
    self.memberThumbnail.contentMode = UIViewContentModeScaleAspectFill;
    self.memberThumbnail.backgroundColor = [UIColor clearColor];
    [self.memberThumbnail.layer setCornerRadius:self.memberThumbnail.frame.size.width / 2];
    [self.memberThumbnail setClipsToBounds:YES];
    
    NSString *thumbnailURL = nil;
    if (_mxRoomMember.avatarUrl)
    {
        // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        thumbnailURL = [self.mainSession.matrixRestClient urlOfContentThumbnail:_mxRoomMember.avatarUrl toFitViewSize:self.memberThumbnail.frame.size withMethod:MXThumbnailingMethodCrop];
    }
    
    self.memberThumbnail.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
    self.memberThumbnail.enableInMemoryCache = YES;
    [self.memberThumbnail setImageURL:thumbnailURL withType:nil andImageOrientation:UIImageOrientationUp previewImage:self.picturePlaceholder];
    
    self.roomMemberMatrixInfo.text = _mxRoomMember.userId;
    
    if (mxRoom)
    {
        // Observe room's members update
        NSArray *mxMembersEvents = @[kMXEventTypeStringRoomMember, kMXEventTypeStringRoomPowerLevels];
        membersListener = [mxRoom.liveTimeline listenToEventsOfTypes:mxMembersEvents onEvent:^(MXEvent *event, MXEventDirection direction, id customObject) {
            // consider only live event
            if (direction == MXEventDirectionForwards)
            {
                
                // Hide potential action sheet
                if (self.actionMenu)
                {
                    [self.actionMenu dismiss:NO];
                    self.actionMenu = nil;
                }
                
                MXRoomMember* nextRoomMember = nil;
                
                // get the updated memmber
                NSArray* membersList = [self.mxRoom.state members];
                for (MXRoomMember* member in membersList)
                {
                    if ([member.userId isEqualToString:_mxRoomMember.userId])
                    {
                        nextRoomMember = member;
                        break;
                    }
                }
                
                // does the member still exist ?
                if (nextRoomMember)
                {
                    // Refresh member
                    _mxRoomMember = nextRoomMember;
                    [self updateMemberInfo];
                } else
                {
                    [self withdrawViewControllerAnimated:YES completion:nil];
                }
            }
        }];
        
        // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
        leaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            // Check whether the user will leave the room related to the displayed member
            if (notif.object == self.mainSession)
            {
                NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
                if (roomId && [roomId isEqualToString:mxRoom.state.roomId])
                {
                    // We must remove the current view controller.
                    [self withdrawViewControllerAnimated:YES completion:nil];
                }
            }
        }];
    }
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Check user's power level before allowing an action (kick, ban, ...)
    MXRoomPowerLevels *powerLevels = [mxRoom.state powerLevels];
    NSUInteger memberPowerLevel = [powerLevels powerLevelOfUserWithUserID:_mxRoomMember.userId];
    NSUInteger oneSelfPowerLevel = [powerLevels powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
    
    [buttonsTitles removeAllObjects];
    
    // Consider the case of the user himself
    if ([_mxRoomMember.userId isEqualToString:self.mainSession.myUser.userId])
    {
        [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"leave"]];
        
        if (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomPowerLevels])
        {
            [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"set_power_level"]];
        }
    }
    else if (_mxRoomMember)
    {
        if (_enableVoipCall)
        {
            // Offer voip call options
            [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"start_voice_call"]];
            [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"start_video_call"]];
        }
        
        // Consider membership of the selected member
        switch (_mxRoomMember.membership)
        {
            case MXMembershipInvite:
            case MXMembershipJoin:
            {
                // Check conditions to be able to kick someone
                if (oneSelfPowerLevel >= [powerLevels kick] && oneSelfPowerLevel >= memberPowerLevel)
                {
                    [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"kick"]];
                }
                // Check conditions to be able to ban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel >= memberPowerLevel)
                {
                    [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"ban"]];
                }
                break;
            }
            case MXMembershipLeave:
            {
                // Check conditions to be able to invite someone
                if (oneSelfPowerLevel >= [powerLevels invite])
                {
                    [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"invite"]];
                }
                // Check conditions to be able to ban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel >= memberPowerLevel)
                {
                    [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"ban"]];
                }
                break;
            }
            case MXMembershipBan:
            {
                // Check conditions to be able to unban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel >= memberPowerLevel)
                {
                    [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"unban"]];
                }
                break;
            }
            default:
            {
                break;
            }
        }
        
        // update power level
        if (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomPowerLevels])
        {
            [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"set_power_level"]];
        }
        
        // offer to start a new chat only if the room is not a 1:1 room with this user
        // it does not make sense : it would open the same room
        MXRoom* room = [self.mainSession privateOneToOneRoomWithUserId:_mxRoomMember.userId];
        if (!room || (![room.state.roomId isEqualToString:mxRoom.state.roomId]))
        {
            [buttonsTitles addObject:[NSBundle mxk_localizedStringForKey:@"start_chat"]];
        }
    }
    
    return (buttonsTitles.count + 1) / 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        NSInteger row = indexPath.row;
        
        MXKTableViewCellWithButtons *cell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButtons defaultReuseIdentifier]];
        if (!cell)
        {
            cell = [[MXKTableViewCellWithButtons alloc] init];
        }
        
        cell.mxkButtonNumber = 2;
        NSArray *buttons = cell.mxkButtons;
        NSInteger index = row * 2;
        NSString *text = nil;
        for (UIButton *button in buttons)
        {
            if (index < buttonsTitles.count)
            {
                text = [buttonsTitles objectAtIndex:index];
            }
            else
            {
                text = nil;
            }
            
            button.hidden = (text.length == 0);
            
            button.layer.borderColor = button.tintColor.CGColor;
            button.layer.borderWidth = 1;
            button.layer.cornerRadius = 5;
            
            [button setTitle:text forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateHighlighted];
            
            [button addTarget:self action:@selector(onActionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            index ++;
        }
        
        return cell;
    }
    
    return nil;
}


#pragma mark - button management

- (BOOL)hasPendingAction
{
    return nil != pendingMaskSpinnerView;
}

- (void)addPendingActionMask
{
    // add a spinner above the tableview to avoid that the user tap on any other button
    pendingMaskSpinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    pendingMaskSpinnerView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
    pendingMaskSpinnerView.frame = self.tableView.frame;
    pendingMaskSpinnerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    
    // append it
    [self.tableView.superview addSubview:pendingMaskSpinnerView];
    
    // animate it
    [pendingMaskSpinnerView startAnimating];
}

- (void)removePendingActionMask
{
    if (pendingMaskSpinnerView)
    {
        [pendingMaskSpinnerView removeFromSuperview];
        pendingMaskSpinnerView = nil;
        [self.tableView reloadData];
    }
}

- (void)setUserPowerLevel:(MXRoomMember*)roomMember to:(NSUInteger)value
{
    NSUInteger currentPowerLevel = [self.mxRoom.state.powerLevels powerLevelOfUserWithUserID:roomMember.userId];
    
    // check if the power level has not yet been set to 0
    if (value != currentPowerLevel)
    {
        __weak typeof(self) weakSelf = self;
        
        [weakSelf addPendingActionMask];
        
        // Reset user power level
        [self.mxRoom setPowerLevelOfUserWithUserID:roomMember.userId powerLevel:value success:^{
            
            [weakSelf removePendingActionMask];
            
        } failure:^(NSError *error) {
            
            [weakSelf removePendingActionMask];
            NSLog(@"[MXKMemberVC] Set user power (%@) failed: %@", roomMember.userId, error);
            // Notify MatrixKit user
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
            
        }];
    }
}

- (void)updateUserPowerLevel:(MXRoomMember*)roomMember
{
    __weak typeof(self) weakSelf = self;
    
    // Ask for the power level to set
    self.actionMenu = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"power_level"]  message:nil style:MXKAlertStyleAlert];
    
    if (![self.mainSession.myUser.userId isEqualToString:roomMember.userId])
    {
        self.actionMenu.cancelButtonIndex = [self.actionMenu addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"reset_to_default"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
        {
            weakSelf.actionMenu = nil;
            
            [weakSelf setUserPowerLevel:roomMember to:weakSelf.mxRoom.state.powerLevels.usersDefault];
        }];
    }
    [self.actionMenu addTextFieldWithConfigurationHandler:^(UITextField *textField)
    {
        textField.secureTextEntry = NO;
        textField.text = [NSString stringWithFormat:@"%tu", [weakSelf.mxRoom.state.powerLevels powerLevelOfUserWithUserID:roomMember.userId]];
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [self.actionMenu addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
    {
        UITextField *textField = [alert textFieldAtIndex:0];
        weakSelf.actionMenu = nil;
        
        if (textField.text.length > 0)
        {
            [weakSelf setUserPowerLevel:roomMember to:[textField.text integerValue]];
        }
    }];
    [self.actionMenu showInViewController:self];
}

@end
