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

#import "MXKRoomMemberTableViewCell.h" // imported here to provide 'updateActivityInfo' definition.

#import "MXKAlert.h"

@interface MXKRoomMemberListViewController ()
{
    /**
     The data source providing UITableViewCells
     */
    MXKRoomMemberListDataSource *dataSource;
    
    /**
     Timer used to update members presence
     */
    NSTimer* presenceUpdateTimer;
    
    /**
     Optional bar buttons
     */
    UIBarButtonItem *searchBarButton;
    UIBarButtonItem *addBarButton;
    
    /**
     The current displayed alert (if any).
     */
    MXKAlert *currentAlert;
    
    /**
     Search bar
     */
    UISearchBar  *roomMembersSearchBar;
    BOOL searchBarShouldEndEditing;
    
    /**
     Used to auto scroll at the top when search session is started or cancelled.
     */
    BOOL shouldScrollToTopOnRefresh;
    
    /**
     Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
     */
    id kMXSessionWillLeaveRoomNotificationObserver;
}

@end

@implementation MXKRoomMemberListViewController
@synthesize dataSource;

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    searchBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(search:)];
    addBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(inviteNewMember:)];
    
    // Enable both bar button by default.
    _enableMemberInvitation = YES;
    _enableMemberSearch = YES;
    [self refreshUIBarButtons];
    
    // Check whether a room has been defined
    if (dataSource)
    {
        [self configureView];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Check whether the user still belongs to the room's members.
    if (self.dataSource && [self.mainSession roomWithRoomId:self.dataSource.roomId])
    {
        
        [self refreshUIBarButtons];
        
        // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
        kMXSessionWillLeaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif)
        {
            
            // Check whether the user will leave the room related to the displayed member list
            if (notif.object == self.mainSession)
            {
                NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
                if (roomId && [roomId isEqualToString:self.dataSource.roomId])
                {
                    // We remove the current view controller.
                    [self withdrawViewControllerAnimated:YES completion:nil];
                }
            }
        }];
    }
    else
    {
        // We remove the current view controller.
        [self withdrawViewControllerAnimated:YES completion:nil];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (kMXSessionWillLeaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXSessionWillLeaveRoomNotificationObserver];
        kMXSessionWillLeaveRoomNotificationObserver = nil;
    }
    
    // Leave potential search session
    if (roomMembersSearchBar)
    {
        [self searchBarCancelButtonClicked:roomMembersSearchBar];
    }
}

