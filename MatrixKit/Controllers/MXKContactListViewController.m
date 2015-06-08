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

#import "MXKContactListViewController.h"

// contacts management
#import "MXKContactManager.h"
#import "MXKContact.h"

#import "MXKContactTableCell.h"

#import "MXKAlert.h"

#import "MXKSectionedContacts.h"

/**
 String identifying table view cell used to display a contact.
 */
NSString *const kMXKContactTableViewCellIdentifier = @"kMXKContactTableViewCellIdentifier";

@interface MXKContactListViewController ()
{
    // YES -> only matrix users
    // NO -> display local contacts
    BOOL displayMatrixUsers;
    
    // screenshot of the local contacts
    NSArray* localContacts;
    MXKSectionedContacts* sectionedLocalContacts;
    
    // screenshot of the matrix users
    NSMutableDictionary* matrixUserByMatrixID;
    MXKSectionedContacts* sectionedMatrixContacts;
    
    // tap on thumbnail to display contact info
    MXKContact* selectedContact;
    
    // Search
    UIBarButtonItem *searchButton;
    UISearchBar     *contactsSearchBar;
    NSMutableArray  *filteredContacts;
    MXKSectionedContacts* sectionedFilteredContacts;
    BOOL             searchBarShouldEndEditing;
    NSString* latestSearchedPattern;
    
    NSArray* collationTitles;
}

@property (strong, nonatomic) MXKAlert *allowContactSyncAlert;
@end

@implementation MXKContactListViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKContactListViewController class])
                          bundle:[NSBundle bundleForClass:[MXKContactListViewController class]]];
}

+ (instancetype)contactListViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKContactListViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKContactListViewController class]]];
}

