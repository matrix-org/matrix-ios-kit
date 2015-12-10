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

#import "MXKAppSettings.h"

/**
 Formatting result codes.
 */
typedef enum : NSUInteger {

    /**
     The formatting was successful.
     */
    MXKEventFormatterErrorNone,

    /**
     The formatter knows the event type but it encountered data that it does not support.
     */
    MXKEventFormatterErrorUnsupported,

    /**
     The formatter encountered unexpected data in the event.
     */
    MXKEventFormatterErrorUnexpected,

    /**
     The formatter does not support the type of the passed event.
     */
    MXKEventFormatterErrorUnknownEventType

} MXKEventFormatterError;

/**
 `MXKEventFormatter` is an utility class for formating Matrix events into strings which
 will be displayed to the end user.
 */
@interface MXKEventFormatter : NSObject
{
@protected
    /**
     The date formatter used to build date string without time information.
     */
    NSDateFormatter *dateFormatter;
    
    /**
     The time formatter used to build time string without date information.
     */
    NSDateFormatter *timeFormatter;
}

/**
 The settings used to handle room events.
 
 By default the shared application settings are considered.
 */
@property (nonatomic) MXKAppSettings *settings;

/**
 Flag indicating if the formatter must build strings that will be displayed as subtitle.
 Default is NO.
 */
@property (nonatomic) BOOL isForSubtitle;

/**
 Initialise the event formatter.

 @param mxSession the Matrix to retrieve contextual data.
 @return the newly created instance.
 */
- (instancetype)initWithMatrixSession:(MXSession*)mxSession;

/**
 Initialise the date and time formatters.
 This formatter could require to be updated after updating the device settings.
 e.g the time format switches from 24H format to AM/PM.
 */
- (void)initDateTimeFormatters;

/**
 Checks whether the event is related to an attachment and if it is supported.

 @param event
 @return YES if the provided event is related to a supported attachment type.
 */
- (BOOL)isSupportedAttachment:(MXEvent*)event;

#pragma mark - Events to strings conversion methods
/**
 Compose the event sender display name according to the current room state.
 
 @param event the event to format.
 @param roomState the room state right before the event.
 @return the sender display name
 */
- (NSString*)senderDisplayNameForEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState;

/**
 Retrieve the avatar url of the event sender from the current room state.
 
 @param event the event to format.
 @param roomState the room state right before the event.
 @return the sender avatar url
 */
- (NSString*)senderAvatarUrlForEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState;

/**
 Generate a displayable string representating the event.
 
 @param event the event to format.
 @param roomState the room state right before the event.
 @param error the error code. In case of formatting error, the formatter may return non nil string as a proposal.
 @return the display text for the event.
 */
- (NSString*)stringFromEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState error:(MXKEventFormatterError*)error;

/**
 Return attributed string for the displayable string representing the event.
 
 @param text pre-computed text representation of the event
 @param event the event.
 @return NSAttributedString for displaying the event.
 */
- (NSAttributedString *)attributedStringFromString:(NSString *)text forEvent:(MXEvent*)event;

#pragma mark - Fake event objects creation
- (MXEvent*)fakeRoomMessageEventForRoomId:(NSString*)roomId withEventId:(NSString*)eventId andContent:(NSDictionary*)content;


#pragma mark - Timestamp formatting

/**
 Generate the date in string format corresponding to the date.
 
 @param date The date.
 @param time The flag used to know if the returned string must include time information or not.
 @return the string representation of the date.
 */
- (NSString*)dateStringFromDate:(NSDate *)date withTime:(BOOL)time;

/**
 Generate the date in string format corresponding to the timestamp.
 The returned string is localised according to the current device settings.

 @param timestamp The timestamp in milliseconds since Epoch.
 @param time The flag used to know if the returned string must include time information or not.
 @return the string representation of the date.
 */
- (NSString*)dateStringFromTimestamp:(uint64_t)timestamp withTime:(BOOL)time;

/**
 Generate the date in string format corresponding to the event.
 The returned string is localised according to the current device settings.
 
 @param event The event to format.
 @param time The flag used to know if the returned string must include time information or not.
 @return the string representation of the event date.
 */
- (NSString*)dateStringFromEvent:(MXEvent*)event withTime:(BOOL)time;

/**
 Generate the time string of the provided date by considered the current system time formatting.
 
 @param date The date.
 @return the string representation of the time component of the date.
 */
- (NSString*)timeStringFromDate:(NSDate *)date;


# pragma mark - Customisation
/**
 Default color used to display text content of event.
 Default is [UIColor blackColor].
 */
@property (nonatomic) UIColor *defaultTextColor;

/**
 Default color used to display text content of event when it is displayed as subtitle (related to 'isForSubtitle' property).
 Default is [UIColor blackColor].
 */
@property (nonatomic) UIColor *subTitleTextColor;

/**
 Color used when the event must be bing to the end user. This happens when the event
 matches the user's push rules.
 Default is [UIColor blueColor].
 */
@property (nonatomic) UIColor *bingTextColor;

/**
 Color used to display text content of an event being sent.
 Default is [UIColor lightGrayColor].
 */
@property (nonatomic) UIColor *sendingTextColor;

/**
 Color used to display error text.
 Default is red.
 */
@property (nonatomic) UIColor *errorTextColor;

@end
