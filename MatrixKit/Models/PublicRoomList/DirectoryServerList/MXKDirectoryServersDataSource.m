/*
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

#import "MXKDirectoryServersDataSource.h"

#import "MXKDirectoryServerCellData.h"

NSString *const kMXKDirectorServerCellIdentifier = @"kMXKDirectorServerCellIdentifier";

#pragma mark - DirectoryServersDataSource

@interface MXKDirectoryServersDataSource ()
{
    // The pending request to load third-party protocols.
    MXHTTPOperation *request;
}

@end

@implementation MXKDirectoryServersDataSource

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        cellDataArray = [NSMutableArray array];
        filteredCellDataArray = nil;

        // Set default data w classes
        [self registerCellDataClass:MXKDirectoryServerCellData.class forCellIdentifier:kMXKDirectorServerCellIdentifier];
    }
    return self;
}

- (void)destroy
{
    cellDataArray = nil;
    filteredCellDataArray = nil;
}

- (void)cancelAllRequests
{
    [super cancelAllRequests];

    [request cancel];
    request = nil;
}

- (void)loadData
{
    // Cancel the previous request
    if (request)
    {
        [request cancel];
    }

    [self setState:MXKDataSourceStatePreparing];

    // Reset all vars
    [cellDataArray removeAllObjects];

    __weak typeof(self) weakSelf = self;
    request = [self.mxSession.matrixRestClient thirdpartyProtocols:^(MXThirdpartyProtocolsResponse *thirdpartyProtocolsResponse) {

        if (weakSelf)
        {
            typeof(self) self = weakSelf;

            for (NSString *protocolName in thirdpartyProtocolsResponse.protocols)
            {
                MXThirdPartyProtocol *protocol = thirdpartyProtocolsResponse.protocols[protocolName];

                for (MXThirdPartyProtocolInstance *instance in protocol.instances)
                {
                    Class class = [self cellDataClassForCellIdentifier:kMXKDirectorServerCellIdentifier];

                    id<MXKDirectoryServerCellDataStoring> cellData = [[class alloc] initWithProtocolInstance:instance protocol:protocol];

                    [cellDataArray addObject:cellData];
                }
            }

            [self setState:MXKDataSourceStateReady];
        }

    } failure:^(NSError *error) {

        if (weakSelf)
        {
            typeof(self) self = weakSelf;

            if (!request || request.isCancelled)
            {
                // Do not take into account error coming from a cancellation
                return;
            }

            self->request = nil;

            NSLog(@"[MXKDirectoryServersDataSource] Failed to fecth third-party protocols.");

            [self setState:MXKDataSourceStateFailed];
        }
    }];
}

- (void)searchWithPatterns:(NSArray*)patternsList
{
    if (patternsList.count)
    {
        if (filteredCellDataArray)
        {
            [filteredCellDataArray removeAllObjects];
        }
        else
        {
            filteredCellDataArray = [NSMutableArray arrayWithCapacity:cellDataArray.count];
        }

        for (id<MXKDirectoryServerCellDataStoring> cellData in cellDataArray)
        {
            for (NSString* pattern in patternsList)
            {
                if ([cellData.desc rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound)
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
    }

    if (self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
}

#pragma mark - Private methods

// Update the MXKDataSource state and the delegate
- (void)setState:(MXKDataSourceState)newState
{
    state = newState;
    if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
    {
        [self.delegate dataSource:self didStateChange:state];
    }
}

- (id<MXKDirectoryServerCellDataStoring>)cellDataAtIndex:(NSInteger)index
{
    if (filteredCellDataArray)
    {
        return filteredCellDataArray[index];
    }
    return cellDataArray[index];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (filteredCellDataArray)
    {
        return filteredCellDataArray.count;
    }
    return cellDataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<MXKDirectoryServerCellDataStoring> cellData = [self cellDataAtIndex:indexPath.row];

    if (cellData && self.delegate)
    {
        NSString *identifier = [self.delegate cellReuseIdentifierForCellData:cellData];
        if (identifier)
        {
            UITableViewCell<MXKCellRendering> *cell  = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];

            // Make the cell display the data
            [cell render:cellData];

            return cell;
        }
    }

    return nil;
}

@end
