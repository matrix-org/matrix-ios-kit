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

#import "MXKRecentListDataSource.h"

#import "MXKRecentCellData.h"
#import "MXKRecentTableViewCell.h"

#import "MXKRoomDataSourceManager.h"

#pragma mark - Constant definitions
NSString *const kMXKRecentCellIdentifier = @"kMXKRecentCellIdentifier";


@interface MXKRecentListDataSource () {

    MXKRoomDataSourceManager *roomDataSourceManager;
}

@end

@implementation MXKRecentListDataSource

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession {
    self = [super initWithMatrixSession:matrixSession];
    if (self) {

        roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mxSession];

        cellDataArray = [NSMutableArray array];
        filteredCellDataArray = nil;

        // Set default data and view classes
        [self registerCellDataClass:MXKRecentCellData.class forCellIdentifier:kMXKRecentCellIdentifier];
        [self registerCellViewClass:MXKRecentTableViewCell.class forCellIdentifier:kMXKRecentCellIdentifier];

        // Set default MXEvent -> NSString formatter
        _eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:self.mxSession];
        _eventFormatter.isForSubtitle = YES;

        [self didMXSessionStateChange];

        // Listen to MXRoomDataSource
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRoomLastMessageChanged:) name:kMXKRoomDataSourceLastMessageChanged object:nil];

    }
    return self;
}

- (void)destroy {
    cellDataArray = nil;
    filteredCellDataArray = nil;
    
    _eventFormatter = nil;
    
    [super destroy];
}

- (void)didMXSessionStateChange {
    if (MXSessionStateStoreDataReady < self.mxSession.state && (0 == cellDataArray.count)) {
        [self loadData];
    }
}

