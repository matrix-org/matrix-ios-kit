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

#import "MXKRoomMemberListDataSource.h"

#import "MXKRoomMemberCellData.h"
#import "MXKRoomMemberTableViewCell.h"

#pragma mark - Constant definitions
NSString *const kMXKRoomMemberCellIdentifier = @"kMXKRoomMemberCellIdentifier";


@interface MXKRoomMemberListDataSource () {
    
    /**
     The room in which members are listed.
     */
    MXRoom *mxRoom;
    
    /**
     The members events listener.
     */
    id membersListener;

    /**
     The typing notification listener in the room.
     */
    id typingNotifListener;
}

@end

@implementation MXKRoomMemberListDataSource

- (instancetype)initWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)mxSession {
    self = [super initWithMatrixSession:mxSession];
    if (self) {

        _roomId = roomId;
        
        cellDataArray = [NSMutableArray array];
        filteredCellDataArray = nil;
        _sortMembersUsingLastSeenTime = YES;
        _hideLeftUsers = YES;
        
        // Set default data and view classes
        [self registerCellDataClass:MXKRoomMemberCellData.class forCellIdentifier:kMXKRoomMemberCellIdentifier];
        [self registerCellViewClass:MXKRoomMemberTableViewCell.class forCellIdentifier:kMXKRoomMemberCellIdentifier];
        
        [self didMXSessionStateChange];
    }
    return self;
}

- (void)destroy {
    cellDataArray = nil;
    filteredCellDataArray = nil;
    
    if (membersListener) {
        [self.mxSession removeListener:membersListener];
        membersListener = nil;
    }
    
    if (typingNotifListener) {
        [mxRoom removeListener:typingNotifListener];
        typingNotifListener = nil;
    }
    
    [super destroy];
}

- (void)didMXSessionStateChange {
    
    if (MXSessionStateStoreDataReady < self.mxSession.state) {
        
        // Check whether the room is not already set
        if (!mxRoom) {
            mxRoom = [self.mxSession roomWithRoomId:_roomId];
            if (mxRoom) {
                [self loadData];
                
                // Register on typing notif
                [self listenTypingNotifications];
                
                // Register on members events
                [self listenMembersEvents];
                
                // Update here data source state
                state = MXKDataSourceStateReady;
                
                // Notify delegate
                if (self.delegate) {
                    if ([self.delegate respondsToSelector:@selector(dataSource:didStateChange:)]) {
                        [self.delegate dataSource:self didStateChange:state];
                    }
                    [self.delegate dataSource:self didCellChange:nil];
                }
            }
            else {
                NSLog(@"[MXKRoomMemberDataSource] The user does not know the room %@", _roomId);
                
                // Update here data source state
                state = MXKDataSourceStateFailed;
                
                // Notify delegate
                if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)]) {
                    [self.delegate dataSource:self didStateChange:state];
                }
            }
        }
    }
}

