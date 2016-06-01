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

#import "MXKRoomDataSourceManager.h"

#import "MXKInterleavedRecentsDataSource.h"
#import "MXKInterleavedRecentTableViewCell.h"

@interface MXKRecentListViewController ()
{
    /**
     The data source providing UITableViewCells
     */
    MXKRecentsDataSource *dataSource;
    
    /**
     Search handling
     */
    UIBarButtonItem *searchButton;
    BOOL ignoreSearchRequest;
    
    /**
     The reconnection animated view.
     */
    UIView* reconnectingView;
    
    /**
     The latest server sync date
     */
    NSDate* latestServerSync;
    
    /**
     The restart the event connnection
     */
    BOOL restartConnection;
}

@end

@implementation MXKRecentListViewController
@synthesize dataSource;

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRecentListViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRecentListViewController class]]];
}

+ (instancetype)recentListViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRecentListViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRecentListViewController class]]];
}

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!_recentsTableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // Adjust Top and Bottom constraints to take into account potential navBar and tabBar.
    if ([NSLayoutConstraint respondsToSelector:@selector(deactivateConstraints:)])
    {
        [NSLayoutConstraint deactivateConstraints:@[_recentsSearchBarTopConstraint, _recentsTableViewBottomConstraint]];
    }
    else
    {
        [self.view removeConstraint:_recentsSearchBarTopConstraint];
        [self.view removeConstraint:_recentsTableViewBottomConstraint];
    }
    
    _recentsSearchBarTopConstraint = [NSLayoutConstraint constraintWithItem:self.topLayoutGuide
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.recentsSearchBar
                                                                  attribute:NSLayoutAttributeTop
                                                                 multiplier:1.0f
                                                                   constant:0.0f];
    
    _recentsTableViewBottomConstraint = [NSLayoutConstraint constraintWithItem:self.bottomLayoutGuide
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.recentsTableView
                                                                     attribute:NSLayoutAttributeBottom
                                                                    multiplier:1.0f
                                                                      constant:0.0f];
    
    if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
    {
        [NSLayoutConstraint activateConstraints:@[_recentsSearchBarTopConstraint, _recentsTableViewBottomConstraint]];
    }
    else
    {
        [self.view addConstraint:_recentsSearchBarTopConstraint];
        [self.view addConstraint:_recentsTableViewBottomConstraint];
    }
    
    // Patch: Auto-layout issue.
    // Issue observed when 'MXKRecentListViewController' instance is used by the master view controller of a split view controller.
    // Back to recents after screen rotation (landscape to portrait) make the recents disappear (table frame size = (0, 0)).
    [self.recentsSearchBar addObserver:self forKeyPath:NSStringFromSelector(@selector(frame)) options:0 context:nil];
    [self.recentsSearchBar addObserver:self forKeyPath:NSStringFromSelector(@selector(center)) options:0 context:nil];
    [self.recentsTableView addObserver:self forKeyPath:NSStringFromSelector(@selector(frame)) options:0 context:nil];
    [self.recentsTableView addObserver:self forKeyPath:NSStringFromSelector(@selector(center)) options:0 context:nil];
    
    // Hide search bar by default
    self.recentsSearchBar.hidden = YES;
    self.recentsSearchBarHeightConstraint.constant = 0;
    [self.view setNeedsUpdateConstraints];
    
    // Add search option in navigation bar
    self.enableSearch = YES;
    
    // Add an accessory view to the search bar in order to retrieve keyboard view.
    self.recentsSearchBar.inputAccessoryView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // Finalize table view configuration
    self.recentsTableView.delegate = self;
    self.recentsTableView.dataSource = dataSource; // Note: dataSource may be nil here
    
    // Set up classes to use for cells
    [self.recentsTableView registerNib:MXKRecentTableViewCell.nib forCellReuseIdentifier:MXKRecentTableViewCell.defaultReuseIdentifier];
    // Consider here the specific case where interleaved recents are supported
    [self.recentsTableView registerNib:MXKInterleavedRecentTableViewCell.nib forCellReuseIdentifier:MXKInterleavedRecentTableViewCell.defaultReuseIdentifier];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Restore search mechanism (if enabled)
    ignoreSearchRequest = NO;

    // Observe server sync at room data source level too
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMatrixSessionChange) name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    
    // Observe the server sync
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSyncNotification) name:kMXSessionDidSyncNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // The user may still press search button whereas the view disappears
    ignoreSearchRequest = YES;

    // Leave potential search session
    if (!self.recentsSearchBar.isHidden)
    {
        [self searchBarCancelButtonClicked:self.recentsSearchBar];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDidSyncNotification object:nil];
    
    [self removeReconnectingView];
}