- (void)searchWithPatterns:(NSArray*)patternsList {
    if (patternsList.count) {
        if (filteredCellDataArray) {
            [filteredCellDataArray removeAllObjects];
        } else {
            filteredCellDataArray = [NSMutableArray arrayWithCapacity:cellDataArray.count];
        }
        
        for (id<MXKRecentCellDataStoring> cellData in cellDataArray) {
            for (NSString* pattern in patternsList) {
                if ([[cellData.room.state displayname] rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [filteredCellDataArray addObject:cellData];
                    break;
                }
            }
        }
    } else {
        filteredCellDataArray = nil;
    }
    
    [self.delegate dataSource:self didCellChange:nil];
}

- (id<MXKRecentCellDataStoring>)cellDataAtIndex:(NSInteger)index {

    if (filteredCellDataArray) {
        return filteredCellDataArray[index];
    }
    return cellDataArray[index];
}

- (CGFloat)cellHeightAtIndex:(NSInteger)index {

    id<MXKRecentCellDataStoring> cellData = [self cellDataAtIndex:index];

    Class<MXKCellRendering> class = [self cellViewClassForCellIdentifier:kMXKRecentCellIdentifier];
    return [class heightForCellData:cellData withMaximumWidth:0];
}

//- (void)setEventsFilterForMessages:(NSArray *)eventsFilterForMessages {
//
//    // Remove the previous live listener
//    if (liveEventsListener) {
//        [self.mxSession removeListener:liveEventsListener];
//    }
//
//    // And register a new one with the requested filter
//    _eventsFilterForMessages = [eventsFilterForMessages copy];
//    liveEventsListener = [self.mxSession listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState) {
//        if (MXEventDirectionForwards == direction) {
//
//            // Check user's membership in live room state (We will remove left rooms from recents)
//            MXRoom *mxRoom = [self.mxSession roomWithRoomId:event.roomId];
//            BOOL isLeft = (mxRoom == nil || mxRoom.state.membership == MXMembershipLeave || mxRoom.state.membership == MXMembershipBan);
//
//            // Consider this new event as unread only if the sender is not the user and if the room is not visible
//            BOOL isUnread = (![event.userId isEqualToString:self.mxSession.matrixRestClient.credentials.userId]
//                             /* @TODO: Applicable at this low level? && ![[AppDelegate theDelegate].masterTabBarController.visibleRoomId isEqualToString:event.roomId]*/);
//
//            // Look for the room
//            BOOL isFound = NO;
//            for (NSUInteger index = 0; index < cellDataArray.count; index++) {
//                id<MXKRecentCellDataStoring> cellData = cellDataArray[index];
//                if ([event.roomId isEqualToString:cellData.room.state.roomId]) {
//                    isFound = YES;
//                    // Decrement here unreads count for this recent (we will add later the refreshed count)
//                    // @TODO unreadCount -= recentRoom.unreadCount;
//
//                    if (isLeft) {
//                        // Remove left room
//                        [cellDataArray removeObjectAtIndex:index];
//
//                        if (filteredCellDataArray) {
//                            NSUInteger filteredIndex = [filteredCellDataArray indexOfObject:cellData];
//                            if (filteredIndex != NSNotFound) {
//                                [filteredCellDataArray removeObjectAtIndex:filteredIndex];
//                            }
//                        }
//                    } else {
//                        if ([cellData updateWithLastEvent:event andRoomState:roomState markAsUnread:isUnread]) {
//                            if (index) {
//                                // Move this room at first position
//                                [cellDataArray removeObjectAtIndex:index];
//                                [cellDataArray insertObject:cellData atIndex:0];
//                            }
//                            // Update filtered recents (if any)
//                            if (filteredCellDataArray) {
//                                NSUInteger filteredIndex = [filteredCellDataArray indexOfObject:cellData];
//                                if (filteredIndex && filteredIndex != NSNotFound) {
//                                    [filteredCellDataArray removeObjectAtIndex:filteredIndex];
//                                    [filteredCellDataArray insertObject:cellData atIndex:0];
//                                }
//                            }
//                        }
//                        // Refresh global unreads count
//                        // @TODO unreadCount += recentRoom.unreadCount;
//                    }
//
//                    // Signal change
//                    if (self.delegate) {
//                        [self.delegate dataSource:self didCellChange:nil];
//                    }
//                    break;
//                }
//            }
//
//            if (!isFound && !isLeft) {
//                // Insert in first position this new room
//                Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];
//                id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithLastEvent:event andRoomState:mxRoom.state markAsUnread:isUnread andRecentListDataSource:self];
//                if (cellData) {
//
//                    [cellDataArray insertObject:cellData atIndex:0];
//
//                    // Signal change
//                    if (self.delegate) {
//                        [self.delegate dataSource:self didCellChange:nil];
//                    }
//                }
//            }
//        }
//    }];
//
//    [self loadData];
//}


#pragma mark - Events processing
- (void)loadData {

    // Reset the table
    [cellDataArray removeAllObjects];

    // Retrieve the MXKCellData class to manage the data
    Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];
    NSAssert([class conformsToProtocol:@protocol(MXKRecentCellDataStoring)], @"MXKRecentListDataSource only manages MXKCellData that conforms to MXKRecentCellDataStoring protocol");

    for (MXRoom *room in self.mxSession.rooms) {

        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:room.state.roomId create:YES];

        id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithLastEvent:roomDataSource.lastMessage
                                                                    andRoomState:room.state
                                                                    markAsUnread:NO
                                                         andRecentListDataSource:self];
        if (cellData) {
            [cellDataArray addObject:cellData];
        }
    }

    // Update here data source state if it is not already ready
    if (state != MXKDataSourceStateReady) {
        state = MXKDataSourceStateReady;
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)]) {
            [self.delegate dataSource:self didStateChange:state];
        }
    }

    // Order them by origin_server_ts
    [cellDataArray sortUsingComparator:^NSComparisonResult(id<MXKRecentCellDataStoring> cellData1, id<MXKRecentCellDataStoring> cellData2) {
        NSComparisonResult result = NSOrderedAscending;
        if (cellData2.lastEvent.originServerTs > cellData1.lastEvent.originServerTs) {
            result = NSOrderedDescending;
        } else if (cellData2.lastEvent.originServerTs == cellData1.lastEvent.originServerTs) {
            result = NSOrderedSame;
        }
        return result;
    }];

    [self.delegate dataSource:self didCellChange:nil];
}

- (void)didRoomLastMessageChanged:(NSNotification *)notif {

    MXKRoomDataSource *roomDataSource = notif.object;
    if (roomDataSource.mxSession == self.mxSession) {

        // For now, reload all data
        [self loadData];
    }
}


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if (filteredCellDataArray) {
        return filteredCellDataArray.count;
    }
    return cellDataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    id<MXKRecentCellDataStoring> roomData = [self cellDataAtIndex:indexPath.row];

    MXKRecentTableViewCell *cell  = [tableView dequeueReusableCellWithIdentifier:kMXKRecentCellIdentifier forIndexPath:indexPath];

    // Make the bubble display the data
    [cell render:roomData];

    return cell;
}

@end
