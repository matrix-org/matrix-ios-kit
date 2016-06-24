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
        if (eventString.length)
        {
            // Manage error
            if (error != MXKEventFormatterErrorNone)
            {
                switch (error)
                {
                    case MXKEventFormatterErrorUnsupported:
                        event.mxkState = MXKEventStateUnsupported;
                        break;
                    case MXKEventFormatterErrorUnexpected:
                        event.mxkState = MXKEventStateUnexpected;
                        break;
                    case MXKEventFormatterErrorUnknownEventType:
                        event.mxkState = MXKEventStateUnknownType;
                        break;

                    default:
                        break;
                }
            }

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
            
            // Keep ref on event (used in case of redaction)
            _event = event;
        }
        else
        {
            // Ignore this event
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
}

- (void)updateWithEvent:(MXEvent*)event
{
    // Report the new event
    _event = event;
    
    // Reseting `attributedTextMessage` is enough to take into account the new event state
    // as it is only a font color change, there is no need to update `textMessage`
    // (Actually, we are unable to recompute `textMessage` as we do not have the room state)
    _attributedTextMessage = nil;
    
    // text message must be updated here in case of redaction, or for media attachment (see body update during video upload) 
    if (_event.isRedactedEvent || _event.isMediaAttachment)
    {
        // Build text component related to this event (Note: we don't have valid room state here, userId will be used as display name)
        MXKEventFormatterError error;
        _textMessage = [_eventFormatter stringFromEvent:event withRoomState:nil error:&error];
    }
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

