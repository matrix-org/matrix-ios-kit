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

#import <Foundation/Foundation.h>
#import <MatrixSDK/MatrixSDK.h>

#import "MXKRoomDataSource.h"

#import "MXKAttachment.h"

#import "MXEvent+MatrixKit.h"

@class MXKRoomDataSource;
/**
 `MXKRoomBubbleCellDataStoring` defines a protocol a class must conform in order to store MXKRoomBubble cell data
 managed by `MXKRoomDataSource`.
 */
@protocol MXKRoomBubbleCellDataStoring <NSObject>

#pragma mark - Data displayed by a room bubble cell

/**
 The sender Id
 */
@property (nonatomic) NSString *senderId;

/**
 The room id
 */
@property (nonatomic) NSString *roomId;

/**
 The sender display name composed when event occured
 */
@property (nonatomic) NSString *senderDisplayName;

/**
 The sender avatar url retrieved when event occured
 */
@property (nonatomic) NSString *senderAvatarUrl;

/**
 The sender avatar placeholder (may be nil) - Used when url is nil, or during avatar download.
 */
@property (nonatomic) UIImage *senderAvatarPlaceholder;

/**
 Tell whether a new pagination starts with this bubble.
 */
@property (nonatomic) BOOL isPaginationFirstBubble;

/**
 Tell whether the sender information is relevant for this bubble
 (For example this information should be hidden in case of 2 consecutive bubbles from the same sender).
 */
@property (nonatomic) BOOL shouldHideSenderInformation;

/**
 The list of events (`MXEvent` instances) handled by this bubble.
 */
@property (nonatomic, readonly) NSArray *events;

/**
 The bubble attachment (if any).
 */
@property (nonatomic) MXKAttachment *attachment;

/**
 The bubble date
 */
@property (nonatomic) NSDate *date;

/**
 YES when the bubble is composed by incoming event(s).
 */
@property (nonatomic) BOOL isIncoming;

/**
 YES when the bubble correspond to an attachment displayed with a thumbnail (see image, video).
 */
@property (nonatomic) BOOL isAttachmentWithThumbnail;

/**
 YES when the bubble correspond to an attachment displayed with an icon (audio, file...).
 */
@property (nonatomic) BOOL isAttachmentWithIcon;

/**
 The raw text message (without attributes)
 */
@property (nonatomic) NSString *textMessage;

/**
 The body of the message with sets of attributes, or kind of content description in case of attachment (e.g. "image attachment")
 */
@property (nonatomic) NSAttributedString *attributedTextMessage;

/**
 Tell whether the sender's name is relevant or not for this bubble.
 Return YES if the first component of the bubble message corresponds to an emote, or a state event in which
 the sender's name appears at the beginning of the message text (for example membership events).
 */
@property (nonatomic) BOOL shouldHideSenderName;

/**
 YES if the sender is currently typing in the current room
 */
@property (nonatomic) BOOL isTyping;

/**
 Show the date time label in rendered bubble cell. NO by default.
 */
@property (nonatomic) BOOL showBubbleDateTime;

/**
 A Boolean value that determines whether the date time labels are customized (By default date time display is handled by MatrixKit). NO by default.
 */
@property (nonatomic) BOOL useCustomDateTimeLabel;

/**
 Show the receipts in rendered bubble cell. YES by default.
 */
@property (nonatomic) BOOL showBubbleReceipts;

/**
 A Boolean value that determines whether the read receipts are customized (By default read receipts display is handled by MatrixKit). NO by default.
 */
@property (nonatomic) BOOL useCustomReceipts;

/**
 A Boolean value that determines whether the unsent button is customized (By default an 'Unsent' button is displayed by MatrixKit in front of unsent events). NO by default.
 */
@property (nonatomic) BOOL useCustomUnsentButton;

#pragma mark - Public methods
/**
 Create a new `MXKRoomBubbleCellDataStoring` object for a new bubble cell.
 
 @param event the event to be displayed in the cell.
 @param roomState the room state when the event occured.
 @param roomDataSource the `MXKRoomDataSource` object that will use this instance.
 @return the newly created instance.
 */
- (instancetype)initWithEvent:(MXEvent*)event andRoomState:(MXRoomState*)roomState andRoomDataSource:(MXKRoomDataSource*)roomDataSource;

/**
Update the event because its mxkState changed or it is has been redacted.
 
 @param eventId the id of the event to change.
 @param the new event data
 @return the number of events hosting by the object after the update.
 */
- (NSUInteger)updateEvent:(NSString*)eventId withEvent:(MXEvent*)event;

/**
 Remove the event from the `MXKRoomBubbleCellDataStoring` object.

 @param eventId the id of the event to remove.
 @return the number of events still hosting by the object after the removal
 */
- (NSUInteger)removeEvent:(NSString*)eventId;

/**
 Remove the passed event and all events after it.

 @param eventId the id of the event where to start removing.
 @param removedEvents removedEvents will contain the list of removed events.
 @return the number of events still hosting by the object after the removal.
 */
- (NSUInteger)removeEventsFromEvent:(NSString*)eventId removedEvents:(NSArray<MXEvent*>**)removedEvents;

/**
 Check if the receiver has the same sender as another bubble.
 
 @param bubbleCellData an object conforms to `MXKRoomBubbleCellDataStoring` protocol.
 @return YES if the receiver has the same sender as the provided bubble
 */
- (BOOL)hasSameSenderAsBubbleCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData;

/**
 Highlight text message of an event in the resulting message body.
 
 @param eventId the id of the event to highlight.
 @param tintColor optional tint color
 @return The body of the message by highlighting the content related to the provided event id
 */
- (NSAttributedString*)attributedTextMessageWithHighlightedEvent:(NSString*)eventId tintColor:(UIColor*)tintColor;

/**
 Highlight all the occurrences of a pattern in the resulting message body 'attributedTextMessage'.
 
 @param pattern the text pattern to highlight.
 @param patternColor optional text color (the pattern text color is unchanged if nil).
 @param patternFont optional text font (the pattern font is unchanged if nil).
 */
- (void)highlightPatternInTextMessage:(NSString*)pattern withForegroundColor:(UIColor*)patternColor andFont:(UIFont*)patternFont;

@optional
/**
 Attempt to add a new event to the bubble.
 
 @param event the event to be displayed in the cell.
 @param roomState the room state when the event occured.
 @return YES if the model accepts that the event can concatenated to events already in the bubble.
 */
- (BOOL)addEvent:(MXEvent*)event andRoomState:(MXRoomState*)roomState;

/**
 The receiver appends to its content the provided bubble cell data, if both have the same sender.
 
 @param bubbleCellData an object conforms to `MXKRoomBubbleCellDataStoring` protocol.
 @return YES if the provided cell data has been merged into receiver.
 */
- (BOOL)mergeWithBubbleCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData;


@end
