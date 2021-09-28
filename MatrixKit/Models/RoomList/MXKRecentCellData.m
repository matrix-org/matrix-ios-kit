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
#import <MatrixSDK/MatrixSDK-Swift.h>

@implementation MXKRecentCellData
@synthesize roomSummary, spaceChildInfo, dataSource, roomDisplayname, lastEventTextMessage, lastEventAttributedTextMessage, lastEventDate;

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

- (instancetype)initWithSpaceChildInfo:(MXSpaceChildInfo*)theSpaceChildInfo dataSource:(MXKDataSource*)theDataSource;
{
    self = [self init];
    if (self)
    {
        spaceChildInfo = theSpaceChildInfo;
        dataSource = theDataSource;

        [self update];
    }
    return self;
}

- (void)update
{
    // Keep ref on displayed last event
    roomDisplayname = spaceChildInfo ? spaceChildInfo.name : roomSummary.displayname;

    lastEventTextMessage = spaceChildInfo ? spaceChildInfo.topic : roomSummary.lastMessage.text;
    lastEventAttributedTextMessage = spaceChildInfo ? nil : roomSummary.lastMessage.attributedText;
}

- (void)dealloc
{
    if (roomSummary)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomSummaryDidChangeNotification object:roomSummary];
    }
    roomSummary = nil;
    spaceChildInfo = nil;

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

- (NSString *)roomIdentifier
{
    if (self.isSuggestedRoom)
    {
        return self.spaceChildInfo.name;
    }
    return roomSummary.roomId;
}

- (NSString *)roomDisplayname
{
    if (self.isSuggestedRoom)
    {
        return self.spaceChildInfo.displayName;
    }
    return roomSummary.displayname;
}

- (NSString *)avatarUrl
{
    if (self.isSuggestedRoom)
    {
        return self.spaceChildInfo.avatarUrl;
    }
    return roomSummary.avatar;
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

- (BOOL)isSuggestedRoom
{
    // As off now, we only store MXSpaceChildInfo in case of suggested rooms
    return self.spaceChildInfo != nil;
}

@end