- (void)dealloc
{
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

#pragma mark - Override MXKTableViewController

- (void)destroy
{
    if (presenceUpdateTimer)
    {
        [presenceUpdateTimer invalidate];
        presenceUpdateTimer = nil;
    }
    
    self.tableView.dataSource = nil;
    self.tableView.delegate = nil;
    self.tableView = nil;
    dataSource.delegate = nil;
    dataSource = nil;
    
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    roomMembersSearchBar = nil;
    searchBarButton = nil;
    addBarButton = nil;
    
    _delegate = nil;
    
    [super destroy];
}

#pragma mark - Internal methods

- (void)configureView
{
    self.tableView.delegate = self;
    
    // Set up table data source
    self.tableView.dataSource = dataSource;
    
    // Set up classes to use for cells
    if ([[dataSource cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier] nib])
    {
        [self.tableView registerNib:[[dataSource cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier] nib] forCellReuseIdentifier:kMXKRoomMemberCellIdentifier];
    }
    else
    {
        [self.tableView registerClass:[dataSource cellViewClassForCellIdentifier:kMXKRoomMemberCellIdentifier] forCellReuseIdentifier:kMXKRoomMemberCellIdentifier];
    }
}

- (void)scrollToTop
{
    // stop any scrolling effect
    [UIView setAnimationsEnabled:NO];
    // before scrolling to the tableview top
    self.tableView.contentOffset = CGPointMake(-self.tableView.contentInset.left, -self.tableView.contentInset.top);
    [UIView setAnimationsEnabled:YES];
}

- (void)updateMembersActivityInfo
{
    for (id memberCell in self.tableView.visibleCells)
    {
        if ([memberCell respondsToSelector:@selector(updateActivityInfo)])
        {
            [memberCell updateActivityInfo];
        }
    }
}

#pragma mark - UIBarButton handling

- (void)setEnableMemberSearch:(BOOL)enableMemberSearch
{
    _enableMemberSearch = enableMemberSearch;
    [self refreshUIBarButtons];
}

- (void)setEnableMemberInvitation:(BOOL)enableMemberInvitation
{
    _enableMemberInvitation = enableMemberInvitation;
    [self refreshUIBarButtons];
    
}

- (void)refreshUIBarButtons
{
    BOOL showInvitationOption = _enableMemberInvitation;
    
    if (showInvitationOption && dataSource)
    {
        // Check conditions to be able to invite someone
        MXRoom *mxRoom = [self.mainSession roomWithRoomId:dataSource.roomId];
        NSUInteger oneSelfPowerLevel = [mxRoom.state.powerLevels powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
        if (oneSelfPowerLevel < [mxRoom.state.powerLevels invite])
        {
            showInvitationOption = NO;
        }
    }
    
    if (showInvitationOption)
    {
        if (_enableMemberSearch)
        {
            self.navigationItem.rightBarButtonItems = @[searchBarButton, addBarButton];
        }
        else
        {
            self.navigationItem.rightBarButtonItems = @[addBarButton];
        }
    }
    else if (_enableMemberSearch)
    {
        self.navigationItem.rightBarButtonItems = @[searchBarButton];
    }
    else
    {
        self.navigationItem.rightBarButtonItems = nil;
    }
}

#pragma mark -
- (void)displayList:(MXKRoomMemberListDataSource *)listDataSource
{
    if (dataSource)
    {
        dataSource.delegate = nil;
        dataSource = nil;
        [self removeMatrixSession:self.mainSession];
    }
    
    dataSource = listDataSource;
    dataSource.delegate = self;
    
    // Report the matrix session at view controller level to update UI according to session state
    [self addMatrixSession:dataSource.mxSession];
    
    if (self.tableView)
    {
        [self configureView];
    }
}

#pragma mark - MXKDataSourceDelegate
- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes
{
    if (presenceUpdateTimer)
    {
        [presenceUpdateTimer invalidate];
        presenceUpdateTimer = nil;
    }
    
    // For now, do a simple full reload
    [self.tableView reloadData];
    
    if (shouldScrollToTopOnRefresh)
    {
        [self scrollToTop];
        shouldScrollToTopOnRefresh = NO;
    }
    
    // Place a timer to update members's activity information
    presenceUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(updateMembersActivityInfo) userInfo:self repeats:YES];
}

#pragma mark - UITableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [dataSource cellHeightAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_delegate)
    {
        id<MXKRoomMemberCellDataStoring> cellData = [dataSource cellDataAtIndex:indexPath.row];
        
        [_delegate roomMemberListViewController:self didSelectMember:cellData.roomMember];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (roomMembersSearchBar)
    {
        return (roomMembersSearchBar.frame.size.height);
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return roomMembersSearchBar;
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // Release here resources, and restore reusable cells
    if ([cell respondsToSelector:@selector(didEndDisplay)])
    {
        [(id<MXKCellRendering>)cell didEndDisplay];
    }
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    searchBarShouldEndEditing = NO;
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar
{
    return searchBarShouldEndEditing;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    // Apply filter
    shouldScrollToTopOnRefresh = YES;
    if (searchText.length)
    {
        [self.dataSource searchWithPatterns:@[searchText]];
    }
    else
    {
        [self.dataSource searchWithPatterns:nil];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // "Done" key has been pressed
    searchBarShouldEndEditing = YES;
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    // Leave search
    searchBarShouldEndEditing = YES;
    [searchBar resignFirstResponder];
    roomMembersSearchBar = nil;
    
    // Refresh display
    shouldScrollToTopOnRefresh = YES;
    [self.dataSource searchWithPatterns:nil];
}

#pragma mark - Actions

- (void)search:(id)sender
{
    if (!roomMembersSearchBar)
    {
        // Check whether there are data in which search
        if ([self.dataSource tableView:self.tableView numberOfRowsInSection:0])
        {
            // Create search bar
            roomMembersSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
            roomMembersSearchBar.showsCancelButton = YES;
            roomMembersSearchBar.returnKeyType = UIReturnKeyDone;
            roomMembersSearchBar.delegate = self;
            searchBarShouldEndEditing = NO;
            [roomMembersSearchBar becomeFirstResponder];
            
            // Force table refresh to add search bar in section header
            shouldScrollToTopOnRefresh = YES;
            [self dataSource:self.dataSource didCellChange:nil];
        }
    }
    else
    {
        [self searchBarCancelButtonClicked: roomMembersSearchBar];
    }
}

- (void)inviteNewMember:(id)sender
{
    __weak typeof(self) weakSelf = self;
    
    // Ask for userId to invite
    currentAlert = [[MXKAlert alloc] initWithTitle:@"User ID:" message:nil style:MXKAlertStyleAlert];
    currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:@"Cancel" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
    {
        typeof(self) self = weakSelf;
        self->currentAlert = nil;
    }];
    
    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField)
    {
        textField.secureTextEntry = NO;
        textField.placeholder = @"ex: @bob:homeserver";
    }];
    [currentAlert addActionWithTitle:@"Invite" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
    {
        UITextField *textField = [alert textFieldAtIndex:0];
        NSString *userId = textField.text;
        
        typeof(self) self = weakSelf;
        self->currentAlert = nil;
        
        if (userId.length)
        {
            MXRoom *mxRoom = [self.mainSession roomWithRoomId:self.dataSource.roomId];
            if (mxRoom)
            {
                [mxRoom inviteUser:userId success:^{
                } failure:^(NSError *error)
                {
                    NSLog(@"[MXKRoomVC] Invite %@ failed: %@", userId, error);
                    // TODO: Alert user
                    //        [[AppDelegate theDelegate] showErrorAsAlert:error];
                }];
            }
        }
    }];
    
    [currentAlert showInViewController:self];
}

@end
