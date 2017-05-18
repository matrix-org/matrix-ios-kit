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

#import "MXKTableViewCell.h"

#import "MXKCellRendering.h"

#import "MXKRoomBubbleCellData.h"

#import "MXKImageView.h"
#import "MXKPieChartView.h"
#import "MXKReceiptSendersContainer.h"

#pragma mark - MXKCellRenderingDelegate cell tap locations

/**
 Action identifier used when the user tapped on message text view.
 
 The `userInfo` dictionary contains an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the tapped event.
 */
extern NSString *const kMXKRoomBubbleCellTapOnMessageTextView;

/**
 Action identifier used when the user tapped on user name label.
 
 The `userInfo` dictionary contains an `NSString` object under the `kMXKRoomBubbleCellUserIdKey` key, representing the user id of the tapped name label.
 */
extern NSString *const kMXKRoomBubbleCellTapOnSenderNameLabel;

/**
 Action identifier used when the user tapped on avatar view.
 
 The `userInfo` dictionary contains an `NSString` object under the `kMXKRoomBubbleCellUserIdKey` key, representing the user id of the tapped avatar.
 */
extern NSString *const kMXKRoomBubbleCellTapOnAvatarView;

/**
 Action identifier used when the user tapped on date/time container.
 
 The `userInfo` is nil.
 */
extern NSString *const kMXKRoomBubbleCellTapOnDateTimeContainer;

/**
 Action identifier used when the user tapped on attachment view.
 
 The `userInfo` is nil. The attachment can be retrieved via MXKRoomBubbleTableViewCell.attachmentView.
 */
extern NSString *const kMXKRoomBubbleCellTapOnAttachmentView;

/**
 Action identifier used when the user tapped on overlay container.
 
 The `userInfo` is nil
 */
extern NSString *const kMXKRoomBubbleCellTapOnOverlayContainer;

/**
 Action identifier used when the user tapped on content view.
 
 The `userInfo` dictionary may contain an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the event displayed at the level of the tapped line. This dictionary is empty if no event correspond to the tapped position.
 */
extern NSString *const kMXKRoomBubbleCellTapOnContentView;

/**
 Action identifier used when the user pressed unsent button displayed in front of an unsent event.
 
 The `userInfo` dictionary contains an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the unsent event.
 */
extern NSString *const kMXKRoomBubbleCellUnsentButtonPressed;

/**
 Action identifier used when the user long pressed on a displayed event.
 
 The `userInfo` dictionary contains an `MXEvent` object under the `kMXKRoomBubbleCellEventKey` key, representing the selected event.
 */
extern NSString *const kMXKRoomBubbleCellLongPressOnEvent;

/**
 Action identifier used when the user long pressed on progress view.
 
 The `userInfo` is nil. The progress view can be retrieved via MXKRoomBubbleTableViewCell.progressView.
 */
extern NSString *const kMXKRoomBubbleCellLongPressOnProgressView;

/**
 Action identifier used when the user long pressed on avatar view.
 
 The `userInfo` dictionary contains an `NSString` object under the `kMXKRoomBubbleCellUserIdKey` key, representing the user id of the concerned avatar.
 */
extern NSString *const kMXKRoomBubbleCellLongPressOnAvatarView;

/**
 Action identifier used when the user clicked on a link.

 This action is sent via the MXKCellRenderingDelegate `shouldDoAction` operation.

 The `userInfo` dictionary contains a `NSURL` object under the `kMXKRoomBubbleCellUrl` key, representing the url the user wants to open.

 The shouldDoAction implementation must return NO to prevent the system (safari) from opening the link.
 
 @discussion: If the link refers to a room alias/id, a user id or an event id, the non-ASCII characters (like '#' in room alias) has been
 escaped to be able to convert it into a legal URL string.
 */
extern NSString *const kMXKRoomBubbleCellShouldInteractWithURL;

/**
 Notifications `userInfo` keys
 */
extern NSString *const kMXKRoomBubbleCellUserIdKey;
extern NSString *const kMXKRoomBubbleCellEventKey;
extern NSString *const kMXKRoomBubbleCellUrl;

#pragma mark - MXKRoomBubbleTableViewCell

/**
 `MXKRoomBubbleTableViewCell` is a base class for displaying a room bubble.
 
 This class is used to handle a maximum of items which may be present in bubbles display (like the user's picture view, the message text view...).
 To optimize bubbles rendering, we advise to define a .xib for each kind of bubble layout (with or without sender's information, with or without attachment...).
 Each inherited class should define only the actual displayed items.
 */
