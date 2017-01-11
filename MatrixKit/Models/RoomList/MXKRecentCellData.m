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

#import "MXKSessionRecentsDataSource.h"
#import "MXEvent+MatrixKit.h"

@interface MXKRecentCellData ()
{
    MXKSessionRecentsDataSource *recentsDataSource;
    
    // Keep reference on last event (used in case of redaction)
    MXEvent *lastEvent;
}

@end

@implementation MXKRecentCellData
@synthesize roomSummary, recentsDataSource, lastEvent, roomDisplayname, lastEventTextMessage, lastEventAttributedTextMessage, lastEventDate;

- (instancetype)initWithRoomSummary:(MXRoomSummary*)theRoomSummary andRecentListDataSource:(MXKSessionRecentsDataSource*)recentListDataSource
{
    self = [self init];
    if (self)
    {
        roomSummary = theRoomSummary;
        recentsDataSource = recentListDataSource;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:kMXRoomSummaryDidChangeNotification object:roomSummary];

        [self update];
    }
    return self;
}

- (void)update
{
    // @TODO: refactor the all thing to take benefit of MXKRoomSummary

    // Keep ref on displayed last event
    lastEvent = roomSummary.lastEvent;
    roomDisplayname = roomSummary.displayname;

    if (lastEvent)
    {
        lastEventDate = [recentsDataSource.eventFormatter dateStringFromEvent:lastEvent withTime:YES];

        // Compute the text message
        // @TODO: refactor
        MXKEventFormatterError error;
        lastEventTextMessage = [recentsDataSource.eventFormatter stringFromEvent:lastEvent withRoomState:roomSummary.room.state error:&error];

        // Store the potential error
        lastEvent.mxkEventFormatterError = error;
    }

    if (0 == lastEventTextMessage.length)
    {
        lastEventTextMessage = @"";
        lastEventAttributedTextMessage = [[NSAttributedString alloc] initWithString:@""];
    }
    else
    {
        // Check whether the sender name has to be added
        NSString *prefix = nil;

        if (lastEvent.eventType == MXEventTypeRoomMessage)
        {
            NSString *msgtype = lastEvent.content[@"msgtype"];
            if ([msgtype isEqualToString:kMXMessageTypeEmote] == NO)
            {
                // @TODO: refactor
                NSString *senderDisplayName = roomSummary.room.state ? [recentsDataSource.eventFormatter senderDisplayNameForEvent:lastEvent withRoomState:roomSummary.room.state] : lastEvent.sender;

                prefix = [NSString stringWithFormat:@"%@: ", senderDisplayName];
            }
        }

        // Compute the attribute text message
        lastEventAttributedTextMessage = [recentsDataSource.eventFormatter renderString:lastEventTextMessage withPrefix:prefix forEvent:lastEvent];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomSummaryDidChangeNotification object:roomSummary];
    roomSummary = nil;

    lastEvent = nil;
    lastEventTextMessage = nil;
    lastEventAttributedTextMessage = nil;
}

- (BOOL)hasUnread
{
    // @TODO
    //return roomDataSource.hasUnread;
    return NO;
}

- (NSUInteger)notificationCount
{
    // @TODO
    //return roomDataSource.notificationCount;
    return 0;
}

- (NSUInteger)highlightCount
{
    // @TODO
    //return roomDataSource.highlightCount;
    return 0;
}

- (void)markAllAsRead
{
    // @TODO
    //[roomDataSource markAllAsRead];
}

@end
