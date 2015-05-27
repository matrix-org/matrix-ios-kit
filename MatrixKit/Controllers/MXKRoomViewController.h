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

#import <MatrixSDK/MatrixSDK.h>

#import "MXKViewController.h"
#import "MXKRoomDataSource.h"
#import "MXKRoomTitleView.h"
#import "MXKRoomInputToolbarView.h"

extern NSString *const kCmdChangeDisplayName;
extern NSString *const kCmdEmote;
extern NSString *const kCmdJoinRoom;
extern NSString *const kCmdKickUser;
extern NSString *const kCmdBanUser;
extern NSString *const kCmdUnbanUser;
extern NSString *const kCmdSetUserPowerLevel;
extern NSString *const kCmdResetUserPowerLevel;

/**
 This view controller displays messages of a room.
 */
@interface MXKRoomViewController : MXKViewController <MXKDataSourceDelegate, MXKRoomTitleViewDelegate, MXKRoomInputToolbarViewDelegate, UITableViewDelegate>

/**
 The current data source associated to the view controller.
 */
@property (nonatomic, readonly) MXKRoomDataSource *roomDataSource;

/**
 The current title view defined into the view controller.
 */
@property (nonatomic, readonly) MXKRoomTitleView* titleView;

/**
 The current input toolbar view defined into the view controller.
 */
@property (nonatomic, readonly) MXKRoomInputToolbarView* inputToolbarView;

/**
 This object is defined when the displayed room is left. It is added into the bubbles table header.
 This label is used to display the reason why the room has been left.
 */
@property (nonatomic, readonly) UILabel *leftRoomReasonLabel;

@property (nonatomic) IBOutlet UITableView *bubblesTableView;
@property (nonatomic) IBOutlet UIView *roomTitleViewContainer;
@property (nonatomic) IBOutlet UIView *roomInputToolbarContainer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bubblesTableViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *roomInputToolbarContainerHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *roomInputToolbarContainerBottomConstraint;

#pragma mark - Class methods

/**
 Returns the `UINib` object initialized for a `MXKRoomViewController`.

 @return The initialized `UINib` object or `nil` if there were errors during initialization
 or the nib file could not be located.
 
 @discussion You may override this method to provide a customized nib. If you do,
 you should also override `roomViewController` to return your
 view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKRoomViewController` object.

 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `MXKRoomViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)roomViewController;

/**
 Display a room.
 
 @param roomDataSource the data source .
 */
- (void)displayRoom:(MXKRoomDataSource*)dataSource;

/**
 Update view controller appearance according to the state of its associated data source.
 This method is called in the following use cases:
 - on data source change (see `[MXKRoomViewController displayRoom:]`).
 - on data source state change (see `[MXKDataSourceDelegate dataSource:didStateChange:]`)
 - when view did appear.
 
 The default implementation:
 - show input toolbar view if the dataSource is defined and ready (`MXKDataSourceStateReady`), hide toolbar in others use cases.
 - stop activity indicator if the dataSource is defined and ready (`MXKDataSourceStateReady`).
 - update view controller title with room information.
 
 Override it to customize view appearance according to data source state.
 */
- (void)updateViewControllerAppearanceOnRoomDataSourceState;

/**
 Update view controller appearance when the user is about to leave the displayed room.
 This method is called when the user will leave the current room (see `kMXSessionWillLeaveRoomNotification`).
 
 The default implementation:
 - discard `roomDataSource`
 - hide input toolbar view
 - freeze the room title display
 - add a label (`leftRoomReasonLabel`) in bubbles table header to display the reason why the room has been left.
 
 Override it to customize view appearance, or to withdraw the view controller.
 
 @param event the MXEvent responsible for the leaving.
 */
- (void)leaveRoomOnEvent:(MXEvent*)event;

/**
 Register the class used to instantiate the title view which will handle the room name display.
 
 The resulting view is added into 'roomTitleViewContainer' view, which must be defined before calling this method.
 
 Note: By default the room name is displayed by using 'navigationItem.title' field of the view controller.
 
 @param roomTitleViewClass a MXKRoomTitleView-inherited class.
 */
- (void)setRoomTitleViewClass:(Class)roomTitleViewClass;

/**
 Register the class used to instantiate the input toolbar view
 which will handle message composer and attachments selection for the room.
 
 The resulting view is added into 'roomInputToolbarContainer' view, which must be defined before calling this method.
 
 @param roomInputToolbarViewClass a MXKRoomInputToolbarView-inherited class.
 */
- (void)setRoomInputToolbarViewClass:(Class)roomInputToolbarViewClass;

/**
 Detect and process potential IRC command in provided string.
 
 @param string to analyse
 @return YES if IRC style command has been detected and interpreted.
 */
- (BOOL)isIRCStyleCommand:(NSString*)string;

/**
 Force to dismiss keyboard if any
 */
- (void)dismissKeyboard;

@end
