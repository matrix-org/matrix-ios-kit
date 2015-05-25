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
    
    /**
     Search handling
     */
    UIBarButtonItem *searchButton;
    BOOL searchBarShouldEndEditing;
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

+ (instancetype)roomViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRecentListViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRecentListViewController class]]];
}

#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!_recentsTableView) {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // Adjust Top and Bottom constraints to take into account potential navBar and tabBar.
    if ([NSLayoutConstraint respondsToSelector:@selector(deactivateConstraints:)]) {
        [NSLayoutConstraint deactivateConstraints:@[_recentsSearchBarTopConstraint, _recentsTableViewBottomConstraint]];
    } else {
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
    
    if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)]) {
        [NSLayoutConstraint activateConstraints:@[_recentsSearchBarTopConstraint, _recentsTableViewBottomConstraint]];
    } else {
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
    
    // Check whether a room has been defined
    if (dataSource) {
        [self configureView];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Leave potential search session
    if (!self.recentsSearchBar.isHidden) {
        [self searchBarCancelButtonClicked:self.recentsSearchBar];
    }
}

- (void)dealloc {
    self.recentsSearchBar.inputAccessoryView = nil;

    searchButton = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    // Dispose of any resources that can be recreated.
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // Patch: Auto-layout issue.
    // Issue observed when 'MXKRecentListViewController' instance is used by the master view controller of a split view controller.
    // Back to recents after screen rotation (landscape to portrait) make the recents disappear (table frame size = (0, 0)).
    
    CGRect searchBarFrame = self.recentsSearchBar.frame;
    CGRect tableViewFrame = self.recentsTableView.frame;
    BOOL isSearchFrameUpdated = NO;
    
    if (searchBarFrame.size.width == 0) {
        searchBarFrame.size.width = self.view.frame.size.width;
        searchBarFrame.size.height = self.recentsSearchBar.isHidden ? 0 : 44;
        self.recentsSearchBar.frame = searchBarFrame;
        isSearchFrameUpdated = YES;
        
        NSLog(@"[MXKRecentListVC] restore recentsSearchBar frame: %f %f", searchBarFrame.size.width, searchBarFrame.size.height);
    }
    
    if (isSearchFrameUpdated || tableViewFrame.size.width == 0) {
        tableViewFrame.origin.y = searchBarFrame.origin.y + searchBarFrame.size.height;
        tableViewFrame.size.width = self.view.frame.size.width;
        tableViewFrame.size.height = self.view.frame.size.height - tableViewFrame.origin.y - _recentsTableViewBottomConstraint.constant - self.bottomLayoutGuide.length;
        self.recentsTableView.frame = tableViewFrame;
        
        NSLog(@"[MXKRecentListVC] restore recentsTableView frame: %f %f", tableViewFrame.size.width, tableViewFrame.size.height);
    }
}

#pragma mark - Override MXKTableViewController

- (void)onKeyboardShowAnimationComplete {
    // Report the keyboard view in order to track keyboard frame changes
    self.keyboardView = _recentsSearchBar.inputAccessoryView.superview;
}

- (void)setKeyboardHeight:(CGFloat)keyboardHeight {
    
    // Deduce the bottom constraint for the table view (Don't forget the potential tabBar)
    CGFloat tableViewBottomConst = keyboardHeight - self.bottomLayoutGuide.length;
    // Check whether the keyboard is over the tabBar
    if (tableViewBottomConst < 0) {
        tableViewBottomConst = 0;
    }
    
    // Update constraints
    _recentsTableViewBottomConstraint.constant = tableViewBottomConst;
    
    // Force layout immediately to take into account new constraint
    [self.view layoutIfNeeded];
}

- (void)destroy {
    
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

- (void)configureView {

    self.recentsTableView.delegate = self;

    // Set up table data source
    self.recentsTableView.dataSource = dataSource;
    
    if (dataSource) {
        // Set up classes to use for cells
        if ([[dataSource cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] nib]) {
            [self.recentsTableView registerNib:[[dataSource cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] nib] forCellReuseIdentifier:kMXKRecentCellIdentifier];
        } else {
            [self.recentsTableView registerClass:[dataSource cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] forCellReuseIdentifier:kMXKRecentCellIdentifier];
        }
    }
}

#pragma mark -

- (void)setEnableSearch:(BOOL)enableSearch {
    if (enableSearch) {
        if (!searchButton) {
            searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(search:)];
        }
        
        // Add it in right bar items
        NSArray *rightBarButtonItems = self.navigationItem.rightBarButtonItems;
        self.navigationItem.rightBarButtonItems = rightBarButtonItems ? [rightBarButtonItems arrayByAddingObject:searchButton] : @[searchButton];
    } else {
        NSMutableArray *rightBarButtonItems = [NSMutableArray arrayWithArray: self.navigationItem.rightBarButtonItems];
        [rightBarButtonItems removeObject:searchButton];
        self.navigationItem.rightBarButtonItems = rightBarButtonItems;
    }
}

- (void)displayList:(MXKRecentListDataSource *)listDataSource {

    // Cancel registration on existing dataSource if any
    if (dataSource) {
        dataSource.delegate = nil;
    }
    
    dataSource = listDataSource;
    dataSource.delegate = self;
    
    // Report the matrix session at view controller level to update UI according to session state
    self.mxSession = dataSource.mxSession;

    if (self.recentsTableView) {
        [self configureView];
    }
}

#pragma mark - Action

- (IBAction)search:(id)sender {
    if (self.recentsSearchBar.isHidden) {
        // Check whether there are data in which search
        if ([self.dataSource numberOfSectionsInTableView:self.recentsTableView]) {
            self.recentsSearchBar.hidden = NO;
            self.recentsSearchBarHeightConstraint.constant = 44;
            [self.view setNeedsUpdateConstraints];
            
            // Create search bar
            searchBarShouldEndEditing = NO;
            [self.recentsSearchBar becomeFirstResponder];
        }
    } else {
        [self searchBarCancelButtonClicked: self.recentsSearchBar];
    }
}

#pragma mark - MXKDataSourceDelegate

- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes {
    // For now, do a simple full reload
    [self.recentsTableView reloadData];
}


#pragma mark - UITableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    return [dataSource cellHeightAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (_delegate) {
        id<MXKRecentCellDataStoring> cellData = [dataSource cellDataAtIndexPath:indexPath];

        [_delegate recentListViewController:self didSelectRoom:cellData.roomDataSource.roomId inMatrixSession:cellData.roomDataSource.mxSession];
    }
    
    // Hide the keyboard when user select a room
    // do not hide the searchBar until the view controller disappear
    // on tablets / iphone 6+, the user could expect to search again while looking at a room
    if ([self.recentsSearchBar isFirstResponder]) {
        searchBarShouldEndEditing = YES;
        [self.recentsSearchBar resignFirstResponder];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath {
    
    // Release here resources, and restore reusable cells
    if ([cell respondsToSelector:@selector(didEndDisplay)]) {
        [(id<MXKCellRendering>)cell didEndDisplay];
    }
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    searchBarShouldEndEditing = NO;
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    return searchBarShouldEndEditing;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    
    // Apply filter
    if (searchText.length) {
        [self.dataSource searchWithPatterns:@[searchText]];
    } else {
        [self.dataSource searchWithPatterns:nil];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    // "Done" key has been pressed
    searchBarShouldEndEditing = YES;
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    
    // Leave search
    searchBarShouldEndEditing = YES;
    [searchBar resignFirstResponder];

    self.recentsSearchBar.hidden = YES;
    self.recentsSearchBarHeightConstraint.constant = 0;
    [self.view setNeedsUpdateConstraints];
    
    // Refresh display
    [self.dataSource searchWithPatterns:nil];
}

@end
