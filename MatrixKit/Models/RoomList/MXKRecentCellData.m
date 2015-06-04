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

#import "MXKRecentCellData.h"

#import "MXKRoomDataSource.h"
#import "MXKSessionRecentsDataSource.h"

@interface MXKRecentCellData ()
{
    
    MXKSessionRecentsDataSource *recentsDataSource;
    
    // Keep reference on last event (used in case of redaction)
    MXEvent *lastEvent;
}

@end

@implementation MXKRecentCellData
@synthesize roomDataSource, lastEvent, roomDisplayname, lastEventTextMessage, lastEventAttributedTextMessage, lastEventDate;

- (instancetype)initWithRoomDataSource:(MXKRoomDataSource *)roomDataSource2 andRecentListDataSource:(MXKSessionRecentsDataSource *)recentsDataSource2
{
    
    self = [self init];
    if (self)
    {
        roomDataSource = roomDataSource2;
        recentsDataSource = recentsDataSource2;
        
        [self update];
    }
    return self;
}

- (void)update
{
    
    lastEvent = roomDataSource.lastMessage;
    roomDisplayname = roomDataSource.room.state.displayname;
    lastEventDate = [recentsDataSource.eventFormatter dateStringForEvent:lastEvent];
    
    // Compute the text message
    MXKEventFormatterError error;
    lastEventTextMessage = [recentsDataSource.eventFormatter stringFromEvent:lastEvent withRoomState:roomDataSource.room.state error:&error];
    
    // Manage error
    if (error != MXKEventFormatterErrorNone)
    {
        switch (error)
        {
            case MXKEventFormatterErrorUnsupported:
                lastEvent.mxkState = MXKEventStateUnsupported;
                break;
            case MXKEventFormatterErrorUnexpected:
                lastEvent.mxkState = MXKEventStateUnexpected;
                break;
            case MXKEventFormatterErrorUnknownEventType:
                lastEvent.mxkState = MXKEventStateUnknownType;
                break;
                
            default:
                break;
        }
    }
    
    if (0 == lastEventTextMessage.length)
    {
        lastEventTextMessage = @"";
        
        // Trigger a back pagination to retrieve the actual last message
        [roomDataSource paginateBackMessages:5 success:nil failure:nil];
    }
    
    // Compute the attribute text message
    NSDictionary *attributes = [recentsDataSource.eventFormatter stringAttributesForEvent:lastEvent];
    if (attributes)
    {
        lastEventAttributedTextMessage = [[NSAttributedString alloc] initWithString:lastEventTextMessage attributes:attributes];
    }
    else
    {
        lastEventAttributedTextMessage = [[NSAttributedString alloc] initWithString:lastEventTextMessage];
    }
    
    // Keep ref on event
    lastEvent = roomDataSource.lastMessage;
}

- (void)dealloc
{
    lastEvent = nil;
    lastEventTextMessage = nil;
    lastEventAttributedTextMessage = nil;
}

- (NSUInteger)unreadCount
{
    return roomDataSource.unreadCount;
}

- (NSUInteger)unreadBingCount
{
    return (0 < roomDataSource.unreadBingCount);
}

@end
