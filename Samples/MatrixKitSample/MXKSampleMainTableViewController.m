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
     The current selected room.
     */
    MXRoom *selectedRoom;
    
    /**
     Current index of sections
     */
    NSInteger roomSectionIndex;
    NSInteger roomMembersSectionIndex;
    NSInteger authenticationSectionIndex;
}

@end

@implementation MXKSampleMainTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tableView.tableHeaderView.hidden = YES;
    self.tableView.allowsSelection = YES;
    [self.tableView reloadData];
    
    // Check whether some accounts are availables
    if ([[MXKAccountManager sharedManager] accounts].count) {
        [self launchMatrixSession];
    } else {
        // Ask for a matrix account first
        [self performSegueWithIdentifier:@"showAuthenticationViewController" sender:self];
    }

    // Test code for directly opening a VC
    //roomId = @"!vfFxDRtZSSdspfTSEr:matrix.org";
    //[self performSegueWithIdentifier:@"showSampleRoomViewController" sender:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (selectedRoom) {
        // Let the manager release the previous room data source
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:selectedRoom.mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:NO];
        if (roomDataSource) {
            [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:NO];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)launchMatrixSession {
    
    // Launch a matrix session only for the first one (TODO launch a session for each account).
    
    NSArray *accounts = [[MXKAccountManager sharedManager] accounts];
    MXKAccount *account = [accounts firstObject];
    
    // As there is no mock for MatrixSDK yet, use a cache for Matrix data to boost init
    MXFileStore *mxFileStore = [[MXFileStore alloc] init];
    [account createSessionWithStore:mxFileStore success:^{
        
        // report created matrix session
        self.mxSession = account.mxSession;
        
        self.tableView.tableHeaderView.hidden = NO;
        [self.tableView reloadData];
        
        // Complete the session registration
        [account startSession:^{
            NSLog(@"Matrix session successfully started (%@)", account.mxCredentials.userId);
        } failure:^(NSError *error) {
            NSAssert(false, @"Start matrix session should not fail. Error: %@", error);
        }];
    } failure:^(NSError *error) {
        NSAssert(false, @"Create matrix session should not fail. Error: %@", error);
    }];
}