- (void)dealloc{
    searchButton = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!_contactsControls)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // get the system collation titles
    collationTitles = [[UILocalizedIndexedCollation currentCollation]sectionTitles];
    
    // global init
    displayMatrixUsers = (0 == self.contactsControls.selectedSegmentIndex);
    matrixUserByMatrixID = [[NSMutableDictionary alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onContactsRefresh:) name:kMXKContactManagerDidUpdateContactsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onContactsRefresh:) name:kMXKContactManagerDidUpdateContactMatrixIDsNotification object:nil];
    
    if (!_contactTableViewCellClass) {
        // Set default table view cell class
        self.contactTableViewCellClass = [MXKContactTableCell class];
    }
    
    // Add search option in navigation bar
    self.enableSearch = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Leave potential search session
    if (contactsSearchBar)
    {
        [self searchBarCancelButtonClicked:contactsSearchBar];
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

// should be called when resetting the application
// the contact manager warn there is a contacts list update
// but the Matrix SDK handler has no more userID -> so assume there is a reset
- (void)reset
{
    // Leave potential search session
    if (contactsSearchBar)
    {
        [self searchBarCancelButtonClicked:contactsSearchBar];
    }
    
    localContacts = nil;
    sectionedLocalContacts = nil;
    
    matrixUserByMatrixID = [[NSMutableDictionary alloc] init];;
    sectionedMatrixContacts = nil;
    
    [self.contactsControls setSelectedSegmentIndex:0];
    [self.tableView reloadData];
}

- (void)refreshMatrixUsers
{
    if (displayMatrixUsers)
    {
        if (contactsSearchBar)
        {
            [self updateSectionedMatrixContacts];
            latestSearchedPattern = nil;
            [self searchBar:contactsSearchBar textDidChange:contactsSearchBar.text];
        }
        else
        {
            [self.tableView reloadData];
        }
    }
}

#pragma mark -

-(void)setContactTableViewCellClass:(Class)contactTableViewCellClass
{
    // Sanity check: accept only MXKContactTableCell classes or sub-classes
    NSParameterAssert([contactTableViewCellClass isSubclassOfClass:MXKContactTableCell.class]);
    
    _contactTableViewCellClass = contactTableViewCellClass;
    [self.tableView registerClass:contactTableViewCellClass forCellReuseIdentifier:kMXKContactTableViewCellIdentifier];
}

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

#pragma mark - overridden MXKTableViewController methods

- (void)onMatrixSessionChange
{
    [super onMatrixSessionChange];
    
    [self refreshMatrixUsers];
}

#pragma mark - UITableView delegate

- (void)updateSectionedLocalContacts
{
    [self stopActivityIndicator];
    
    MXKContactManager* sharedManager = [MXKContactManager sharedManager];
    
    if (!localContacts)
    {
        localContacts = sharedManager.contacts;
    }
    
    if (!sectionedLocalContacts)
    {
        sectionedLocalContacts = [sharedManager getSectionedContacts:sharedManager.contacts];
    }
}

- (void)updateSectionedMatrixContacts
{
    NSArray *mxSessions = self.mxSessions;
    
    // Check whether at least one session is available
    if (!mxSessions.count)
    {
        [self startActivityIndicator];
        sectionedMatrixContacts = nil;
    }
    else
    {
        [self stopActivityIndicator];
        
        NSArray* usersIDs = [self oneToOneRoomMemberIDs];
        // return a MatrixIDs list of 1:1 room members
        
        // Update contact mapping
        // Copy the current dictionary keys (avoid delete and create the same ones, it could save thumbnail downloads)
        NSMutableArray* knownUserIDs = [[matrixUserByMatrixID allKeys] mutableCopy];
        
        for (MXSession *mxSession in mxSessions)
        {
            for(NSString* userID in usersIDs)
            {
                MXUser* user = [mxSession userWithUserId:userID];
                if (user)
                {
                    // managed UserID
                    [knownUserIDs removeObject:userID];
                    
                    MXKContact* contact = [matrixUserByMatrixID objectForKey:userID];
                    
                    // already defined
                    if (contact)
                    {
                        contact.displayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                    }
                    else
                    {
                        contact = [[MXKContact alloc] initWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) matrixID:user.userId];
                        [matrixUserByMatrixID setValue:contact forKey:userID];
                    }
                }
            }
        }
        
        // some userIDs don't exist anymore
        for (NSString* userID in knownUserIDs)
        {
            [matrixUserByMatrixID removeObjectForKey:userID];
        }
        
        sectionedMatrixContacts = [[MXKContactManager sharedManager] getSectionedContacts:[matrixUserByMatrixID allValues]];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // search in progress
    if (contactsSearchBar)
    {
        return sectionedFilteredContacts.sectionedContacts.count;
    }
    else if (displayMatrixUsers)
    {
        [self updateSectionedMatrixContacts];
        return sectionedMatrixContacts.sectionedContacts.count;
        
    }
    else
    {
        [self updateSectionedLocalContacts];
        return sectionedLocalContacts.sectionedContacts.count;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    MXKSectionedContacts* sectionedContacts = contactsSearchBar ? sectionedFilteredContacts : (displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts);
    
    return [[sectionedContacts.sectionedContacts objectAtIndex:section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MXKSectionedContacts* sectionedContacts = contactsSearchBar ? sectionedFilteredContacts : (displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts);
    
    MXKContact* contact = nil;
    
    if (indexPath.section < sectionedContacts.sectionedContacts.count)
    {
        NSArray *thisSection = [sectionedContacts.sectionedContacts objectAtIndex:indexPath.section];
        
        if (indexPath.row < thisSection.count)
        {
            contact = [thisSection objectAtIndex:indexPath.row];
        }
    }
    
    return [((Class<MXKCellRendering>)_contactTableViewCellClass) heightForCellData:contact withMaximumWidth:tableView.frame.size.width];
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
    if (contactsSearchBar)
    {
        // Hide section titles during search session
        return nil;
    }
    
    MXKSectionedContacts* sectionedContacts = contactsSearchBar ? sectionedFilteredContacts : (displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts);
    
    if (sectionedContacts.sectionTitles.count <= section)
    {
        return nil;
    }
    else
    {
        return (NSString*)[sectionedContacts.sectionTitles objectAtIndex:section];
    }
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)aTableView
{
    // do not display the collation during a search
    if (contactsSearchBar)
    {
        return nil;
    }
    
    return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)aTableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    MXKSectionedContacts* sectionedContacts = contactsSearchBar ? sectionedFilteredContacts : (displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts);
    NSUInteger section = [sectionedContacts.sectionTitles indexOfObject:title];
    
    // undefined title -> jump to the first valid non empty section
    if (NSNotFound == section)
    {
        NSUInteger systemCollationIndex = [collationTitles indexOfObject:title];
        
        // find in the system collation
        if (NSNotFound != systemCollationIndex)
        {
            systemCollationIndex--;
            
            while ((systemCollationIndex == 0) && (NSNotFound == section))
            {
                NSString* systemTitle = [collationTitles objectAtIndex:systemCollationIndex];
                section = [sectionedContacts.sectionTitles indexOfObject:systemTitle];
                systemCollationIndex--;
            }
        }
    }
    
    return section;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // In case of search, the section titles are hidden and the search bar is displayed in first section header.
    if (contactsSearchBar)
    {
        if (section == 0)
        {
            return contactsSearchBar.frame.size.height;
        }
        return 0;
    }
    
    // Default section header height
    return 22;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (contactsSearchBar && section == 0)
    {
        return contactsSearchBar;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MXKContactTableCell* cell = [tableView dequeueReusableCellWithIdentifier:kMXKContactTableViewCellIdentifier forIndexPath:indexPath];
    
    MXKSectionedContacts* sectionedContacts = contactsSearchBar ? sectionedFilteredContacts : (displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts);
    
    MXKContact* contact = nil;
    
    if (indexPath.section < sectionedContacts.sectionedContacts.count)
    {
        NSArray *thisSection = [sectionedContacts.sectionedContacts objectAtIndex:indexPath.section];
        
        if (indexPath.row < thisSection.count)
        {
            contact = [thisSection objectAtIndex:indexPath.row];
        }
    }
    
    [cell render:contact];
    cell.delegate = self;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MXKSectionedContacts* sectionedContacts = contactsSearchBar ? sectionedFilteredContacts : (displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts);
    
    MXKContact* contact = nil;
    
    if (indexPath.section < sectionedContacts.sectionedContacts.count)
    {
        NSArray *thisSection = [sectionedContacts.sectionedContacts objectAtIndex:indexPath.section];
        
        if (indexPath.row < thisSection.count)
        {
            contact = [thisSection objectAtIndex:indexPath.row];
        }
    }
    
    if (self.delegate) {
        [self.delegate contactListViewController:self didSelectContact:contact.contactID];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // Release here resources, and restore reusable cells
    if ([cell respondsToSelector:@selector(didEndDisplay)])
    {
        [(id<MXKCellRendering>)cell didEndDisplay];
    }
}

#pragma mark - Actions

- (void)onContactsRefresh:(NSNotification *)notif
{
    // Consider here only global notifications, ignore notifications related to a specific contact.
    if (notif.object) {
        return;
    }
    
    localContacts = nil;
    sectionedLocalContacts = nil;
    
    // there is an user id
    if (self.mxSessions)
    {
        [self updateSectionedLocalContacts];
        //
        if (!displayMatrixUsers)
        {
            if (contactsSearchBar)
            {
                latestSearchedPattern = nil;
                [self searchBar:contactsSearchBar textDidChange:contactsSearchBar.text];
            }
            else
            {
                [self.tableView reloadData];
            }
        }
    }
    else
    {
        // the client could have been logged out
        [self reset];
    }
}

- (IBAction)onSegmentValueChange:(id)sender
{
    if (sender == self.contactsControls)
    {
        displayMatrixUsers = (0 == self.contactsControls.selectedSegmentIndex);
        
        if (contactsSearchBar)
        {
            if (displayMatrixUsers)
            {
                [self updateSectionedMatrixContacts];
            }
            else
            {
                [self updateSectionedLocalContacts];
            }
            
            latestSearchedPattern = nil;
            [self searchBar:contactsSearchBar textDidChange:contactsSearchBar.text];
        }
        else
        {
            [self.tableView reloadData];
        }
    }
}

#pragma mark MFMessageComposeViewControllerDelegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Search management

- (void)search:(id)sender
{
    if (!contactsSearchBar)
    {
        MXKSectionedContacts* sectionedContacts = displayMatrixUsers ? sectionedMatrixContacts : sectionedLocalContacts;
        
        // Check whether there are data in which search
        if (sectionedContacts.sectionedContacts.count > 0)
        {
            // Create search bar
            contactsSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
            contactsSearchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            contactsSearchBar.showsCancelButton = YES;
            contactsSearchBar.returnKeyType = UIReturnKeyDone;
            contactsSearchBar.delegate = self;
            searchBarShouldEndEditing = NO;
            
            // init the table content
            latestSearchedPattern = @"";
            filteredContacts = [(displayMatrixUsers ? [matrixUserByMatrixID allValues] : localContacts) mutableCopy];
            sectionedFilteredContacts = [[MXKContactManager sharedManager] getSectionedContacts:filteredContacts];
            
            [self.tableView reloadData];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [contactsSearchBar becomeFirstResponder];
            });
        }
    }
    else
    {
        [self searchBarCancelButtonClicked:contactsSearchBar];
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

- (NSArray*)patternsFromText:(NSString*)text
{
    NSArray* items = [text componentsSeparatedByString:@" "];
    
    if (items.count <= 1)
    {
        return items;
    }
    
    NSMutableArray* patterns = [[NSMutableArray alloc] init];
    
    for (NSString* item in items)
    {
        if (item.length > 0)
        {
            [patterns addObject:item];
        }
    }
    
    return patterns;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ((contactsSearchBar == searchBar) && (![latestSearchedPattern isEqualToString:searchText]))
    {
        latestSearchedPattern = searchText;
        
        // contacts
        NSArray* contacts = displayMatrixUsers ? [matrixUserByMatrixID allValues] : localContacts;
        
        // Update filtered list
        if (searchText.length && contacts.count)
        {
            
            filteredContacts = [[NSMutableArray alloc] init];
            
            NSArray* patterns = [self patternsFromText:searchText];
            for(MXKContact* contact in contacts)
            {
                if ([contact matchedWithPatterns:patterns])
                {
                    [filteredContacts addObject:contact];
                }
            }
        }
        else
        {
            filteredContacts = [contacts mutableCopy];
        }
        
        sectionedFilteredContacts = [[MXKContactManager sharedManager] getSectionedContacts:filteredContacts];
        
        // Refresh display
        [self.tableView reloadData];
        [self scrollToTop];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    if (contactsSearchBar == searchBar)
    {
        // "Done" key has been pressed
        searchBarShouldEndEditing = YES;
        [contactsSearchBar resignFirstResponder];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    if (contactsSearchBar == searchBar)
    {
        // Leave search
        searchBarShouldEndEditing = YES;
        [contactsSearchBar resignFirstResponder];
        [contactsSearchBar removeFromSuperview];
        contactsSearchBar = nil;
        filteredContacts = nil;
        sectionedFilteredContacts = nil;
        latestSearchedPattern = nil;
        [self.tableView reloadData];
        [self scrollToTop];
    }
}

#pragma mark - MXKCellRendering delegate

- (void)cell:(id<MXKCellRendering>)cell didRecognizeAction:(NSString*)actionIdentifier userInfo:(NSDictionary *)userInfo
{
    if ([actionIdentifier isEqualToString:kMXKContactCellTapOnThumbnailView])
    { 
        if (self.delegate) {
            [self.delegate contactListViewController:self didTapContactThumbnail:userInfo[kMXKContactCellContactIdKey]];
        }
    }
}

#pragma mark - Matrix session handling

// return a MatrixIDs list of 1:1 room members
- (NSArray*)oneToOneRoomMemberIDs
{
    NSMutableArray* matrixIDs = [[NSMutableArray alloc] init];
    
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        for (MXRoom *mxRoom in mxSession.rooms)
        {
            NSArray* membersList = [mxRoom.state members];
            
            // keep only 1:1 chat
            if ([mxRoom.state members].count <= 2)
            {
                for (MXRoomMember* member in membersList)
                {
                    // not myself
                    if (![member.userId isEqualToString:mxSession.myUser.userId])
                    {
                        if ([matrixIDs indexOfObject:member.userId] == NSNotFound)
                        {
                            [matrixIDs addObject:member.userId];
                        }
                    }
                }
            }
        }
    }
    
    return matrixIDs;
}

@end
