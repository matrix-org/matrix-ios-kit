/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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

#import "MXKDataSource.h"
#import "MXEvent+MatrixKit.h"

@implementation MXKRecentCellData
@synthesize roomSummary, dataSource, roomDisplayname, lastEventTextMessage, lastEventAttributedTextMessage, lastEventDate;

- (instancetype)initWithRoomSummary:(id<MXRoomSummaryProtocol>)theRoomSummary
                         dataSource:(MXKDataSource*)theDataSource;
{
    self = [self init];
    if (self)
    {
        roomSummary = theRoomSummary;
        dataSource = theDataSource;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:kMXRoomSummaryDidChangeNotification object:roomSummary];

        [self update];
    }
    return self;
}

- (void)update
{
    // Keep ref on displayed last event
    roomDisplayname = roomSummary.displayname;

    lastEventTextMessage = roomSummary.lastMessage.text;
    lastEventAttributedTextMessage = roomSummary.lastMessage.attributedText;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomSummaryDidChangeNotification object:roomSummary];
    roomSummary = nil;

    lastEventTextMessage = nil;
    lastEventAttributedTextMessage = nil;
}

- (MXSession *)mxSession
{
    return dataSource.mxSession;
}

- (NSString*)lastEventDate
{
    return (NSString*)roomSummary.lastMessage.others[@"lastEventDate"];
}

- (BOOL)hasUnread
{
    return (roomSummary.localUnreadEventCount != 0);
}

- (NSString *)roomDisplayname
{
    return roomSummary.displayname;
}

- (NSUInteger)notificationCount
{
    return roomSummary.notificationCount;
}

- (NSUInteger)highlightCount
{
    return roomSummary.highlightCount;
}

- (NSString*)notificationCountStringValue
{
    return [NSString stringWithFormat:@"%tu", self.notificationCount];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@: %@ - %@", super.description, self.roomSummary.roomId, self.roomDisplayname, self.lastEventTextMessage];
}

@end
