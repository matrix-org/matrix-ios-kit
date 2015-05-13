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

#import "MXKRecentListViewController.h"

@interface MXKRecentListViewController () {

    /**
     The data source providing UITableViewCells
     */
    MXKRecentListDataSource *dataSource;
}

@end

@implementation MXKRecentListViewController
@synthesize dataSource;

#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Check whether a room has been defined
    if (dataSource) {
        [self configureView];
    }
}

- (void)dealloc {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    // Dispose of any resources that can be recreated.
}

#pragma mark - override MXKTableViewController

- (void)destroy {
    
    self.tableView.dataSource = nil;
    self.tableView.delegate = nil;
    self.tableView = nil;
    
    dataSource.delegate = nil;
    dataSource = nil;
    
    _delegate = nil;
    
    [super destroy];
}

#pragma mark -

- (void)configureView {

    self.tableView.delegate = self;

    // Set up table data source
    self.tableView.dataSource = dataSource;
    
    if (dataSource) {
        // Set up classes to use for cells
        if ([[dataSource cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] nib]) {
            [self.tableView registerNib:[[dataSource cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] nib] forCellReuseIdentifier:kMXKRecentCellIdentifier];
        } else {
            [self.tableView registerClass:[dataSource cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] forCellReuseIdentifier:kMXKRecentCellIdentifier];
        }
    }
}

#pragma mark -
- (void)displayList:(MXKRecentListDataSource *)listDataSource {

    dataSource = listDataSource;
    dataSource.delegate = self;
    
    // Report the matrix session at view controller level to update UI according to session state
    self.mxSession = dataSource.mxSession;

    if (self.tableView) {
        [self configureView];
    }
}

#pragma mark - MXKDataSourceDelegate
- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes {
    // For now, do a simple full reload
    [self.tableView reloadData];
}


#pragma mark - UITableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    return [dataSource cellHeightAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (_delegate) {
        id<MXKRecentCellDataStoring> cellData = [dataSource cellDataAtIndex:indexPath.row];

        [_delegate recentListViewController:self didSelectRoom:cellData.roomDataSource.room.state.roomId];
    }
}

@end
