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
#import "MXKRecentListDataSource.h"

@interface MXKRecentCellData () {

    MXKRecentListDataSource *recentListDataSource;

    // Keep reference on last event (used in case of redaction)
    MXEvent *lastEvent;
}

@end

@implementation MXKRecentCellData
@synthesize roomDataSource, lastEvent, roomDisplayname, lastEventDescription, lastEventDate, unreadCount, containsBingUnread;

- (instancetype)initWithRoomDataSource:(MXKRoomDataSource *)roomDataSource2 andRecentListDataSource:(MXKRecentListDataSource *)recentListDataSource2 {

    self = [self init];
    if (self) {
        roomDataSource = roomDataSource2;
        recentListDataSource = recentListDataSource2;

        [self update];
    }
    return self;
}

- (void)update {

//    lastEvent = event;
//    roomDisplayname = room.state.displayname;
//
//    // Check whether the description of the provided event is not empty
//    MXKEventFormatterError error;
//    NSString *description = [recentListDataSource.eventFormatter stringFromEvent:event withRoomState:roomState error:&error];
//
//    if (description.length) {
//        // Update current last event
//        lastEvent = event;
//        lastEventDescription = description;
//        lastEventDate = [recentListDataSource.eventFormatter dateStringForEvent:event];
//        if (isUnread) {
//            unreadCount ++;
//            containsBingUnread = (containsBingUnread || (!event.isState && !event.redactedBecause && NO /*[mxHandler containsBingWord:_lastEventDescription] @TODO*/));
//        }
//        return YES;
//    } else if (lastEventDescription.length) {
//        // Here we tried to update the last event with a new live one, but the description of this new one is empty.
//        // Consider the specific case of redaction event
//        if (event.eventType == MXEventTypeRoomRedaction) {
//            // Check whether the redacted event is the current last event
//            if ([event.redacts isEqualToString:lastEvent.eventId]) {
//                // Update last event description
//                MXEvent *redactedEvent = [lastEvent prune];
//                redactedEvent.redactedBecause = event.originalDictionary;
//
//                return YES;
//            }
//        }
//    }
//    return NO;

    // @TODO: Do some cleaning: following code seems duplicating what updateWithLastEvent: does
    //unreadCount = isUnread ? 1 : 0;

    lastEvent = roomDataSource.lastMessage;
    roomDisplayname = roomDataSource.room.state.displayname;

    MXKEventFormatterError error;
    lastEventDescription = [recentListDataSource.eventFormatter stringFromEvent:lastEvent withRoomState:roomDataSource.room.state error:&error];
    lastEventDate = [recentListDataSource.eventFormatter dateStringForEvent:lastEvent];

    // In case of unread, check whether the last event description contains bing words
    //containsBingUnread = (!event.isState && !event.redactedBecause && NO /*[mxHandler containsBingWord:_lastEventDescription] @TODO*/);

    // Keep ref on event
    lastEvent = roomDataSource.lastMessage;
}

- (void)resetUnreadCount {
    unreadCount = 0;
    containsBingUnread = NO;
}


- (void)dealloc {
    lastEvent = nil;
    lastEventDescription = nil;
}

@end
