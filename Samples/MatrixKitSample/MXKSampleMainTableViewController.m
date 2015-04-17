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

#import "MXKSampleMainTableViewController.h"
#import "MXKSampleRecentsViewController.h"
#import "MXKSampleRoomViewController.h"
#import "MXKSampleJSQMessagesViewController.h"
#import "MXKSampleRoomMembersViewController.h"
#import <MatrixSDK/MXFileStore.h>

@interface MXKSampleMainTableViewController () {
    
    /**
     The room data source manager for the current Matrix sesion
     */
    MXKRoomDataSourceManager *roomDataSourceManager;
}

/**
 The id of the current room.
 */
@property NSString *roomId;

@end

@implementation MXKSampleMainTableViewController
@synthesize roomId;

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureView];

    // We need a room
    // So, initialise a Matrix session on matrix.org to display #test:matrix.org
    MXCredentials *credentials = [[MXCredentials alloc] initWithHomeServer:@"https://matrix.org"
                                                                    userId:@"@your_matrix_id"
                                                               accessToken:@"your_access_token"];

    self.mxSession = [[MXSession alloc] initWithMatrixRestClient:[[MXRestClient alloc] initWithCredentials:credentials]];

    roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mxSession];

    // As there is no mock for MatrixSDK yet, use a cache for Matrix data to boost init
    MXFileStore *mxFileStore = [[MXFileStore alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.mxSession setStore:mxFileStore success:^{
        typeof(self) self = weakSelf;
        [self.mxSession start:^{
            // Resolve #test:matrix.org to room id in order to make tests there
            [self.mxSession.matrixRestClient roomIDForRoomAlias:@"#test:matrix.org" success:^(NSString *aRoomId) {

                self.roomId = aRoomId;

            } failure:^(NSError *error) {
                NSAssert(false, @"roomIDForRoomAlias should not fail. Error: %@", error);
            }];

        } failure:^(NSError *error) {
            NSAssert(false, @"Make sure you have hardcoded your matrix id and your access token in the code few lines above. Error: %@", error);
        }];
    } failure:^(NSError *error) {
    }];

    // Test code for directly opening a VC
    //roomId = @"!vfFxDRtZSSdspfTSEr:matrix.org";
    //[self performSegueWithIdentifier:@"showSampleRoomViewController" sender:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Let the manager release the previous room data source
     MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:roomId create:NO];
    if (roomDataSource) {
        [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:NO];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureView {
    [self.tableView reloadData];
    self.tableView.allowsSelection = YES;
}


#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    } else if (section == 1) {
        return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Room view controller samples:";
    } else if (section == 1) {
        return @"Member list samples:";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SampleMainTableViewCell" forIndexPath:indexPath];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Default implementation";
                break;
            case 1:
                cell.textLabel.text = @"Demo based on JSQMessagesViewController lib";
                break;
        }
    } else {
        cell.textLabel.text = @"Default implementation";
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Ignore selection until roomId is ready
    if (!roomId) {
        return;
    }
    
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                [self performSegueWithIdentifier:@"showSampleRoomViewController" sender:self];
                break;
            case 1:
                [self performSegueWithIdentifier:@"showSampleJSQMessagesViewController" sender:self];
                break;
        }
    } else {
        [self performSegueWithIdentifier:@"showSampleRoomMembersViewController" sender:self];
    }
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([segue.identifier isEqualToString:@"showSampleRecentsViewController"]) {
        MXKSampleRecentsViewController *sampleRecentListViewController = (MXKSampleRecentsViewController *)segue.destinationViewController;
        sampleRecentListViewController.delegate = self;

        MXKRecentListDataSource *listDataSource = [[MXKRecentListDataSource alloc] initWithMatrixSession:self.mxSession];
        [sampleRecentListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleRoomViewController"]) {
        MXKSampleRoomViewController *sampleRoomViewController = (MXKSampleRoomViewController *)segue.destinationViewController;

        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:roomId create:YES];

        // As the sample plays with several kinds of room data source, make sure we reuse one with the right type
        if (roomDataSource && NO == [roomDataSource isMemberOfClass:MXKRoomDataSource.class]) {
            [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:YES];
             roomDataSource = [roomDataSourceManager roomDataSourceForRoom:roomId create:YES];
        }

        [sampleRoomViewController displayRoom:roomDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleJSQMessagesViewController"]) {
        MXKSampleJSQMessagesViewController *sampleRoomViewController = (MXKSampleJSQMessagesViewController *)segue.destinationViewController;

        MXKSampleJSQRoomDataSource *roomDataSource = (MXKSampleJSQRoomDataSource *)[roomDataSourceManager roomDataSourceForRoom:roomId create:NO];

        // As the sample plays with several kind of room data source, make sure we reuse one with the right type
        if (roomDataSource && NO == [roomDataSource isMemberOfClass:MXKSampleJSQRoomDataSource.class]) {
            [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:YES];
            roomDataSource = nil;
        }

        if (!roomDataSource) {
            roomDataSource = [[MXKSampleJSQRoomDataSource alloc] initWithRoomId:roomId andMatrixSession:self.mxSession];
            [roomDataSourceManager addRoomDataSource:roomDataSource];
        }

        [sampleRoomViewController displayRoom:roomDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleRoomMembersViewController"]) {
        MXKSampleRoomMembersViewController *sampleRoomMemberListViewController = (MXKSampleRoomMembersViewController *)segue.destinationViewController;
        sampleRoomMemberListViewController.delegate = self;
        
        MXKRoomMemberListDataSource *listDataSource = [[MXKRoomMemberListDataSource alloc] initWithRoomId:roomId andMatrixSession:self.mxSession];
        [sampleRoomMemberListViewController displayList:listDataSource];
    }
}

#pragma mark - MXKRecentListViewControllerDelegate
- (void)recentListViewController:(MXKRecentListViewController *)recentListViewController didSelectRoom:(NSString *)aRoomId {

    // Change the current room id and come back to the main page
    self.roomId = aRoomId;
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma  mark - MXKRoomMemberListViewControllerDelegate

- (void)roomMemberListViewController:(MXKRoomMemberListViewController *)roomMemberListViewController didSelectMember:(NSString*)memberId {
    // TODO
    NSLog(@"member (%@) has been selected", memberId);
}

#pragma mark -
- (void)setRoomId:(NSString *)inRoomId {
    roomId = inRoomId;
    MXRoom *room = [self.mxSession roomWithRoomId:roomId];
    _selectedRoomDisplayName.text = room.state.displayname;
}

- (NSString*)roomId {
    return roomId;
}

@end
