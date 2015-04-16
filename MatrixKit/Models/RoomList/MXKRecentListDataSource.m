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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRoomInformationChanged:) name:kMXKRoomDataSourceMetaDataChanged object:nil];
    }
    return self;
}

- (void)destroy {

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKRoomDataSourceMetaDataChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionNewRoomNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionLeftRoomNotification object:nil];

    cellDataArray = nil;
    filteredCellDataArray = nil;
    
    _eventFormatter = nil;
    
    [super destroy];
}

- (void)didMXSessionStateChange {
    if (MXSessionStateStoreDataReady <= self.mxSession.state && (0 == cellDataArray.count)) {
        [self loadData];
    }
}

- (NSUInteger)unreadCount {

    NSUInteger unreadCount = 0;

    // Sum unreadCount of all current cells
    // Use numberOfRowsInSection methods so that we take benefit of the filtering
    for (NSUInteger i = 0; i < [self tableView:nil numberOfRowsInSection:0]; i++) {

        id<MXKRecentCellDataStoring> cellData = [self cellDataAtIndex:i];
        unreadCount += cellData.unreadCount;
    }
    return unreadCount;
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
                if ([[cellData.roomDataSource.room.state displayname] rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
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


#pragma mark - Events processing
- (void)loadData {

    // Reset the table
    [cellDataArray removeAllObjects];

    // Retrieve the MXKCellData class to manage the data
    Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];
    NSAssert([class conformsToProtocol:@protocol(MXKRecentCellDataStoring)], @"MXKRecentListDataSource only manages MXKCellData that conforms to MXKRecentCellDataStoring protocol");

    for (MXRoom *room in self.mxSession.rooms) {

        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:room.state.roomId create:YES];

        id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithRoomDataSource:roomDataSource andRecentListDataSource:self];
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
    [self sortCellData];

    // Listen to MXSession rooms count changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXSessionHaveNewRoom:) name:kMXSessionNewRoomNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXSessionLeaveRoom:) name:kMXSessionLeftRoomNotification object:nil];

}

- (void)didRoomInformationChanged:(NSNotification *)notif {

    MXKRoomDataSource *roomDataSource = notif.object;
    if (roomDataSource.mxSession == self.mxSession) {

        // Retrieve the corresponding cell data
        id<MXKRecentCellDataStoring> theRoomData;
        for (id<MXKRecentCellDataStoring> roomData in cellDataArray) {
            if (roomData.roomDataSource == roomDataSource) {
                theRoomData = roomData;
                break;
            }
        }

        // And update it
        if (theRoomData) {
            [theRoomData update];
            [self sortCellData];
        }
        else {
            NSLog(@"[MXKRecentListDataSource] didRoomLastMessageChanged: Cannot find the changed room data source");
        }
    }
}

- (void)didMXSessionHaveNewRoom:(NSNotification *)notif {
    MXSession *mxSession = notif.object;
    if (mxSession == self.mxSession) {
        NSString *roomId = notif.userInfo[@"roomId"];

        // Add the room if there is not yet a cell for it
        id<MXKRecentCellDataStoring> roomData = [self cellDataWithRoomId:roomId];
        if (nil == roomData) {

            NSLog(@"MXKRecentListDataSource] Add newly joined room: %@", roomId);

            // Retrieve the MXKCellData class to manage the data
            Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];

            MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:roomId create:YES];
            id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithRoomDataSource:roomDataSource andRecentListDataSource:self];
            if (cellData) {

                [cellDataArray addObject:cellData];
                [self sortCellData];
            }
        }
    }
}

- (void)didMXSessionLeaveRoom:(NSNotification *)notif {

    MXSession *mxSession = notif.object;
    if (mxSession == self.mxSession) {

        NSString *roomId = notif.userInfo[@"roomId"];
        id<MXKRecentCellDataStoring> roomData = [self cellDataWithRoomId:roomId];

        if (roomData) {

            NSLog(@"MXKRecentListDataSource] Remove left room: %@", roomId);

            [cellDataArray removeObject:roomData];
            [self sortCellData];
        }
    }
}

// Order cells
- (void)sortCellData {

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

    // And inform the delegate about the update
    [self.delegate dataSource:self didCellChange:nil];
}


// Find the cell data that stores information about the given room id
- (id<MXKRecentCellDataStoring>)cellDataWithRoomId:(NSString*)roomId {

    id<MXKRecentCellDataStoring> theRoomData;
    for (id<MXKRecentCellDataStoring> roomData in cellDataArray) {
        if ([roomData.roomDataSource.roomId isEqualToString:roomId]) {
            theRoomData = roomData;
            break;
        }
    }
    return theRoomData;
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
