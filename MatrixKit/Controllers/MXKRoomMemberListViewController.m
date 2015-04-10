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

#import "MXKRoomMemberListViewController.h"

@interface MXKRoomMemberListViewController () {

    /**
     The data source providing UITableViewCells
     */
    MXKRoomMemberListDataSource *dataSource;
}

@end

@implementation MXKRoomMemberListViewController
@synthesize dataSource;

#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Add programmatically the table view and set its constraints here.
    // We do not use .xib to define view controller content because we observed wrong display when
    // this view controller was used as `master view controller` in split view controller (In some scenario,
    // the view controller was refreshed with null width and height).
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.frame];
    [self.tableView setTranslatesAutoresizingMaskIntoConstraints: NO];
    [self.view addSubview:self.tableView];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.bottomLayoutGuide
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.tableView
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0f
                                                           constant:0.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.topLayoutGuide
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.tableView
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0f
                                                           constant:0.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                     attribute:NSLayoutAttributeLeading
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.tableView
                                                     attribute:NSLayoutAttributeLeading
                                                    multiplier:1.0f
                                                      constant:0.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                     attribute:NSLayoutAttributeTrailing
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self.tableView
                                                     attribute:NSLayoutAttributeTrailing
                                                    multiplier:1.0f
                                                      constant:0.0f]];
    
    // Check whether a room has been defined
    if (dataSource) {
        [self configureView];
    }
}

- (void)dealloc {
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
    _tableView = nil;
    dataSource = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    // Dispose of any resources that can be recreated.
}

- (void)configureView {

    _tableView.delegate = self;

    // Set up table data source
    _tableView.dataSource = dataSource;
    
    // Set up classes to use for cells
    if ([[dataSource cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier] nib]) {
        [_tableView registerNib:[[dataSource cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier] nib] forCellReuseIdentifier:kMXKRoomMemberCellIdentifier];
    } else {
        [_tableView registerClass:[dataSource cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier] forCellReuseIdentifier:kMXKRoomMemberCellIdentifier];
    }
}

#pragma mark -
- (void)displayList:(MXKRoomMemberListDataSource *)listDataSource {

    dataSource = listDataSource;
    dataSource.delegate = self;

    if (_tableView) {
        [self configureView];
    }
}

#pragma mark - MXKDataSourceDelegate
- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes {
    // For now, do a simple full reload
    [_tableView reloadData];
}


#pragma mark - UITableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    return [dataSource cellHeightAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (_delegate) {
        id<MXKRoomMemberCellDataStoring> cellData = [dataSource cellDataAtIndex:indexPath.row];

        [_delegate roomMemberListViewController:self didSelectMember:cellData.roomMember];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