@interface MXKRoomBubbleTableViewCell : MXKTableViewCell <MXKCellRendering, UITextViewDelegate>
{
@protected
    /**
     The current bubble data displayed by the table view cell
     */
    MXKRoomBubbleCellData *bubbleData;
}

/**
 The current bubble data displayed by the table view cell
 */
@property (strong, nonatomic, readonly) MXKRoomBubbleCellData *bubbleData;

/**
 Option to highlight or not the content of message text view (May be used in case of text selection)
 */
@property (nonatomic) BOOL allTextHighlighted;

/**
 The default picture displayed when no picture is available.
 */
@property (nonatomic) UIImage *picturePlaceholder;

/**
 The read receipts alignment.
 By default, they are left aligned.
 */
@property (nonatomic) ReadReceiptsAlignment readReceiptsAlignment;

@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIView *userNameTapGestureMaskView;
@property (strong, nonatomic) IBOutlet MXKImageView *pictureView;
@property (weak, nonatomic) IBOutlet UITextView  *messageTextView;
@property (strong, nonatomic) IBOutlet MXKImageView *attachmentView;
@property (strong, nonatomic) IBOutlet UIImageView *playIconView;
@property (strong, nonatomic) IBOutlet UIImageView *fileTypeIconView;
@property (weak, nonatomic) IBOutlet UIView *bubbleInfoContainer;
@property (weak, nonatomic) IBOutlet UIView *bubbleOverlayContainer;

/**
 The container view in which the encryption information may be displayed
 */
@property (weak, nonatomic) IBOutlet UIView *encryptionStatusContainerView;

@property (weak, nonatomic) IBOutlet UIView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *statsLabel;
@property (weak, nonatomic) IBOutlet MXKPieChartView *progressChartView;

/**
 The constraints which defines the relationship between messageTextView and its superview.
 The defined constant are supposed >= 0.
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *msgTextViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *msgTextViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *msgTextViewLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *msgTextViewTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *msgTextViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *msgTextViewMinHeightConstraint;

/**
 The constraints which defines the relationship between attachmentView and its superview
 The defined constant are supposed >= 0.
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attachViewWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attachViewMinHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attachViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attachViewBottomConstraint;

/**
 The constraints which defines the relationship between bubbleInfoContainer and its superview
 The defined constant are supposed >= 0.
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bubbleInfoContainerTopConstraint;

- (void)startProgressUI;

- (void)updateProgressUI:(NSDictionary*)statisticsDict;

#pragma mark - Original Xib values

/**
 Get an original instance of the `MXKRoomBubbleTableViewCell` child class.

 @return an instance of the child class caller which has the original Xib values.
 */
+ (MXKRoomBubbleTableViewCell*)cellWithOriginalXib;

/**
 Disable the handling of the long press on event (see kMXKRoomBubbleCellLongPressOnEvent). NO by default.
 
 CAUTION: Changing this flag only impact the new created cells (existing 'MXKRoomBubbleTableViewCell' instances are unchanged).
 */
+ (void)disableLongPressGestureOnEvent:(BOOL)disable;

/**
 The `MXKRoomBubbleTableViewCell` orignal implementation of [MXKCellRendering render:] not
 overidden by a class child.

 @param cellData the data object to render.
 */
- (void)originalRender:(MXKCellData*)cellData;

/**
 The `MXKRoomBubbleTableViewCell` orignal implementation of [MXKCellRendering 
 originalHeightForCellData: withMaximumWidth:] not overidden by a class child.

 @param cellData the data object to render.
 @param maxWidth the maximum available width.
 @return the cell height
 */
+ (CGFloat)originalHeightForCellData:(MXKCellData*)cellData withMaximumWidth:(CGFloat)maxWidth;

/**
 Highlight text message related to a specific event in the displayed message.
 
 @param eventId the id of the event to highlight (use nil to cancel highlighting).
 */
- (void)highlightTextMessageForEvent:(NSString*)eventId;

/**
 The top position of an event in the cell.
 
 A cell can display several events. The method returns the vertical position of a given
 event in the cell.
 
 @return the y position (in pixel) of the event in the cell.
 */
- (CGFloat)topPositionOfEvent:(NSString*)eventId;

@end
