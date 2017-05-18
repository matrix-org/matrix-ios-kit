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

#import "MXKSessionRecentsDataSource.h"

#import "MXKRoomDataSourceManager.h"

#pragma mark - Constant definitions
NSString *const kMXKRecentCellIdentifier = @"kMXKRecentCellIdentifier";


@interface MXKSessionRecentsDataSource ()
{
    MXKRoomDataSourceManager *roomDataSourceManager;
    
    /**
     Internal array used to regulate change notifications.
     Cell data changes are stored instantly in this array.
     These changes are reported to the delegate only if no server sync is in progress.
     */
    NSMutableArray *internalCellDataArray;

    /**
     Store the current search patterns list.
     */
    NSArray* searchPatternsList;
}

@end

@implementation MXKSessionRecentsDataSource

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    self = [super initWithMatrixSession:matrixSession];
    if (self)
    {
        roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mxSession];
        
        internalCellDataArray = [NSMutableArray array];
        filteredCellDataArray = nil;
        
        // Set default data and view classes
        [self registerCellDataClass:MXKRecentCellData.class forCellIdentifier:kMXKRecentCellIdentifier];
    }
    return self;
}

- (void)destroy
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomSummaryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionNewRoomNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDidLeaveRoomNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDirectRoomsDidChangeNotification object:nil];
    
    cellDataArray = nil;
    internalCellDataArray = nil;
    filteredCellDataArray = nil;
    
    searchPatternsList = nil;
    
    [super destroy];
}

- (void)didMXSessionStateChange
{
    if (MXSessionStateStoreDataReady <= self.mxSession.state)
    {
        // Check whether some data have been already load
        if (0 == internalCellDataArray.count)
        {
            [self loadData];
        }
        else if (!roomDataSourceManager.isServerSyncInProgress)
        {
            // Sort cell data and notify the delegate
            [self sortCellDataAndNotifyChanges];
        }
    }
}

#pragma mark -

- (NSInteger)numberOfCells
{
    if (filteredCellDataArray)
    {
        return filteredCellDataArray.count;
    }
    return cellDataArray.count;
}

- (BOOL)hasUnread
{
    // Check all current cells
    // Use numberOfRowsInSection methods so that we take benefit of the filtering
    for (NSUInteger i = 0; i < self.numberOfCells; i++)
    {
        id<MXKRecentCellDataStoring> cellData = [self cellDataAtIndex:i];
        if (cellData.hasUnread)
        {
            return YES;
        }
    }
    return NO;
}

- (void)markAllAsRead
{
    // Clear unread count on all recent cells
    for (NSUInteger i = 0; i < self.numberOfCells; i++)
    {
        id<MXKRecentCellDataStoring> cellData = [self cellDataAtIndex:i];
        [cellData markAllAsRead];
    }
}

