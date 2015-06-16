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

#import "MXKTableViewController.h"

/**
 Available actions on room member
 */
typedef NSString* MXKRoomMemberDetailsAction;
extern NSString *const MXKRoomMemberDetailsActionInvite;
extern NSString *const MXKRoomMemberDetailsActionLeave;
extern NSString *const MXKRoomMemberDetailsActionKick;
extern NSString *const MXKRoomMemberDetailsActionBan;
extern NSString *const MXKRoomMemberDetailsActionUnban;
extern NSString *const MXKRoomMemberDetailsActionSetPowerLevel;
extern NSString *const MXKRoomMemberDetailsActionStartChat;
extern NSString *const MXKRoomMemberDetailsActionStartVoiceCall;
extern NSString *const MXKRoomMemberDetailsActionStartVideoCall;

@class MXKRoomMemberDetailsViewController;

/**
 `MXKRoomMemberDetailsViewController` delegate.
 */
@protocol MXKRoomMemberDetailsViewControllerDelegate <NSObject>

/**
 Tells the delegate that the user wants to start a one-to-one chat or place a call with the room member.
 
 @param roomMemberDetailsViewController the `MXKRoomMemberDetailsViewController` instance.
 @param action the wanted action: MXKRoomMemberDetailsActionStartChat, MXKRoomMemberDetailsActionStartVoiceCall or MXKRoomMemberDetailsActionStartVideoCall.
 */
- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController startOneToOneCommunication:(MXKRoomMemberDetailsAction)action;

@end

@interface MXKRoomMemberDetailsViewController : MXKTableViewController

@property (weak, nonatomic) IBOutlet UIButton *memberThumbnailButton;
@property (weak, nonatomic) IBOutlet UITextView *roomMemberMatrixInfo;

/**
 The default account picture displayed when no picture is defined.
 */
@property (nonatomic) UIImage *picturePlaceholder;

/**
 The displayed member and the corresponding room
 */
@property (nonatomic, readonly) MXRoomMember *mxRoomMember;
@property (nonatomic, readonly) MXRoom *mxRoom;

/**
 Enable voip call (voice/video). NO by default
 */
@property (nonatomic) BOOL enableVoipCall;

/**
 The delegate for the view controller.
 */
@property (nonatomic) id<MXKRoomMemberDetailsViewControllerDelegate> delegate;

#pragma mark - Class methods

/**
 Returns the `UINib` object initialized for a `MXKRoomMemberDetailsViewController`.
 
 @return The initialized `UINib` object or `nil` if there were errors during initialization
 or the nib file could not be located.
 
 @discussion You may override this method to provide a customized nib. If you do,
 you should also override `roomMemberDetailsViewController` to return your
 view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKRoomMemberDetailsViewController` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `MXKRoomMemberDetailsViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)roomMemberDetailsViewController;

/**
 Set the room member to display. Provide the actual room in order to handle member changes.
 
 @param roomMember the matrix room member
 @param room the matrix room to which this member belongs.
 */
- (void)displayRoomMember:(MXRoomMember*)roomMember withMatrixRoom:(MXRoom*)room;

/**
 The member's thumbnail is displayed inside a button. The following method is registered on
 `UIControlEventTouchUpInside` event of this button.
 */
- (IBAction)onMemberThumbnailPressed:(id)sender;

/**
 The following method is registered on `UIControlEventTouchUpInside` event for all displayed action buttons (see MXKRoomMemberDetailsAction).
 */
- (IBAction)onActionButtonPressed:(id)sender;

@end

