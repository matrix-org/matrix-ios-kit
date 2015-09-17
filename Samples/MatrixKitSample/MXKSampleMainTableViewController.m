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
#import "MXKSampleRoomViewController.h"
#import "MXKSampleJSQMessagesViewController.h"
#import "MXKSampleRoomMembersViewController.h"

#import "MXKSampleRoomMemberTableViewCell.h"

#import <MatrixSDK/MXFileStore.h>

@interface MXKSampleMainTableViewController ()
{
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
     The current selected room member.
     */
    MXRoomMember *selectedRoomMember;
    
    /**
     The current selected account.
     */
    MXKAccount *selectedAccount;
    
    /**
     The current selected contact
     */
    MXKContact *selectedContact;
    
    /**
     The current call view controller (if any).
     */
    MXKCallViewController *currentCallViewController;
    
    /**
     Call status window displayed when user goes back to app during a call.
     */
    UIWindow* callStatusBarWindow;
    UIButton* callStatusBarButton;
    
    /**
     Current index of sections
     */
    NSInteger accountSectionIndex;
    NSInteger recentsSectionIndex;
    NSInteger roomSectionIndex;
    NSInteger roomMembersSectionIndex;
    NSInteger authenticationSectionIndex;
    NSInteger contactSectionIndex;
}

@end

@implementation MXKSampleMainTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.tableHeaderView.hidden = YES;
    self.tableView.allowsSelection = YES;
    
    // Register matrix session state observer
    matrixSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXSession *mxSession = (MXSession*)notif.object;
        
        // Check whether the concerned session is a new one
        if (mxSession.state == MXSessionStateInitialised)
        {
            // Report created matrix session
            [self addMatrixSession:mxSession];
            [[MXKContactManager sharedManager] addMatrixSession:mxSession];
            
            self.tableView.tableHeaderView.hidden = NO;
            [self.tableView reloadData];
        }
        else if (mxSession.state == MXSessionStateClosed)
        {
            [self removeMatrixSession:mxSession];
            [[MXKContactManager sharedManager] removeMatrixSession:mxSession];
        }
    }];
    
    // Register call observer in order to handle voip call
    callObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallManagerNewCall object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Ignore the call if a call is already in progress
        if (!currentCallViewController)
        {
            MXCall *mxCall = (MXCall*)notif.object;
            
            currentCallViewController = [MXKCallViewController callViewController:mxCall];
            currentCallViewController.delegate = self;
            
            UINavigationController *navigationController = self.navigationController;
            [navigationController.topViewController presentViewController:currentCallViewController animated:YES completion:^{
                currentCallViewController.isPresented = YES;
            }];
            
            // Hide system status bar
            [UIApplication sharedApplication].statusBarHidden = YES;
        }
    }];
    
    // Add observer to handle new account
    [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidAddAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Refresh table to add this new account
        [self.tableView reloadData];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidRemoveAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXKAccount *mxAccount = notif.object;
        if (mxAccount)
        {
            // Check whether details of this account was displayed
            if (self.childViewControllers.count)
            {
                for (id viewController in self.childViewControllers)
                {
                    if ([viewController isKindOfClass:[MXKAccountDetailsViewController class]])
                    {
                        MXKAccountDetailsViewController *accountDetailsViewController = (MXKAccountDetailsViewController*)viewController;
                        if ([accountDetailsViewController.mxAccount.mxCredentials.userId isEqualToString:mxAccount.mxCredentials.userId])
                        {
                            // pop the account details view controller
                            [self.navigationController popToRootViewControllerAnimated:YES];
                            break;
                        }
                    }
                }
            }
        }
        
        if (![MXKAccountManager sharedManager].accounts.count)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self logout];
            });
        }
        else
        {
            // Refresh table to remove this account
            [self.tableView reloadData];
        }
    }];
    
    // Add observer to update accounts section
    [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountUserInfoDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        // Refresh table to remove this account
        [self.tableView reloadData];
    }];
    
    // Observers have been set, we will start now a matrix session for each enabled accounts.
    // As there is no mock for MatrixSDK yet, use an actual Matrix file store to boost init
    [MXKAccountManager sharedManager].storeClass = [MXFileStore class];
    [[MXKAccountManager sharedManager] openSessionForActiveAccounts];
    
    // Check whether some accounts are availables
    if (![[MXKAccountManager sharedManager] accounts].count)
    {
        // Ask for a matrix account first
        [self performSegueWithIdentifier:@"showMXKAuthenticationViewController" sender:self];
    }
    
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (selectedRoom)
    {
        // Let the manager release the previous room data source
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:selectedRoom.mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:NO];
        if (roomDataSource)
        {
            [roomDataSourceManager closeRoomDataSource:roomDataSource forceClose:NO];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)login
{
    // Show authentication screen
    [self performSegueWithIdentifier:@"showMXKAuthenticationViewController" sender:self];
}

