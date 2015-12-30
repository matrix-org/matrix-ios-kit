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

#import "MXKSearchDataSource.h"

#import "MXKSearchCellData.h"

#pragma mark - Constant definitions
NSString *const kMXKSearchCellDataIdentifier = @"kMXKSearchCellDataIdentifier";


@interface MXKSearchDataSource ()
{
    /**
     List of results retrieved from the server.
     */
    NSMutableArray<id<MXKSearchCellDataStoring>> *cellDataArray;

    /**
     Token that can be used to get the next batch of results in the group, if exists.
     */
    NSString *nextBatch;
}

@end

@implementation MXKSearchDataSource 

- (instancetype)initWithMatrixSession:(MXSession *)mxSession
{
    self = [super initWithMatrixSession:mxSession];
    if (self)
    {
        // Set default data and view classes
        // Cell data
        [self registerCellDataClass:MXKSearchCellData.class forCellIdentifier:kMXKSearchCellDataIdentifier];

        // Set default MXEvent -> NSString formatter
        _eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:mxSession];

        cellDataArray = [NSMutableArray array];
    }
    return self;
}

- (void)searchMessageText:(NSString *)text
{
    if (![_searchText isEqualToString:text])
    {
        NSLog(@"[MXKSearchDataSource] searchMessageText: %@", text);

        // Reset data before making the new search
        _searchText = text;
        _serverCount = 0;
        _canPaginate = NO;
        nextBatch = nil;
        self.state = MXKDataSourceStatePreparing;
        [cellDataArray removeAllObjects];

        [self doSearch];
    }
}

- (void)paginateBack
{
    NSLog(@"[MXKSearchDataSource] paginateBack");

    self.state = MXKDataSourceStatePreparing;
    [self doSearch];
}

- (id<MXKSearchCellDataStoring>)cellDataAtIndex:(NSInteger)index
{
    id<MXKSearchCellDataStoring> cellData;
    if (index < cellDataArray.count)
    {
        cellData = cellDataArray[index];
    }

    return cellData;
}

#pragma mark - Private methods

// Update the MXKDataSource and notify the delegate
- (void)setState:(MXKDataSourceState)newState
{
    state = newState;

    if (self.delegate)
    {
        if ([self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
        {
            [self.delegate dataSource:self didStateChange:state];
        }
    }
}

- (void)doSearch
{
    NSDate *startDate = [NSDate date];

    [self.mxSession.matrixRestClient searchMessageText:_searchText inRooms:nil beforeLimit:0 afterLimit:0 nextBatch:nextBatch success:^(MXSearchRoomEventResults *roomEventResults) {

        NSLog(@"[MXKSearchDataSource] searchMessageText: %@. Done in %.3fms - Got %tu / %tu messages", _searchText, [[NSDate date] timeIntervalSinceDate:startDate] * 1000, roomEventResults.results.count, roomEventResults.count);

        _serverCount = roomEventResults.count;
        _canPaginate = (0 < roomEventResults.results.count);
        nextBatch = roomEventResults.nextBatch;

        // Retrieve the MXKCellData class to manage the data
        Class class = [self cellDataClassForCellIdentifier:kMXKSearchCellDataIdentifier];
        NSAssert([class conformsToProtocol:@protocol(MXKSearchCellDataStoring)], @"MXKSearchDataSource only manages MXKCellData that conforms to MXKSearchCellDataStoring protocol");

        // Process HS response to cells data
        for (MXSearchResult *result in roomEventResults.results)
        {
            id<MXKSearchCellDataStoring> cellData = [[class alloc] initWithSearchResult:result andSearchDataSource:self];
            if (cellData)
            {
                [cellDataArray insertObject:cellData atIndex:0];
            }
        }

        self.state = MXKDataSourceStateReady;

        // Provide changes information to the delegate
        NSIndexSet *insertedIndexes;
        if (roomEventResults.results.count)
        {
            insertedIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, roomEventResults.results.count)];
        }

        [self.delegate dataSource:self didCellChange:insertedIndexes];

    } failure:^(NSError *error) {
        self.state = MXKDataSourceStateFailed;
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return cellDataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<MXKSearchCellDataStoring> cellData = [self cellDataAtIndex:indexPath.row];

    NSString *cellIdentifier = [self.delegate cellReuseIdentifierForCellData:cellData];
    if (cellIdentifier)
    {
        UITableViewCell<MXKCellRendering> *cell  = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];

        // Make the bubble display the data
        [cell render:cellData];

        return cell;
    }

    return nil;
}

@end
