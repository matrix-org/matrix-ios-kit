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

#import "MXKRoomBubbleComponent.h"

#import "MXEvent+MatrixKit.h"

@implementation MXKRoomBubbleComponent

- (instancetype)initWithEvent:(MXEvent*)event andRoomState:(MXRoomState*)roomState andEventFormatter:(MXKEventFormatter*)formatter
{
    if (self = [super init])
    {
        // Build text component related to this event
        _eventFormatter = formatter;
        MXKEventFormatterError error;

        NSAttributedString *eventString = [_eventFormatter attributedStringFromEvent:event withRoomState:roomState error:&error];
        
        // Store the potential error
        event.mxkEventFormatterError = error;
        
        _textMessage = nil;
        _attributedTextMessage = eventString;
        
        // Set date time
        if (event.originServerTs != kMXUndefinedTimestamp)
        {
            _date = [NSDate dateWithTimeIntervalSince1970:(double)event.originServerTs/1000];
        }
        else
        {
            _date = nil;
        }
        
        // Keep ref on event (used to handle the read marker, or a potential event redaction).
        _event = event;

        _displayFix = MXKRoomBubbleComponentDisplayFixNone;
        if ([event.content[@"format"] isEqualToString:kMXRoomMessageFormatHTML])
        {
            if ([((NSString*)event.content[@"formatted_body"]) containsString:@"<blockquote"])
            {
                _displayFix |= MXKRoomBubbleComponentDisplayFixHtmlBlockquote;
            }
        }
    }
    return self;
}

- (void)dealloc
{
}

- (void)updateWithEvent:(MXEvent*)event andRoomState:(MXRoomState*)roomState
{
    // Report the new event
    _event = event;

    if (_event.isRedactedEvent)
    {
        // Do not use the live room state for redacted events as they occured in the past
        // Note: as we don't have valid room state in this case, userId will be used as display name
        roomState = nil;
    }
    // Other calls to updateWithEvent are made to update the state of an event (ex: MXKEventStateSending to MXKEventStateDefault).
    // They occur in live so we can use the room up-to-date state without making huge errors

    _textMessage = nil;

    MXKEventFormatterError error;
    _attributedTextMessage = [_eventFormatter attributedStringFromEvent:event withRoomState:roomState error:&error];
}

- (NSString *)textMessage
{
    if (!_textMessage)
    {
        _textMessage = _attributedTextMessage.string;
    }
    return _textMessage;
}

@end