- (void)searchWithPatterns:(NSArray*)patternsList
{
    if (patternsList.count)
    {
        searchPatternsList = patternsList;
        
        if (filteredCellDataArray)
        {
            [filteredCellDataArray removeAllObjects];
        }
        else
        {
            filteredCellDataArray = [NSMutableArray arrayWithCapacity:cellDataArray.count];
        }
        
        for (id<MXKRecentCellDataStoring> cellData in cellDataArray)
        {
            for (NSString* pattern in patternsList)
            {
                if (cellData.roomDisplayname && [cellData.roomDisplayname rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound)
                {
                    [filteredCellDataArray addObject:cellData];
                    break;
                }
            }
        }
    }
    else
    {
        filteredCellDataArray = nil;
        searchPatternsList = nil;
    }
    
    [self.delegate dataSource:self didCellChange:nil];
}

- (id<MXKRecentCellDataStoring>)cellDataAtIndex:(NSInteger)index
{
    if (filteredCellDataArray)
    {
        if (index < filteredCellDataArray.count)
        {
            return filteredCellDataArray[index];
        }
    }
    else if (index < cellDataArray.count)
    {
        return cellDataArray[index];
    }
    
    return nil;
}

- (CGFloat)cellHeightAtIndex:(NSInteger)index
{
    if (self.delegate)
    {
        id<MXKRecentCellDataStoring> cellData = [self cellDataAtIndex:index];
        
        Class<MXKCellRendering> class = [self.delegate cellViewClassForCellData:cellData];
        return [class heightForCellData:cellData withMaximumWidth:0];
    }
    
    return 0;
}


#pragma mark - Events processing
- (void)loadData
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomSummaryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionNewRoomNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDidLeaveRoomNotification object:nil];
    
    // Reset the table
    [internalCellDataArray removeAllObjects];
    
    // Retrieve the MXKCellData class to manage the data
    Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];
    NSAssert([class conformsToProtocol:@protocol(MXKRecentCellDataStoring)], @"MXKSessionRecentsDataSource only manages MXKCellData that conforms to MXKRecentCellDataStoring protocol");

    NSDate *startDate = [NSDate date];
    
    for (MXRoomSummary *roomSummary in self.mxSession.roomsSummaries)
    {
        // Filter out private rooms with conference users
        if (!roomSummary.room.state.isConferenceUserRoom)  // @TODO
        {
            id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithRoomSummary:roomSummary andRecentListDataSource:self];
            if (cellData)
            {
                [internalCellDataArray addObject:cellData];
            }
        }
    }

    NSLog(@"[MXKSessionRecentsDataSource] Loaded %tu recents in %.3fms", self.mxSession.rooms.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);

    // Make sure all rooms have a last message
    [self.mxSession fixRoomsSummariesLastMessage];

    // Report loaded array except if sync is in progress
    if (!roomDataSourceManager.isServerSyncInProgress)
    {
        [self sortCellDataAndNotifyChanges];
    }
    
    // Listen to MXSession rooms count changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXSessionHaveNewRoom:) name:kMXSessionNewRoomNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXSessionDidLeaveRoom:) name:kMXSessionDidLeaveRoomNotification object:nil];
    
    // Listen to the direct rooms list
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDirectRoomsChange:) name:kMXSessionDirectRoomsDidChangeNotification object:nil];
    
    // Listen to MXRoomSummary
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRoomSummaryChanged:) name:kMXRoomSummaryDidChangeNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXSessionStateChange) name:kMXKRoomDataSourceSyncStatusChanged object:nil];
}

- (void)didDirectRoomsChange:(NSNotification *)notif
{
    // Inform the delegate about the update
    [self.delegate dataSource:self didCellChange:nil];
}

- (void)didRoomSummaryChanged:(NSNotification *)notif
{
    MXRoomSummary *roomSummary = notif.object;

    if (roomSummary.mxSession == self.mxSession && internalCellDataArray.count)
    {
        // Find the index of the related cell data
        NSInteger index = NSNotFound;
        for (index = 0; index < internalCellDataArray.count; index++)
        {
            id<MXKRecentCellDataStoring> theRoomData = [internalCellDataArray objectAtIndex:index];
            if (theRoomData.roomSummary == roomSummary)
            {
                break;
            }
        }
        
        if (index < internalCellDataArray.count)
        {
            // Create a new instance to not modify the content of 'cellDataArray' (the copy is not a deep copy).
            Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];
            id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithRoomSummary:roomSummary andRecentListDataSource:self];
            if (cellData)
            {
                [internalCellDataArray replaceObjectAtIndex:index withObject:cellData];
            }
            
            // Report change except if sync is in progress
            if (!roomDataSourceManager.isServerSyncInProgress)
            {
                [self sortCellDataAndNotifyChanges];
            }
        }
        else
        {
            NSLog(@"[MXKSessionRecentsDataSource] didRoomLastMessageChanged: Cannot find the changed room summary for %@ (%@). It is probably not managed by this recents data source", roomSummary.roomId, roomSummary);
        }
    }
    else
    {
        // Inform the delegate that all the room summaries have been updated.
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)didMXSessionHaveNewRoom:(NSNotification *)notif
{
    MXSession *mxSession = notif.object;
    if (mxSession == self.mxSession)
    {
        NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
        
        // Add the room if there is not yet a cell for it
        id<MXKRecentCellDataStoring> roomData = [self cellDataWithRoomId:roomId];
        if (nil == roomData)
        {
            NSLog(@"MXKSessionRecentsDataSource] Add newly joined room: %@", roomId);
            
            // Retrieve the MXKCellData class to manage the data
            Class class = [self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier];

            MXRoomSummary *roomSummary = [mxSession roomSummaryWithRoomId:roomId];
            id<MXKRecentCellDataStoring> cellData = [[class alloc] initWithRoomSummary:roomSummary andRecentListDataSource:self];
            if (cellData)
            {
                [internalCellDataArray addObject:cellData];
                
                // Report change except if sync is in progress
                if (!roomDataSourceManager.isServerSyncInProgress)
                {
                    [self sortCellDataAndNotifyChanges];
                }
            }
        }
    }
}