- (void)dealloc
{
    self.recentsSearchBar.inputAccessoryView = nil;
    
    searchButton = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Patch: Auto-layout issue.
    // Issue observed when 'MXKRecentListViewController' instance is used by the master view controller of a split view controller.
    // Back to recents after screen rotation (landscape to portrait) make the recents disappear (table frame size = (0, 0)).
    
    CGRect searchBarFrame = self.recentsSearchBar.frame;
    CGRect tableViewFrame = self.recentsTableView.frame;
    BOOL isSearchFrameUpdated = NO;
    
    if (searchBarFrame.size.width == 0)
    {
        searchBarFrame.size.width = self.view.frame.size.width;
        searchBarFrame.size.height = self.recentsSearchBar.isHidden ? 0 : 44;
        self.recentsSearchBar.frame = searchBarFrame;
        isSearchFrameUpdated = YES;
        
        NSLog(@"[MXKRecentListVC] restore recentsSearchBar frame: %f %f", searchBarFrame.size.width, searchBarFrame.size.height);
    }
    
    if (isSearchFrameUpdated || tableViewFrame.size.width == 0)
    {
        tableViewFrame.origin.y = searchBarFrame.origin.y + searchBarFrame.size.height;
        tableViewFrame.size.width = self.view.frame.size.width;
        tableViewFrame.size.height = self.view.frame.size.height - tableViewFrame.origin.y - _recentsTableViewBottomConstraint.constant - self.bottomLayoutGuide.length;
        self.recentsTableView.frame = tableViewFrame;
        
        NSLog(@"[MXKRecentListVC] restore recentsTableView frame: %f %f", tableViewFrame.size.width, tableViewFrame.size.height);
    }
}

#pragma mark - Override MXKViewController

- (void)onMatrixSessionChange
{
    [super onMatrixSessionChange];
    
    // Check whether no server sync is in progress in room data sources
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        if ([MXKRoomDataSourceManager sharedManagerForMatrixSession:mxSession].isServerSyncInProgress)
        {
            // sync is in progress for at least one data source, keep running the loading wheel
            [self.activityIndicator startAnimating];
            break;
        }
    }
}

- (void)onKeyboardShowAnimationComplete
{
    // Report the keyboard view in order to track keyboard frame changes
    self.keyboardView = _recentsSearchBar.inputAccessoryView.superview;
}

- (void)setKeyboardHeight:(CGFloat)keyboardHeight
{
    // Deduce the bottom constraint for the table view (Don't forget the potential tabBar)
    CGFloat tableViewBottomConst = keyboardHeight - self.bottomLayoutGuide.length;
    // Check whether the keyboard is over the tabBar
    if (tableViewBottomConst < 0)
    {
        tableViewBottomConst = 0;
    }
    
    // Update constraints
    _recentsTableViewBottomConstraint.constant = tableViewBottomConst;
    
    // Force layout immediately to take into account new constraint
    [self.view layoutIfNeeded];
}

- (void)destroy
{
    // Remove view observers
    [self.recentsSearchBar removeObserver:self forKeyPath:NSStringFromSelector(@selector(frame))];
    [self.recentsSearchBar removeObserver:self forKeyPath:NSStringFromSelector(@selector(center))];
    [self.recentsTableView removeObserver:self forKeyPath:NSStringFromSelector(@selector(frame))];
    [self.recentsTableView removeObserver:self forKeyPath:NSStringFromSelector(@selector(center))];
    
    self.recentsTableView.dataSource = nil;
    self.recentsTableView.delegate = nil;
    self.recentsTableView = nil;
    
    dataSource.delegate = nil;
    dataSource = nil;
    
    _delegate = nil;
    
    [super destroy];
}