- (void)logout
{
    // Clear cache
    [MXKMediaManager clearCache];
    
    // Logout all matrix account
    [[MXKAccountManager sharedManager] logout];
    
    // Reset
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        [self removeMatrixSession:mxSession];
    }
    selectedRoom = nil;
    _selectedRoomDisplayName.text = nil;
    
    // Update display
    self.tableView.tableHeaderView.hidden = YES;
    self.selectedRoomDisplayName.text = @"Please select a room";
    [self.tableView reloadData];
}

- (IBAction)onAccountToggleChange:(id)sender
{
    UISwitch *accountSwitchToggle = sender;
    
    NSArray *accounts = [[MXKAccountManager sharedManager] accounts];
    if (accountSwitchToggle.tag < accounts.count)
    {
        MXKAccount *account = [accounts objectAtIndex:accountSwitchToggle.tag];
        account.disabled = !accountSwitchToggle.on;
    }
    
    [self.tableView reloadData];
}

// Test code for directly opening a Room VC
//- (void)didMatrixSessionStateChange{
//
//    [super didMatrixSessionStateChange];
//
//    if (self.mxSession.state == MXKDataSourceStateReady){
//        // Test code for directly opening a VC
//        NSString *roomId = @"!xxx";
//        selectedRoom = [self.mxSession roomWithRoomId:roomId];
//        [self performSegueWithIdentifier:@"showMXKRoomViewController" sender:self];
//    }
//
//}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger count = 0;
    
    accountSectionIndex = recentsSectionIndex = roomSectionIndex = roomMembersSectionIndex = authenticationSectionIndex = contactSectionIndex = -1;
    
    accountSectionIndex = count++;
    
    if ([[MXKAccountManager sharedManager] accounts].count)
    {
        recentsSectionIndex = count++;
    }
    
    if (selectedRoom)
    {
        roomSectionIndex = count++;
        roomMembersSectionIndex = count++;
    }
    
    authenticationSectionIndex = count++;
    contactSectionIndex = count++;
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == accountSectionIndex)
    {
        if ([[MXKAccountManager sharedManager] accounts].count)
        {
            return [[MXKAccountManager sharedManager] accounts].count + 2; // Add 2 cells in this section to add actions: add account, logout all.
        }
        return 1; // Display only "Add account" action button.
    }
    else if (section == recentsSectionIndex)
    {
        return 2;
    }
    else if (section == roomSectionIndex)
    {
        return 3;
    }
    else if (section == roomMembersSectionIndex)
    {
        return 2;
    }
    else if (section == authenticationSectionIndex)
    {
        return 1;
    }
    else if (section == contactSectionIndex)
    {
        return 1;
    }
    
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == accountSectionIndex)
    {
        return @"Accounts:";
    }
    else if (section == recentsSectionIndex)
    {
        return @"Recents:";
    }
    else if (section == roomSectionIndex)
    {
        return @"Rooms:";
    }
    else if (section == roomMembersSectionIndex)
    {
        return @"Room members:";
    }
    else if (section == authenticationSectionIndex)
    {
        return @"Authentication:";
    }
    else if (section == contactSectionIndex)
    {
        return @"Contacts:";
    }
    
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (indexPath.section == accountSectionIndex)
    {
        NSArray *accounts = [[MXKAccountManager sharedManager] accounts];
        if (indexPath.row < accounts.count)
        {
            MXKAccountTableViewCell *accountCell = [tableView dequeueReusableCellWithIdentifier:[MXKAccountTableViewCell defaultReuseIdentifier]];
            if (!accountCell)
            {
                accountCell = [[MXKAccountTableViewCell alloc] init];
            }
            
            accountCell.mxAccount = [accounts objectAtIndex:indexPath.row];
            
            // Display switch toggle in case of multiple accounts
            if (accounts.count > 1 || accountCell.mxAccount.disabled)
            {
                accountCell.accountSwitchToggle.tag = indexPath.row;
                accountCell.accountSwitchToggle.hidden = NO;
                [accountCell.accountSwitchToggle addTarget:self action:@selector(onAccountToggleChange:) forControlEvents:UIControlEventValueChanged];
            }
            
            cell = accountCell;
        }
        else if (indexPath.row == accounts.count)
        {
            MXKTableViewCellWithButton *addBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!addBtnCell)
            {
                addBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            [addBtnCell.mxkButton setTitle:@"Add account" forState:UIControlStateNormal];
            [addBtnCell.mxkButton setTitle:@"Add account" forState:UIControlStateHighlighted];
            [addBtnCell.mxkButton addTarget:self action:@selector(login) forControlEvents:UIControlEventTouchUpInside];
            
            cell = addBtnCell;
        }
        else
        {
            MXKTableViewCellWithButton *logoutBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
            if (!logoutBtnCell)
            {
                logoutBtnCell = [[MXKTableViewCellWithButton alloc] init];
            }
            [logoutBtnCell.mxkButton setTitle:@"Logout all accounts" forState:UIControlStateNormal];
            [logoutBtnCell.mxkButton setTitle:@"Logout all accounts" forState:UIControlStateHighlighted];
            [logoutBtnCell.mxkButton addTarget:self action:@selector(logout) forControlEvents:UIControlEventTouchUpInside];
            
            cell = logoutBtnCell;
        }
    }
    else if (indexPath.section == recentsSectionIndex)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:@"mainTableViewCellSampleVC" forIndexPath:indexPath];
        switch (indexPath.row)
        {
            case 0:
                cell.textLabel.text = @"MXKRecentListViewController";
                break;
            case 1:
                cell.textLabel.text = @"Interleaved Recents";
                break;
        }
    }
    else if (indexPath.section == roomSectionIndex)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:@"mainTableViewCellSampleVC" forIndexPath:indexPath];
        switch (indexPath.row)
        {
            case 0:
                cell.textLabel.text = @"MXKRoomViewController";
                break;
            case 1:
                cell.textLabel.text = @"Sample with editable title and growing text input";
                break;
            case 2:
                cell.textLabel.text = @"Sample based on JSQMessagesViewController lib";
                break;
        }
    }
    else if (indexPath.section == roomMembersSectionIndex)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:@"mainTableViewCellSampleVC" forIndexPath:indexPath];
        switch (indexPath.row)
        {
            case 0:
                cell.textLabel.text = @"MXKRoomMemberListViewController";
                break;
            case 1:
                cell.textLabel.text = @"Sample with customized Table View Cell";
                break;
        }
    }
    else if (indexPath.section == authenticationSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                cell = [tableView dequeueReusableCellWithIdentifier:@"mainTableViewCellSampleVC" forIndexPath:indexPath];
                cell.textLabel.text = @"MXKAuthenticationViewController";
                break;
        }
    }
    else if (indexPath.section == contactSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                cell = [tableView dequeueReusableCellWithIdentifier:@"mainTableViewCellSampleVC" forIndexPath:indexPath];
                cell.textLabel.text = @"MXKContactListViewController";
                break;
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == accountSectionIndex)
    {
        return 50;
    }
    return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == accountSectionIndex)
    {
        NSArray *accounts = [[MXKAccountManager sharedManager] accounts];
        if (indexPath.row < accounts.count)
        {
            selectedAccount = [accounts objectAtIndex:indexPath.row];
            
            [self performSegueWithIdentifier:@"showMXKAccountDetailsViewController" sender:self];
        }
    }
    else if (indexPath.section == recentsSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                [self performSegueWithIdentifier:@"showMXKRecentListViewController" sender:self];
                break;
            case 1:
                [self performSegueWithIdentifier:@"showInterleavedRecentsViewController" sender:self];
                break;
        }
    }
    else if (indexPath.section == roomSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                [self performSegueWithIdentifier:@"showMXKRoomViewController" sender:self];
                break;
            case 1:
                [self performSegueWithIdentifier:@"showSampleRoomViewController" sender:self];
                break;
            case 2:
                [self performSegueWithIdentifier:@"showSampleJSQMessagesViewController" sender:self];
                break;
        }
    }
    else if (indexPath.section == roomMembersSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                [self performSegueWithIdentifier:@"showMXKRoomMemberListViewController" sender:self];
                break;
            case 1:
                [self performSegueWithIdentifier:@"showSampleRoomMembersViewController" sender:self];
                break;
        }
    }
    else if (indexPath.section == authenticationSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                [self performSegueWithIdentifier:@"showMXKAuthenticationViewController" sender:self];
                break;
        }
    }
    else if (indexPath.section == contactSectionIndex)
    {
        switch (indexPath.row)
        {
            case 0:
                [self performSegueWithIdentifier:@"showMXKContactListViewController" sender:self];
                break;
        }
    }
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [super prepareForSegue:segue sender:sender];
    
    id destinationViewController = segue.destinationViewController;
    
    if (([segue.identifier isEqualToString:@"showMXKRecentListViewController"] || [segue.identifier isEqualToString:@"showRoomSelector"]) && self.mainSession)
    {
        MXKRecentListViewController *recentListViewController = (MXKRecentListViewController *)destinationViewController;
        recentListViewController.delegate = self;
        
        // Prepare listDataSource
        MXKRecentsDataSource *listDataSource = [[MXKRecentsDataSource alloc] init];
        NSArray* accounts = [[MXKAccountManager sharedManager] activeAccounts];
        for (MXKAccount *account in accounts)
        {
            if (account.mxSession)
            {
                [listDataSource addMatrixSession:account.mxSession];
            }
        }
        [recentListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showInterleavedRecentsViewController"] && self.mainSession)
    {
        MXKRecentListViewController *recentListViewController = (MXKRecentListViewController *)destinationViewController;
        recentListViewController.delegate = self;
        
        // Prepare listDataSource
        MXKInterleavedRecentsDataSource *listDataSource = [[MXKInterleavedRecentsDataSource alloc] init];
        NSArray* accounts = [[MXKAccountManager sharedManager] activeAccounts];
        for (MXKAccount *account in accounts)
        {
            if (account.mxSession)
            {
                [listDataSource addMatrixSession:account.mxSession];
            }
        }
        [recentListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showMXKRoomViewController"] || [segue.identifier isEqualToString:@"showSampleRoomViewController"])
    {
        MXKRoomViewController *roomViewController = (MXKRoomViewController *)destinationViewController;
        
        // Update the RoomDataSource class at manager level
        [MXKRoomDataSourceManager registerRoomDataSourceClass:MXKRoomDataSource.class];
        
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:selectedRoom.mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:YES];
        
        [roomViewController displayRoom:roomDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleJSQMessagesViewController"])
    {
        MXKSampleJSQMessagesViewController *sampleRoomViewController = (MXKSampleJSQMessagesViewController *)destinationViewController;
        
        // Update the RoomDataSource class at manager level
        [MXKRoomDataSourceManager registerRoomDataSourceClass:MXKSampleJSQRoomDataSource.class];
        
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:selectedRoom.mxSession];
        MXKSampleJSQRoomDataSource *roomDataSource = (MXKSampleJSQRoomDataSource *)[roomDataSourceManager roomDataSourceForRoom:selectedRoom.state.roomId create:YES];
        
        [sampleRoomViewController displayRoom:roomDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showMXKRoomMemberListViewController"])
    {
        MXKRoomMemberListViewController *roomMemberListViewController = (MXKRoomMemberListViewController *)destinationViewController;
        roomMemberListViewController.delegate = self;
        
        MXKRoomMemberListDataSource *listDataSource = [[MXKRoomMemberListDataSource alloc] initWithRoomId:selectedRoom.state.roomId andMatrixSession:selectedRoom.mxSession];
        
        [listDataSource finalizeInitialization];
        
        [roomMemberListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showSampleRoomMembersViewController"])
    {
        MXKSampleRoomMembersViewController *sampleRoomMemberListViewController = (MXKSampleRoomMembersViewController *)destinationViewController;
        sampleRoomMemberListViewController.delegate = self;
        
        MXKRoomMemberListDataSource *listDataSource = [[MXKRoomMemberListDataSource alloc] initWithRoomId:selectedRoom.state.roomId andMatrixSession:selectedRoom.mxSession];
        
        // Replace default table view cell with customized cell: `MXKSampleRoomMemberTableViewCell`
        [listDataSource registerCellViewClass:MXKSampleRoomMemberTableViewCell.class forCellIdentifier:kMXKRoomMemberCellIdentifier];
        
        [listDataSource finalizeInitialization];
        
        [sampleRoomMemberListViewController displayList:listDataSource];
    }
    else if ([segue.identifier isEqualToString:@"showMXKAuthenticationViewController"])
    {
        MXKAuthenticationViewController *authViewController = (MXKAuthenticationViewController *)destinationViewController;
        authViewController.delegate = self;
        authViewController.defaultHomeServerUrl = @"https://matrix.org";
        authViewController.defaultIdentityServerUrl = @"https://matrix.org";
    }
    else if ([segue.identifier isEqualToString:@"showMXKContactListViewController"])
    {
        MXKContactListViewController *contactsController = (MXKContactListViewController *)destinationViewController;
        NSArray* accounts = [[MXKAccountManager sharedManager] activeAccounts];
        for (MXKAccount *account in accounts)
        {
            if (account.mxSession)
            {
                [contactsController addMatrixSession:account.mxSession];
            }
        }
        contactsController.delegate = self;
    }
    else if ([segue.identifier isEqualToString:@"showMXKAccountDetailsViewController"])
    {
        MXKAccountDetailsViewController *accountViewController = (MXKAccountDetailsViewController *)destinationViewController;
        accountViewController.mxAccount = selectedAccount;
    }
    else if ([segue.identifier isEqualToString:@"showMXKRoomMemberDetailsViewController"])
    {
        MXKRoomMemberDetailsViewController *memberDetails = (MXKRoomMemberDetailsViewController*)destinationViewController;
        [memberDetails displayRoomMember:selectedRoomMember withMatrixRoom:selectedRoom];
        memberDetails.delegate = self;
    }
    else if ([segue.identifier isEqualToString:@"showMXKContactDetailsViewController"])
    {
        MXKContactDetailsViewController *contactDetails = (MXKContactDetailsViewController*)destinationViewController;
        contactDetails.contact = selectedContact;
        contactDetails.delegate = self;
    }
}

#pragma mark - MXKRecentListViewControllerDelegate
- (void)recentListViewController:(MXKRecentListViewController *)recentListViewController didSelectRoom:(NSString *)roomId inMatrixSession:(MXSession *)matrixSession
{
    // Update the selected room and go back to the main page
    selectedRoom = [matrixSession roomWithRoomId:roomId];
    _selectedRoomDisplayName.text = selectedRoom.state.displayname;
    
    [self.tableView reloadData];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma  mark - MXKRoomMemberListViewControllerDelegate

- (void)roomMemberListViewController:(MXKRoomMemberListViewController *)roomMemberListViewController didSelectMember:(MXRoomMember*)member
{
    NSLog(@"Member (%@) has been selected", member.userId);
    
    selectedRoomMember = member;
    
    [self performSegueWithIdentifier:@"showMXKRoomMemberDetailsViewController" sender:self];
}

#pragma mark - MXKAuthenticationViewControllerDelegate

- (void)authenticationViewController:(MXKAuthenticationViewController *)authenticationViewController didLogWithUserId:(NSString*)userId
{
    NSLog(@"New account (%@) has been added", userId);
    
    // Go back to the main page
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - MXKCallViewControllerDelegate

- (void)dismissCallViewController:(MXKCallViewController *)callViewController
{
    if (callViewController == currentCallViewController)
    {
        
        if (callViewController.isPresented)
        {
            BOOL callIsEnded = (callViewController.mxCall.state == MXCallStateEnded);
            NSLog(@"Call view controller must be dismissed (%d)", callIsEnded);
            
            [callViewController dismissViewControllerAnimated:YES completion:^{
                callViewController.isPresented = NO;
                
                if (!callIsEnded)
                {
                    [self addCallStatusBar];
                }
            }];
            
            if (callIsEnded)
            {
                [self removeCallStatusBar];
                
                // Restore system status bar
                [UIApplication sharedApplication].statusBarHidden = NO;
                
                // Release properly
                [currentCallViewController destroy];
                currentCallViewController = nil;
            }
        }
        else
        {
            // Here the presentation of the call view controller is in progress
            // Postpone the dismiss
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissCallViewController:callViewController];
            });
        }
    }
}

#pragma mark - MXKContactListViewControllerDelegate

- (void)contactListViewController:(MXKContactListViewController *)contactListViewController didSelectContact:(NSString *)contactId
{
    selectedContact = [[MXKContactManager sharedManager] contactWithContactID:contactId];
    NSLog(@"    -> %@ has been selected", selectedContact.displayName);
    
    [self performSegueWithIdentifier:@"showMXKContactDetailsViewController" sender:self];
}

- (void)contactListViewController:(MXKContactListViewController *)contactListViewController didTapContactThumbnail:(NSString *)contactId
{
    selectedContact = [[MXKContactManager sharedManager] contactWithContactID:contactId];
    NSLog(@"    -> Avatar of %@ has been tapped", selectedContact.displayName);
}

#pragma mark - MXKRoomMemberDetailsViewControllerDelegate

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController startChatWithMemberId:(NSString *)matrixId
{
    NSLog(@"    -> Start chat with %@ is requested", matrixId);
}

#pragma mark - MXKContactDetailsViewControllerDelegate

- (void)contactDetailsViewController:(MXKContactDetailsViewController *)contactDetailsViewController startChatWithMatrixId:(NSString *)matrixId
{
    NSLog(@"    -> Start chat with %@ is requested", matrixId);
}

#pragma mark - Call status handling

- (void)addCallStatusBar
{
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

- (void)removeCallStatusBar
{
    if (callStatusBarWindow)
    {
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

- (void)returnToCallView
{
    [self removeCallStatusBar];
    
    UINavigationController *navigationController = self.navigationController;
    [navigationController.topViewController presentViewController:currentCallViewController animated:YES completion:^{
        currentCallViewController.isPresented = YES;
    }];
}

- (void)statusBarDidChangeFrame
{
    UIApplication *app = [UIApplication sharedApplication];
    UIViewController *rootController = app.keyWindow.rootViewController;
    
    // Refresh the root view controller frame
    CGRect frame = [[UIScreen mainScreen] applicationFrame];
    if (callStatusBarWindow)
    {
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