- (void)didMXSessionDidLeaveRoom:(NSNotification *)notif
{
    MXSession *mxSession = notif.object;
    if (mxSession == self.mxSession)
    {
        NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
        id<MXKRecentCellDataStoring> roomData = [self cellDataWithRoomId:roomId];
        
        if (roomData)
        {
            NSLog(@"MXKSessionRecentsDataSource] Remove left room: %@", roomId);
            
            [internalCellDataArray removeObject:roomData];
            
            // Report change except if sync is in progress
            if (!roomDataSourceManager.isServerSyncInProgress)
            {
                [self sortCellDataAndNotifyChanges];
            }
        }
    }
}

- (void)didMXSessionInviteRoomUpdate:(NSNotification *)notif
{
    MXSession *mxSession = notif.object;
    if (mxSession == self.mxSession)
    {
        // do nothing by default
        // the inherited classes might require to perform a full or a particial refresh.
        //[self.delegate dataSource:self didCellChange:nil];
    }
}

// Order cells
- (void)sortCellDataAndNotifyChanges
{
    // Order them by origin_server_ts
    [internalCellDataArray sortUsingComparator:^NSComparisonResult(id<MXKRecentCellDataStoring> cellData1, id<MXKRecentCellDataStoring> cellData2)
    {
        NSComparisonResult result = NSOrderedAscending;
        if (cellData2.lastEvent.originServerTs > cellData1.lastEvent.originServerTs)
        {
            result = NSOrderedDescending;
        }
        else if (cellData2.lastEvent.originServerTs == cellData1.lastEvent.originServerTs)
        {
            result = NSOrderedSame;
        }
        return result;
    }];
    
    // Snapshot the cell data array
    cellDataArray = [internalCellDataArray copy];
    
    // Update search result if any
    if (searchPatternsList)
    {
        [self searchWithPatterns:searchPatternsList];
    }
    
    // Update here data source state
    if (state != MXKDataSourceStateReady)
    {
        state = MXKDataSourceStateReady;
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
        {
            [self.delegate dataSource:self didStateChange:state];
        }
    }
    
    // And inform the delegate about the update
    [self.delegate dataSource:self didCellChange:nil];
}

// Find the cell data that stores information about the given room id
- (id<MXKRecentCellDataStoring>)cellDataWithRoomId:(NSString*)roomId
{
    id<MXKRecentCellDataStoring> theRoomData;
    for (id<MXKRecentCellDataStoring> roomData in cellDataArray)
    {
        if ([roomData.roomSummary.roomId isEqualToString:roomId])
        {
            theRoomData = roomData;
            break;
        }
    }
    return theRoomData;
}

@end
