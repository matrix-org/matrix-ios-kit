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
     Observer matrix sessions to handle new opened session
     */
    id matrixSessionStateObserver;
    
    /**
     Observer used to handle call
     */
    id callObserver;
    
    /**
     The current selected room.
     */
    MXRoom *selectedRoom;
    
    /**
     The current call view controller (if any).
     */
    MXKCallViewController *presentedCallViewController;
    
    /**
     Call status window displayed when user goes back to app during a call.
     */
    UIWindow* callStatusBarWindow;
    UIButton* callStatusBarButton;
    
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
    
    // Register matrix session state observer in order to handle new opened session
    matrixSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXSession *mxSession = (MXSession*)notif.object;
        
        // Check whether the concerned session is a new one
        if (mxSession.state == MXSessionStateInitialised) {
            // report created matrix session
            self.mxSession = mxSession;
            
            self.tableView.tableHeaderView.hidden = NO;
            [self.tableView reloadData];
        }
    }];
    
    // Register call observer in order to handle new opened session
    callObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallManagerNewCall object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXCall *mxCall = (MXCall*)notif.object;
        
        presentedCallViewController = [MXKCallViewController callViewController:mxCall];
        presentedCallViewController.delegate = self;
        
        UINavigationController *navigationController = self.navigationController;
        [navigationController.topViewController presentViewController:presentedCallViewController animated:YES completion:^{
            // Hide system status bar
            [UIApplication sharedApplication].statusBarHidden = YES;
        }];
    }];
    
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
    [account openSessionWithStore:mxFileStore];
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

#pragma mark - MXKAuthenticationViewControllerDelegate

- (void)authenticationViewController:(MXKAuthenticationViewController *)authenticationViewController didLogWithUserId:(NSString*)userId {
    NSLog(@"New account (%@) has been added", userId);
    
    if (!self.mxSession) {
        [self launchMatrixSession];
    }
    
    // Go back to the main page
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - MXKCallViewControllerDelegate

- (void)dismissCallViewController:(MXKCallViewController *)callViewController {
    
    BOOL callIsEnded = (callViewController.mxCall.state == MXCallStateEnded);
    NSLog(@"Call view controller must be dismissed (%d)", callIsEnded);
    
    [self dismissViewControllerAnimated:YES completion:^{
        if (!callIsEnded) {
            [self addCallStatusBar];
        } else {
            // Restore system status bar
            [UIApplication sharedApplication].statusBarHidden = NO;
        }
    }];
    
    if (callIsEnded) {
        [self removeCallStatusBar];
        
        // Release properly
        presentedCallViewController.mxCall.delegate = nil;
        presentedCallViewController.delegate = nil;
        presentedCallViewController = nil;
    }
}

#pragma mark - Call status handling

- (void)addCallStatusBar {
    
    // Add a call status bar
    CGSize topBarSize = CGSizeMake(self.view.frame.size.width, 44);
    
    callStatusBarWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0,0, topBarSize.width,topBarSize.height)];
    callStatusBarWindow.windowLevel = UIWindowLevelStatusBar;
    
    // Create statusBarButton
    callStatusBarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    callStatusBarButton.frame = CGRectMake(0, 0, topBarSize.width,topBarSize.height);
    NSString *btnTitle = @"Return to call";
    
    [callStatusBarButton setTitle:btnTitle forState:UIControlStateNormal];
    [callStatusBarButton setTitle:btnTitle forState:UIControlStateHighlighted];
    callStatusBarButton.titleLabel.textColor = [UIColor whiteColor];
    
    [callStatusBarButton setBackgroundColor:[UIColor blueColor]];
    [callStatusBarButton addTarget:self action:@selector(returnToCallView) forControlEvents:UIControlEventTouchUpInside];
    
    // Place button into the new window
    [callStatusBarWindow addSubview:callStatusBarButton];
    
    callStatusBarWindow.hidden = NO;
    [self statusBarDidChangeFrame];
    
    // We need to listen to the system status bar size change events to refresh the root controller frame.
    // Else the navigation bar position will be wrong.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarDidChangeFrame)
                                                 name:UIApplicationDidChangeStatusBarFrameNotification
                                               object:nil];
}

- (void)removeCallStatusBar {
    
    if (callStatusBarWindow) {
        
        // Hide & destroy it
        callStatusBarWindow.hidden = YES;
        [self statusBarDidChangeFrame];
        [callStatusBarButton removeFromSuperview];
        callStatusBarButton = nil;
        callStatusBarWindow = nil;
        
        // No more need to listen to system status bar changes
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    }
}

- (void)returnToCallView {
    
    [self removeCallStatusBar];
    
    UINavigationController *navigationController = self.navigationController;
    [navigationController.topViewController presentViewController:presentedCallViewController animated:YES completion:nil];
}

- (void)statusBarDidChangeFrame {
    
    UIApplication *app = [UIApplication sharedApplication];
    UIViewController *rootController = app.keyWindow.rootViewController;
    
    // Refresh the root view controller frame
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    if (callStatusBarWindow) {
        // Substract the height of call status bar from the frame.
        CGFloat callBarStatusHeight = callStatusBarWindow.frame.size.height;
        
        CGFloat delta = callBarStatusHeight - frame.origin.y;
        frame.origin.y = callBarStatusHeight;
        frame.size.height -= delta;
    }
    rootController.view.frame = frame;
    [rootController.view setNeedsLayout];
}

@end