#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count = 0;
    
    roomSectionIndex = roomMembersSectionIndex = authenticationSectionIndex = -1;
    
    if (selectedRoom) {
        roomSectionIndex = count++;
        roomMembersSectionIndex = count++;
    }
    
    authenticationSectionIndex = count++;
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == roomSectionIndex) {
        return 2;
    } else if (section == roomMembersSectionIndex) {
        return 1;
    } else if (section == authenticationSectionIndex) {
        return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == roomSectionIndex) {
        return @"Room samples:";
    } else if (section == roomMembersSectionIndex) {
        return @"Room members samples:";
    } else if (section == authenticationSectionIndex) {
        return @"Authentication samples:";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SampleMainTableViewCell" forIndexPath:indexPath];

    if (indexPath.section == roomSectionIndex) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Default implementation";
                break;
            case 1:
                cell.textLabel.text = @"Demo based on JSQMessagesViewController lib";
                break;
        }
    } else if (indexPath.section == roomMembersSectionIndex) {
        cell.textLabel.text = @"Default implementation";
    } else if (indexPath.section == authenticationSectionIndex) {
        cell.textLabel.text = @"Default implementation";
    }
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == roomSectionIndex) {
        switch (indexPath.row) {
            case 0:
                [self performSegueWithIdentifier:@"showSampleRoomViewController" sender:self];
                break;
            case 1:
                [self performSegueWithIdentifier:@"showSampleJSQMessagesViewController" sender:self];
                break;
        }
    } else if (indexPath.section == roomMembersSectionIndex) {
        [self performSegueWithIdentifier:@"showSampleRoomMembersViewController" sender:self];
    } else if (indexPath.section == authenticationSectionIndex) {
        [self performSegueWithIdentifier:@"showAuthenticationViewController" sender:self];
    }
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {

    if ([segue.identifier isEqualToString:@"showSampleRecentsViewController"] && self.mxSession) {
        MXKSampleRecentsViewController *sampleRecentListViewController = (MXKSampleRecentsViewController *)segue.destinationViewController;
        sampleRecentListViewController.delegate = self;

        MXKRecentListDataSource *listDataSource = [[MXKRecentListDataSource alloc] initWithMatrixSession:self.mxSession];
        [sampleRecentListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleRoomViewController"]) {
        MXKSampleRoomViewController *sampleRoomViewController = (MXKSampleRoomViewController *)segue.destinationViewController;

        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:selectedRoom.mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:YES];

        // As the sample plays with several kinds of room data source, make sure we reuse one with the right type
        if (roomDataSource && NO == [roomDataSource isMemberOfClass:MXKRoomDataSource.class]) {
            [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:YES];
             roomDataSource = [roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:YES];
        }

        [sampleRoomViewController displayRoom:roomDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleJSQMessagesViewController"]) {
        MXKSampleJSQMessagesViewController *sampleRoomViewController = (MXKSampleJSQMessagesViewController *)segue.destinationViewController;

        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:selectedRoom.mxSession];
        MXKSampleJSQRoomDataSource *roomDataSource = (MXKSampleJSQRoomDataSource *)[roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:NO];

        // As the sample plays with several kind of room data source, make sure we reuse one with the right type
        if (roomDataSource && NO == [roomDataSource isMemberOfClass:MXKSampleJSQRoomDataSource.class]) {
            [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:YES];
            roomDataSource = nil;
        }

        if (!roomDataSource) {
            roomDataSource = [[MXKSampleJSQRoomDataSource alloc] initWithRoomId:selectedRoom.state.roomId andMatrixSession:selectedRoom.mxSession];
            [roomDataSourceManager addRoomDataSource:roomDataSource];
        }

        [sampleRoomViewController displayRoom:roomDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleRoomMembersViewController"]) {
        MXKSampleRoomMembersViewController *sampleRoomMemberListViewController = (MXKSampleRoomMembersViewController *)segue.destinationViewController;
        sampleRoomMemberListViewController.delegate = self;
        
        MXKRoomMemberListDataSource *listDataSource = [[MXKRoomMemberListDataSource alloc] initWithRoomId:selectedRoom.state.roomId andMatrixSession:selectedRoom.mxSession];
        [sampleRoomMemberListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showAuthenticationViewController"]) {
        MXKAuthenticationViewController *sampleAuthViewController = (MXKAuthenticationViewController *)segue.destinationViewController;
        sampleAuthViewController.delegate = self;
        sampleAuthViewController.defaultHomeServerUrl = @"https://matrix.org";
        sampleAuthViewController.defaultIdentityServerUrl = @"https://matrix.org";
    }
}

#pragma mark - MXKRecentListViewControllerDelegate
- (void)recentListViewController:(MXKRecentListViewController *)recentListViewController didSelectRoom:(NSString *)roomId {

    // Update the selected room and go back to the main page
    selectedRoom = [self.mxSession roomWithRoomId:roomId];
    _selectedRoomDisplayName.text = selectedRoom.state.displayname;
    
    [self.tableView reloadData];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma  mark - MXKRoomMemberListViewControllerDelegate

- (void)roomMemberListViewController:(MXKRoomMemberListViewController *)roomMemberListViewController didSelectMember:(NSString*)memberId {
    // TODO
    NSLog(@"Member (%@) has been selected", memberId);
}

#pragma mark - 

- (void)authenticationViewController:(MXKAuthenticationViewController *)authenticationViewController didLogWithUserId:(NSString*)userId {
    NSLog(@"New account (%@) has been added", userId);
    
    if (!self.mxSession) {
        [self launchMatrixSession];
    }
    
    // Go back to the main page
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