#pragma mark -

- (void)setEnableSearch:(BOOL)enableSearch
{
    if (enableSearch)
    {
        if (!searchButton)
        {
            searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(search:)];
        }
        
        // Add it in right bar items
        NSArray *rightBarButtonItems = self.navigationItem.rightBarButtonItems;
        self.navigationItem.rightBarButtonItems = rightBarButtonItems ? [rightBarButtonItems arrayByAddingObject:searchButton] : @[searchButton];
    }
    else
    {
        NSMutableArray *rightBarButtonItems = [NSMutableArray arrayWithArray: self.navigationItem.rightBarButtonItems];
        [rightBarButtonItems removeObject:searchButton];
        self.navigationItem.rightBarButtonItems = rightBarButtonItems;
    }
}

- (void)displayList:(MXKRecentsDataSource *)listDataSource
{
    // Cancel registration on existing dataSource if any
    if (dataSource)
    {
        dataSource.delegate = nil;
        
        // Remove associated matrix sessions
        NSArray *mxSessions = self.mxSessions;
        for (MXSession *mxSession in mxSessions)
        {
            [self removeMatrixSession:mxSession];
        }
    }
    
    dataSource = listDataSource;
    dataSource.delegate = self;
    
    // Report all matrix sessions at view controller level to update UI according to sessions state
    NSArray *mxSessions = listDataSource.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        [self addMatrixSession:mxSession];
    }
    
    if (self.recentsTableView)
    {
        // Set up table data source
        self.recentsTableView.dataSource = dataSource;
    }
}

#pragma mark - Action

- (IBAction)search:(id)sender
{
    // The user may have pressed search button whereas the view controller was disappearing
    if (ignoreSearchRequest)
    {
        return;
    }
    
    if (self.recentsSearchBar.isHidden)
    {
        // Check whether there are data in which search
        if ([self.dataSource numberOfSectionsInTableView:self.recentsTableView])
        {
            self.recentsSearchBar.hidden = NO;
            self.recentsSearchBarHeightConstraint.constant = 44;
            [self.view setNeedsUpdateConstraints];
            
            // Create search bar
            [self.recentsSearchBar becomeFirstResponder];
        }
    }
    else
    {
        [self searchBarCancelButtonClicked: self.recentsSearchBar];
    }
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    // Consider here the specific case where interleaved recents are supported
    if ([dataSource isKindOfClass:MXKInterleavedRecentsDataSource.class])
    {
        return MXKInterleavedRecentTableViewCell.class;
    }
    
    // Return the default recent table view cell
    return MXKRecentTableViewCell.class;
}

- (NSString *)cellReuseIdentifierForCellData:(MXKCellData*)cellData
{
    // Consider here the specific case where interleaved recents are supported
    if ([dataSource isKindOfClass:MXKInterleavedRecentsDataSource.class])
    {
        return MXKInterleavedRecentTableViewCell.defaultReuseIdentifier;
    }
    
    // Return the default recent table view cell
    return MXKRecentTableViewCell.defaultReuseIdentifier;
}

- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes
{
    // For now, do a simple full reload
    [self.recentsTableView reloadData];
}

- (void)dataSource:(MXKDataSource *)dataSource didAddMatrixSession:(MXSession *)mxSession
{
    [self addMatrixSession:mxSession];
}

- (void)dataSource:(MXKDataSource *)dataSource didRemoveMatrixSession:(MXSession *)mxSession
{
    [self removeMatrixSession:mxSession];
}