- (void)searchWithPatterns:(NSArray*)patternsList {
    if (patternsList.count) {
        if (filteredCellDataArray) {
            [filteredCellDataArray removeAllObjects];
        } else {
            filteredCellDataArray = [NSMutableArray arrayWithCapacity:cellDataArray.count];
        }
        
        for (id<MXKRoomMemberCellDataStoring> cellData in cellDataArray) {
            for (NSString* pattern in patternsList) {
                if ([[cellData memberDisplayName] rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [filteredCellDataArray addObject:cellData];
                    break;
                }
            }
        }
    } else {
        filteredCellDataArray = nil;
    }
    
    if (self.delegate) {
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (id<MXKRoomMemberCellDataStoring>)cellDataAtIndex:(NSInteger)index {

    if (filteredCellDataArray) {
        return filteredCellDataArray[index];
    }
    return cellDataArray[index];
}

- (CGFloat)cellHeightAtIndex:(NSInteger)index {

    id<MXKRoomMemberCellDataStoring> cellData = [self cellDataAtIndex:index];

    Class<MXKCellRendering> class = [self cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier];
    return [class heightForCellData:cellData withMaximumWidth:0];
}

#pragma mark - Members processing

- (void)loadData {
    
    NSArray* membersList = [mxRoom.state members];
    
    if (_hideLeftUsers) {
        NSMutableArray* filteredMembers = [[NSMutableArray alloc] init];
        
        for (MXRoomMember* member in membersList) {
            if (member.membership != MXMembershipLeave) {
                [filteredMembers addObject:member];
            }
        }
        
        membersList = filteredMembers;
    }
    
    [cellDataArray removeAllObjects];
    
    // Retrieve the MXKCellData class to manage the data
    Class class = [self cellDataClassForCellIdentifier:kMXKRoomMemberCellIdentifier];
    NSAssert([class conformsToProtocol:@protocol(MXKRoomMemberCellDataStoring)], @"MXKRoomMemberListDataSource only manages MXKCellData that conforms to MXKRoomMemberCellDataStoring protocol");
    
    for (MXRoomMember *member in membersList) {
        
        id<MXKRoomMemberCellDataStoring> cellData = [[class alloc] initWithRoomMember:member roomState:mxRoom.state andRoomMemberListDataSource:self];
        if (cellData) {
            [cellDataArray addObject:cellData];
        }
    }
    
    [self sortMembers];
}

- (void)sortMembers {
    NSArray *sortedMembers = [cellDataArray sortedArrayUsingComparator:^NSComparisonResult(id<MXKRoomMemberCellDataStoring> member1, id<MXKRoomMemberCellDataStoring> member2) {
        
        // Move banned and left members at the end of the list
        if (member1.roomMember.membership == MXMembershipLeave || member1.roomMember.membership == MXMembershipBan) {
            if (member2.roomMember.membership != MXMembershipLeave && member2.roomMember.membership != MXMembershipBan) {
                return NSOrderedDescending;
            }
        } else if (member2.roomMember.membership == MXMembershipLeave || member2.roomMember.membership == MXMembershipBan) {
            return NSOrderedAscending;
        }
        
        // Move invited members just before left and banned members
        if (member1.roomMember.membership == MXMembershipInvite) {
            if (member2.roomMember.membership != MXMembershipInvite) {
                return NSOrderedDescending;
            }
        } else if (member2.roomMember.membership == MXMembershipInvite) {
            return NSOrderedAscending;
        }
        
        if (_sortMembersUsingLastSeenTime) {
            // Get the users that correspond to these members
            MXUser *user1 = [self.mxSession userWithUserId:member1.roomMember.userId];
            MXUser *user2 = [self.mxSession userWithUserId:member2.roomMember.userId];
            
            // Move users who are not online or unavailable at the end (before invited users)
            if ((user1.presence == MXPresenceOnline) || (user1.presence == MXPresenceUnavailable)) {
                if ((user2.presence != MXPresenceOnline) && (user2.presence != MXPresenceUnavailable)) {
                    return NSOrderedAscending;
                }
            } else if ((user2.presence == MXPresenceOnline) || (user2.presence == MXPresenceUnavailable)) {
                return NSOrderedDescending;
            } else {
                // Here both users are neither online nor unavailable (the lastActive ago is useless)
                // We will sort them according to their display, by keeping in front the offline users
                if (user1.presence == MXPresenceOffline) {
                    if (user2.presence != MXPresenceOffline) {
                        return NSOrderedAscending;
                    }
                } else if (user2.presence == MXPresenceOffline) {
                    return NSOrderedDescending;
                }
                return [[mxRoom.state memberSortedName:member1.roomMember.userId] compare:[mxRoom.state memberSortedName:member2.roomMember.userId] options:NSCaseInsensitiveSearch];
            }
            
            // Consider user's lastActive ago value
            if (user1.lastActiveAgo < user2.lastActiveAgo) {
                return NSOrderedAscending;
            } else if (user1.lastActiveAgo == user2.lastActiveAgo) {
                return [[mxRoom.state memberSortedName:member1.roomMember.userId] compare:[mxRoom.state memberSortedName:member2.roomMember.userId] options:NSCaseInsensitiveSearch];
            }
            return NSOrderedDescending;
        } else {
            // Move user without display name at the end (before invited users)
            if (member1.roomMember.displayname.length) {
                if (!member2.roomMember.displayname.length) {
                    return NSOrderedAscending;
                }
            } else if (member2.roomMember.displayname.length) {
                return NSOrderedDescending;
            }
            
            return [[mxRoom.state memberSortedName:member1.roomMember.userId] compare:[mxRoom.state memberSortedName:member2.roomMember.userId] options:NSCaseInsensitiveSearch];
        }
    }];
    
    cellDataArray = [NSMutableArray arrayWithArray:sortedMembers];
}

- (void)listenMembersEvents{
    
    // Remove the previous live listener
    if (membersListener) {
        [self.mxSession removeListener:membersListener];
    }
    
    // Register a listener for events that concern room members
    NSArray *mxMembersEvents = @[
                                 kMXEventTypeStringRoomMember,
                                 kMXEventTypeStringRoomPowerLevels,
                                 kMXEventTypeStringPresence
                                 ];
    membersListener = [self.mxSession listenToEventsOfTypes:mxMembersEvents onEvent:^(MXEvent *event, MXEventDirection direction, id customObject) {
        // consider only live event
        if (direction == MXEventDirectionForwards) {
            // Check the room Id (if any)
            if (event.roomId && [event.roomId isEqualToString:mxRoom.state.roomId] == NO) {
                // This event does not concern the current room members
                return;
            }
            
            // refresh the whole members list. TODO GFO refresh only the updated members.
            [self loadData];
            
            if (self.delegate) {
                [self.delegate dataSource:self didCellChange:nil];
            }
        }
    }];
}

- (void)listenTypingNotifications {
    
    // Remove the previous live listener
    if (typingNotifListener) {
        [mxRoom removeListener:typingNotifListener];
    }
    
    // Add typing notification listener
    typingNotifListener = [mxRoom listenToEventsOfTypes:@[kMXEventTypeStringTypingNotification] onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState) {
        
        // Handle only live events
        if (direction == MXEventDirectionForwards) {
            // Retrieve typing users list
            NSMutableArray *typingUsers = [NSMutableArray arrayWithArray:mxRoom.typingUsers];
            // Remove typing info for the current user
            NSUInteger index = [typingUsers indexOfObject:self.mxSession.myUser.userId];
            if (index != NSNotFound) {
                [typingUsers removeObjectAtIndex:index];
            }
            
            for (id<MXKRoomMemberCellDataStoring> cellData in cellDataArray) {
                if ([typingUsers indexOfObject:cellData.roomMember.userId] == NSNotFound) {
                    cellData.isTyping = NO;
                } else {
                    cellData.isTyping = YES;
                }
            }
            
            if (self.delegate) {
                [self.delegate dataSource:self didCellChange:nil];
            }
        }
    }];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if (filteredCellDataArray) {
        return filteredCellDataArray.count;
    }
    return cellDataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    id<MXKRoomMemberCellDataStoring> roomData = [self cellDataAtIndex:indexPath.row];

    MXKRoomMemberTableViewCell *cell  = [tableView dequeueReusableCellWithIdentifier:kMXKRoomMemberCellIdentifier forIndexPath:indexPath];

    // Make the bubble display the data
    [cell render:roomData];

    return cell;
}

@end
