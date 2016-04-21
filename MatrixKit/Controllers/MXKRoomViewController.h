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
#import "MXKRoomActivitiesView.h"


#import "MXKAttachmentsViewController.h"

extern NSString *const kCmdChangeDisplayName;
extern NSString *const kCmdEmote;
extern NSString *const kCmdJoinRoom;
extern NSString *const kCmdKickUser;
extern NSString *const kCmdBanUser;
extern NSString *const kCmdUnbanUser;
extern NSString *const kCmdSetUserPowerLevel;
extern NSString *const kCmdResetUserPowerLevel;

/**
 This view controller displays messages of a room. Only one matrix session is handled by this view controller.
 */
@interface MXKRoomViewController : MXKViewController <MXKDataSourceDelegate, MXKRoomTitleViewDelegate, MXKRoomInputToolbarViewDelegate, UITableViewDelegate, UIDocumentInteractionControllerDelegate, MXKAttachmentsViewControllerDelegate>
{
@protected
    /**
     The document interaction Controller used to share attachment
     */
    UIDocumentInteractionController *documentInteractionController;
    
    /**
     The current shared attachment.
     */
    MXKAttachment *currentSharedAttachment;
    
    /**
     The potential text input placeholder is saved when it is replaced temporarily
     */
    NSString *savedInputToolbarPlaceholder;
    
    /**
     Tell whether a device rotation is in progress
     */
    BOOL isSizeTransitionInProgress;
}

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
 The current extra info view defined into the view controller.
 */
@property (nonatomic, readonly) MXKRoomActivitiesView* activitiesView;

/**
 The threshold used to trigger inconspicuous back pagination, or forwards pagination
 for non live timeline. A pagination is triggered when the vertical content offset
 is lower this threshold.
 Default is 300.
 */
@property (nonatomic) NSUInteger paginationThreshold;

/**
 The maximum number of messages to retrieve during a pagination. Default is 30.
 */
@property (nonatomic) NSUInteger paginationLimit;

/**
 Enable/disable saving of the current typed text in message composer when view disappears.
 The message composer is prefilled with this text when the room is opened again.
 This property value is YES by default.
 */
@property BOOL saveProgressTextInput;

/**
 The invited rooms can be automatically joined when the data source is ready.
 This property enable/disable this option. Its value is YES by default.
 */
@property BOOL autoJoinInvitedRoom;

/**
 This object is defined when the displayed room is left. It is added into the bubbles table header.
 This label is used to display the reason why the room has been left.
 */
@property (nonatomic, readonly) UILabel *leftRoomReasonLabel;

@property (nonatomic) IBOutlet UITableView *bubblesTableView;
@property (nonatomic) IBOutlet UIView *roomTitleViewContainer;
@property (nonatomic) IBOutlet UIView *roomInputToolbarContainer;
@property (nonatomic) IBOutlet UIView *roomActivitiesContainer;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bubblesTableViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bubblesTableViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *roomActivitiesContainerHeightConstraint;
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
 This method is called when the associated data source is ready.
 
 By default this operation triggers the initial back pagination when the user is an actual
 member of the room (membership = join).
 
 The invited rooms are automatically joined during this operation if 'autoJoinInvitedRoom' is YES.
 When the room is successfully joined, an initial back pagination is triggered too.
 Else nothing is done for the invited rooms.
 
 Override it to customize the view controller behavior when the data source is ready.
 */
- (void)onRoomDataSourceReady;

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
 Join the current displayed room.
 
 This operation fails if the user has already joined the room, or if the data source is not ready.
 It fails if a join request is already running too.
 
 @param completion the block to execute at the end of the operation.
 You may specify nil for this parameter.
 */
- (void)joinRoom:(void(^)(BOOL succeed))completion;

/**
 Join a room with a room id.

 This operation fails if the user has already joined the room, or if the data source is not ready,
 or if the access to the room is forbidden to the user.
 It fails if a join request is already running too.
 
 @param roomIdOrAlias the id or the alias of the room to join.
 @param signUrl the signurl paramater passed with a 3PID invitation. It is optional and can be nil.
 @param completion the block to execute at the end of the operation.
 You may specify nil for this parameter.
 */
- (void)joinRoomWithRoomId:(NSString*)roomIdOrAlias andSignUrl:(NSString*)signUrl completion:(void(^)(BOOL succeed))completion;

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
 Register the class used to instantiate the input toolbar view which will handle message composer
 and attachments selection for the room.
 
 The resulting view is added into 'roomInputToolbarContainer' view, which must be defined before calling this method.
 
 @param roomInputToolbarViewClass a MXKRoomInputToolbarView-inherited class, or nil to remove the current view.
 */
- (void)setRoomInputToolbarViewClass:(Class)roomInputToolbarViewClass;

/**
 Register the class used to instantiate the extra info view.
 
 The resulting view is added into 'roomActivitiesContainer' view, which must be defined before calling this method.
 
 @param roomActivitiesViewClass a MXKRoomActivitiesViewClass-inherited class, or nil to remove the current view.
 */
- (void)setRoomActivitiesViewClass:(Class)roomActivitiesViewClass;

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