#pragma mark - UITableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [dataSource cellHeightAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Section header is required only when several recent lists are displayed.
    if (self.dataSource.displayedRecentsDataSourcesCount > 1)
    {
        return 35;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Let dataSource provide the section header.
    return [dataSource viewForHeaderInSection:section withFrame:[tableView rectForHeaderInSection:section]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_delegate)
    {
        id<MXKRecentCellDataStoring> cellData = [dataSource cellDataAtIndexPath:indexPath];
        
        [_delegate recentListViewController:self didSelectRoom:cellData.roomDataSource.roomId inMatrixSession:cellData.roomDataSource.mxSession];
    }
    
    // Hide the keyboard when user select a room
    // do not hide the searchBar until the view controller disappear
    // on tablets / iphone 6+, the user could expect to search again while looking at a room
    [self.recentsSearchBar resignFirstResponder];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // Release here resources, and restore reusable cells
    if ([cell respondsToSelector:@selector(didEndDisplay)])
    {
        [(id<MXKCellRendering>)cell didEndDisplay];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView == _recentsTableView && scrollView.contentSize.height)
    {
        if (scrollView.contentOffset.y <= 0)
        {
            self.recentsTableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
        }
        else
        {
            self.recentsTableView.backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // Detect vertical bounce at the top of the tableview to trigger pagination
    if (scrollView == _recentsTableView)
    {
        [self detectPullToKick:scrollView];
        
        if (targetContentOffset->y <= 0 && scrollView.contentSize.height)
        {
            self.recentsTableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
        }
        else
        {
            self.recentsTableView.backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == _recentsTableView)
    {
        [self managePullToKick:scrollView];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == _recentsTableView)
    {
        if (scrollView.contentOffset.y == 0)
        {
            [self managePullToKick:scrollView];
        }
    }
}


#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    // Apply filter
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
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    // Leave search
    [searchBar resignFirstResponder];
    
    self.recentsSearchBar.hidden = YES;
    self.recentsSearchBarHeightConstraint.constant = 0;
    [self.view setNeedsUpdateConstraints];
    
    self.recentsSearchBar.text = nil;
    
    // Refresh display
    [self.dataSource searchWithPatterns:nil];
}

#pragma mark - resync management

- (void)onSyncNotification
{
    latestServerSync = [NSDate date];
    [self removeReconnectingView];
}

- (BOOL)canReconnect
{
    // avoid restarting connection if some data has been received within 1 second (1000 : latestServerSync is null)
    NSTimeInterval interval = latestServerSync ? [[NSDate date] timeIntervalSinceDate:latestServerSync] : 1000;
    return  (interval > 1) && [self.mainSession reconnect];
}

- (void)addReconnectingView
{
    if (!reconnectingView)
    {
        UIActivityIndicatorView* spinner  = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.transform = CGAffineTransformMakeScale(0.75f, 0.75f);
        CGRect frame = spinner.frame;
        frame.size.height = 80; // 80 * 0.75 = 60
        spinner.bounds = frame;
        
        spinner.color = [UIColor darkGrayColor];
        spinner.hidesWhenStopped = NO;
        spinner.backgroundColor = [UIColor clearColor];
        [spinner startAnimating];
        
        // no need to manage constraints here, IOS defines them.
        _recentsTableView.tableHeaderView = reconnectingView = spinner;
    }
}

- (void)removeReconnectingView
{
    if (reconnectingView && !restartConnection)
    {
        _recentsTableView.tableHeaderView = reconnectingView = nil;
    }
}

/**
 Detect if the current connection must be restarted.
 The spinner is displayed until the overscroll ends (and scrollViewDidEndDecelerating is called).
 */
- (void)detectPullToKick:(UIScrollView *)scrollView
{
    if (!reconnectingView)
    {
        // detect if the user scrolls over the tableview top
        restartConnection = (scrollView.contentOffset.y < -128);
        
        if (restartConnection)
        {
            // wait that list decelerate to display / hide it
            [self addReconnectingView];
        }
    }
}


/**
 Restarts the current connection if it is required.
 The 0.3s delay is added to avoid flickering if the connection does not require to be restarted.
 */
- (void)managePullToKick:(UIScrollView *)scrollView
{
    // the current connection must be restarted
    if (restartConnection)
    {
        // display at least 0.3s the spinner to show to the user that something is pending
        // else the UI is flickering
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            restartConnection = NO;
            
            if (![self canReconnect])
            {
                // if the event stream has not been restarted
                // hide the spinner
                [self removeReconnectingView];
            }
            // else wait that onSyncNotification is called.
        });
    }
}

@end
