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

#import "MXKRecentsDataSource.h"

#import "NSBundle+MatrixKit.h"

#import "MXKConstants.h"

#import "MXKMediaManager.h"

@interface MXKRecentsDataSource ()
{
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    
    /**
     Array of `MXKSessionRecentsDataSource` instances (one by matrix session).
     */
    NSMutableArray *recentsDataSourceArray;
    
    /**
     The current search pattern list
     */
    NSArray* searchPatternsList;
    
    /*
     While muting a room, the dedicated rule might be deleted before creating a new one.
     The creation must be done after the deletion has been confirmed.
     The confirmation is done with a notification.
     */
    NSMutableDictionary* ruleDidUpdateObserverByRoomId;
    NSMutableDictionary* ruleDidFailUpdateObserverByRoomId;
}

@end

@implementation MXKRecentsDataSource

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        mxSessionArray = [NSMutableArray array];
        recentsDataSourceArray = [NSMutableArray array];
        
        displayedRecentsDataSourceArray = [NSMutableArray array];
        shrinkedRecentsDataSourceArray = [NSMutableArray array];
        
        // Set default data and view classes
        [self registerCellDataClass:MXKRecentCellData.class forCellIdentifier:kMXKRecentCellIdentifier];

        ruleDidUpdateObserverByRoomId = [[NSMutableDictionary alloc] init];
        ruleDidFailUpdateObserverByRoomId = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    self = [self init];
    if (self)
    {
        [self addMatrixSession:matrixSession];
    }
    return self;
}

- (void)addMatrixSession:(MXSession *)matrixSession
{
    MXKSessionRecentsDataSource *recentsDataSource = [[MXKSessionRecentsDataSource alloc] initWithMatrixSession:matrixSession];
    
    if (recentsDataSource)
    {
        // Report the shared event formatter (if any)
        if (_eventFormatter)
        {
            recentsDataSource.eventFormatter = _eventFormatter;
        }
        
        // Set the actual data and view classes
        [recentsDataSource registerCellDataClass:[self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier] forCellIdentifier:kMXKRecentCellIdentifier];
        
        [mxSessionArray addObject:matrixSession];
        
        recentsDataSource.delegate = self;
        [recentsDataSourceArray addObject:recentsDataSource];
        
        [recentsDataSource finalizeInitialization];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didAddMatrixSession:)])
        {
            [self.delegate dataSource:self didAddMatrixSession:matrixSession];
        }
        
        // Check the current state of the data source
        [self dataSource:recentsDataSource didStateChange:recentsDataSource.state];
    }
}

- (void)removeMatrixSession:(MXSession*)matrixSession
{
    for (NSUInteger index = 0; index < mxSessionArray.count; index++)
    {
        MXSession *mxSession = [mxSessionArray objectAtIndex:index];
        if (mxSession == matrixSession)
        {
            MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:index];
            [recentsDataSource destroy];
            
            [displayedRecentsDataSourceArray removeObject:recentsDataSource];
            
            [recentsDataSourceArray removeObjectAtIndex:index];
            [mxSessionArray removeObjectAtIndex:index];
            
            // Loop on 'didCellChange' method to let inherited 'MXKRecentsDataSource' class handle this removed data source.
            [self dataSource:recentsDataSource didCellChange:nil];
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didRemoveMatrixSession:)])
            {
                [self.delegate dataSource:self didRemoveMatrixSession:matrixSession];
            }
            
            break;
        }
    }
}

#pragma mark - MXKDataSource overridden

- (MXSession*)mxSession
{
    if (mxSessionArray.count > 1)
    {
        NSLog(@"[MXKRecentsDataSource] CAUTION: mxSession property is not relevant in case of multi-sessions (%tu)", mxSessionArray.count);
    }
    
    // TODO: This property is not well adapted in case of multi-sessions
    // We consider by default the first added session as the main one...
    if (mxSessionArray.count)
    {
        return [mxSessionArray firstObject];
    }
    return nil;
}

- (MXKDataSourceState)state
{
    // Manage a global state based on the state of each internal data source.
    
    MXKDataSourceState currentState = MXKDataSourceStateUnknown;
    MXKSessionRecentsDataSource *dataSource;
    
    if (recentsDataSourceArray.count)
    { 
        dataSource = [recentsDataSourceArray firstObject];
        currentState = dataSource.state;
        
        // Deduce the current state according to the internal data sources
        for (NSUInteger index = 1; index < recentsDataSourceArray.count; index++)
        {
            dataSource = [recentsDataSourceArray objectAtIndex:index];
            
            switch (dataSource.state)
            {
                case MXKDataSourceStateUnknown:
                    break;
                case MXKDataSourceStatePreparing:
                    currentState = MXKDataSourceStatePreparing;
                    break;
                case MXKDataSourceStateFailed:
                    if (currentState == MXKDataSourceStateUnknown)
                    {
                        currentState = MXKDataSourceStateFailed;
                    }
                    break;
                case MXKDataSourceStateReady:
                    if (currentState == MXKDataSourceStateUnknown || currentState == MXKDataSourceStateFailed)
                    {
                        currentState = MXKDataSourceStateReady;
                    }
                    break;
                    
                default:
                    break;
            }
        }
    }
    
    return currentState;
}

- (void)destroy
{
    // remove any observer
    if (ruleDidUpdateObserverByRoomId || ruleDidFailUpdateObserverByRoomId)
    {
        NSMutableArray *observers = [[NSMutableArray alloc] init];
        
        if (ruleDidUpdateObserverByRoomId)
        {
            [observers addObjectsFromArray:[ruleDidUpdateObserverByRoomId allValues]];
            ruleDidUpdateObserverByRoomId = nil;
        }
        
        if (ruleDidFailUpdateObserverByRoomId)
        {
            [observers addObjectsFromArray:[ruleDidFailUpdateObserverByRoomId allValues]];
            ruleDidFailUpdateObserverByRoomId = nil;
        }
        
        for(id observer in observers)
        {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }
    }
    
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        [recentsDataSource destroy];
    }
    displayedRecentsDataSourceArray = nil;
    recentsDataSourceArray = nil;
    shrinkedRecentsDataSourceArray = nil;
    mxSessionArray = nil;
    
    searchPatternsList = nil;
    
    [super destroy];
}

#pragma mark -

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}

- (NSUInteger)displayedRecentsDataSourcesCount
{
    return displayedRecentsDataSourceArray.count;
}

- (NSUInteger)unreadCount
{
    NSUInteger unreadCount = 0;
    
    // Sum unreadCount of all ready data sources
    for (MXKSessionRecentsDataSource *recentsDataSource in displayedRecentsDataSourceArray)
    {
        unreadCount += recentsDataSource.unreadCount;
    }
    return unreadCount;
}

- (void)setEventFormatter:(MXKEventFormatter *)eventFormatter
{
    _eventFormatter = eventFormatter;
    
    // Report this formatter in all existing dataSource
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        recentsDataSource.eventFormatter = eventFormatter;
    }
}

- (void)markAllAsRead
{
    for (MXKSessionRecentsDataSource *recentsDataSource in displayedRecentsDataSourceArray)
    {
        [recentsDataSource markAllAsRead];
    }
}

- (void)searchWithPatterns:(NSArray*)patternsList
{
    searchPatternsList = patternsList;
    
    // CAUTION: Apply here the search pattern to all ready data sources (not only displayed ones).
    // Some data sources may have been removed from 'displayedRecentsDataSourceArray' during a previous search if no recent was matching.
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        if (recentsDataSource.state == MXKDataSourceStateReady)
        {
            [recentsDataSource searchWithPatterns:patternsList];
        }
    }
}

- (UIView *)viewForHeaderInSection:(NSInteger)section withFrame:(CGRect)frame
{
    UIView *sectionHeader = nil;
    
    if (displayedRecentsDataSourceArray.count > 1 && section < displayedRecentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [displayedRecentsDataSourceArray objectAtIndex:section];
        
        NSString* sectionTitle = recentsDataSource.mxSession.myUser.userId;
        
        if (recentsDataSource.unreadCount)
        {
            sectionTitle = [NSString stringWithFormat:@"%@ (%tu)", sectionTitle, recentsDataSource.unreadCount];
        }
        
        sectionHeader = [[UIView alloc] initWithFrame:frame];
        sectionHeader.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
        
        // Add shrink button
        UIButton *shrinkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = sectionHeader.frame;
        frame.origin.x = frame.origin.y = 0;
        shrinkButton.frame = frame;
        shrinkButton.backgroundColor = [UIColor clearColor];
        [shrinkButton addTarget:self action:@selector(onButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        shrinkButton.tag = section;
        [sectionHeader addSubview:shrinkButton];
        sectionHeader.userInteractionEnabled = YES;
        
        // Add shrink icon
        UIImage *chevron;
        if ([shrinkedRecentsDataSourceArray indexOfObject:recentsDataSource] != NSNotFound)
        {
            chevron = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"disclosure"];
        }
        else
        {
            chevron = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"shrink"];
        }
        UIImageView *chevronView = [[UIImageView alloc] initWithImage:chevron];
        chevronView.contentMode = UIViewContentModeCenter;
        frame = chevronView.frame;
        frame.origin.x = sectionHeader.frame.size.width - frame.size.width - 8;
        frame.origin.y = (sectionHeader.frame.size.height - frame.size.height) / 2;
        chevronView.frame = frame;
        [sectionHeader addSubview:chevronView];
        chevronView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
        
        // Add label
        frame = sectionHeader.frame;
        frame.origin.x = 5;
        frame.origin.y = 5;
        frame.size.width = chevronView.frame.origin.x - 10;
        frame.size.height -= 10;
        UILabel *headerLabel = [[UILabel alloc] initWithFrame:frame];
        headerLabel.font = [UIFont boldSystemFontOfSize:16];
        headerLabel.backgroundColor = [UIColor clearColor];
        headerLabel.text = sectionTitle;
        [sectionHeader addSubview:headerLabel];
    }
    
    return sectionHeader;
}

- (id<MXKRecentCellDataStoring>)cellDataAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < displayedRecentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [displayedRecentsDataSourceArray objectAtIndex:indexPath.section];
        
        return [recentsDataSource cellDataAtIndex:indexPath.row];
    }
    return nil;
}

- (CGFloat)cellHeightAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < displayedRecentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [displayedRecentsDataSourceArray objectAtIndex:indexPath.section];
        
        return [recentsDataSource cellHeightAtIndex:indexPath.row];
    }
    return 0;
}

- (NSIndexPath*)cellIndexPathWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)matrixSession
{
    NSIndexPath *indexPath = nil;
    
    // Look for the right data source
    for (NSInteger section = 0; section < displayedRecentsDataSourceArray.count; section++)
    {
        MXKSessionRecentsDataSource *recentsDataSource = displayedRecentsDataSourceArray[section];
        if (recentsDataSource.mxSession == matrixSession)
        {
            // Check whether the source is not shrinked
            if ([shrinkedRecentsDataSourceArray indexOfObject:recentsDataSource] == NSNotFound)
            {
                // Look for the cell
                for (NSInteger index = 0; index < recentsDataSource.numberOfCells; index ++)
                {
                    id<MXKRecentCellDataStoring> recentCellData = [recentsDataSource cellDataAtIndex:index];
                    if ([roomId isEqualToString:recentCellData.roomDataSource.roomId])
                    {
                        // Got it
                        indexPath = [NSIndexPath indexPathForRow:index inSection:section];
                        break;
                    }
                }
            }
            break;
        }
    }
    
    return indexPath;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Check whether all data sources are ready before rendering recents
    if (self.state == MXKDataSourceStateReady)
    {
        return displayedRecentsDataSourceArray.count;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < displayedRecentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [displayedRecentsDataSourceArray objectAtIndex:section];
        
        // Check whether the source is shrinked
        if ([shrinkedRecentsDataSourceArray indexOfObject:recentsDataSource] == NSNotFound)
        {
            return recentsDataSource.numberOfCells;
        }
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < displayedRecentsDataSourceArray.count && self.delegate)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [displayedRecentsDataSourceArray objectAtIndex:indexPath.section];
        
        id<MXKRecentCellDataStoring> roomData = [recentsDataSource cellDataAtIndex:indexPath.row];
        
        NSString *cellIdentifier = [self.delegate cellReuseIdentifierForCellData:roomData];
        if (cellIdentifier)
        {
            UITableViewCell<MXKCellRendering> *cell  = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
            
            // Make the bubble display the data
            [cell render:roomData];
            
            return cell;
        }
    }
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [self leaveRoomAtIndexPath:indexPath];
    }
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    // Retrieve the class from the delegate here
    if (self.delegate)
    {
        return [self.delegate cellViewClassForCellData:cellData];
    }
    
    return nil;
}

- (NSString *)cellReuseIdentifierForCellData:(MXKCellData*)cellData
{
    // Retrieve the identifier from the delegate here
    if (self.delegate)
    {
        return [self.delegate cellReuseIdentifierForCellData:cellData];
    }
    
    return nil;
}

- (void)dataSource:(MXKDataSource*)dataSource didCellChange:(id)changes
{
    // Keep update readyRecentsDataSourceArray by checking number of cells
    if (dataSource.state == MXKDataSourceStateReady)
    {
        MXKSessionRecentsDataSource *recentsDataSource = (MXKSessionRecentsDataSource*)dataSource;
        
        if (recentsDataSource.numberOfCells)
        {
            // Check whether the data source must be added
            if ([displayedRecentsDataSourceArray indexOfObject:recentsDataSource] == NSNotFound)
            {
                // Add this data source first
                [self dataSource:dataSource didStateChange:dataSource.state];
                return;
            }
        }
        else
        {
            // Check whether this data source must be removed
            if ([displayedRecentsDataSourceArray indexOfObject:recentsDataSource] != NSNotFound)
            {
                [displayedRecentsDataSourceArray removeObject:recentsDataSource];
                
                // Loop on 'didCellChange' method to let inherited 'MXKRecentsDataSource' class handle this removed data source.
                [self dataSource:recentsDataSource didCellChange:nil];
                return;
            }
        }
    }
    
    // Notify delegate
    [self.delegate dataSource:self didCellChange:changes];
}

- (void)dataSource:(MXKDataSource*)dataSource didStateChange:(MXKDataSourceState)state
{
    // Update list of ready data sources
    MXKSessionRecentsDataSource *recentsDataSource = (MXKSessionRecentsDataSource*)dataSource;
    if (dataSource.state == MXKDataSourceStateReady && recentsDataSource.numberOfCells)
    {
        if ([displayedRecentsDataSourceArray indexOfObject:recentsDataSource] == NSNotFound)
        {
            // Add this new recents data source.
            if (!displayedRecentsDataSourceArray.count)
            {
                [displayedRecentsDataSourceArray addObject:recentsDataSource];
            }
            else
            {
                // To display multiple accounts in a consistent order, we sort the recents data source by considering the account user id (alphabetic order).
                NSUInteger index;
                for (index = 0; index < displayedRecentsDataSourceArray.count; index++)
                {
                    MXKSessionRecentsDataSource *currentRecentsDataSource = displayedRecentsDataSourceArray[index];
                    if ([currentRecentsDataSource.mxSession.myUser.userId compare:recentsDataSource.mxSession.myUser.userId] == NSOrderedDescending)
                    {
                        break;
                    }
                }
                
                // Insert this data source
                [displayedRecentsDataSourceArray insertObject:recentsDataSource atIndex:index];
            }
            
            // Check whether a search session is in progress
            if (searchPatternsList)
            {
                [recentsDataSource searchWithPatterns:searchPatternsList];
            }
            else
            {
                // Loop on 'didCellChange' method to let inherited 'MXKRecentsDataSource' class handle this new added data source.
                [self dataSource:recentsDataSource didCellChange:nil];
            }
        }
    }
    else if ([displayedRecentsDataSourceArray indexOfObject:recentsDataSource] != NSNotFound)
    {
        [displayedRecentsDataSourceArray removeObject:recentsDataSource];
        
        // Loop on 'didCellChange' method to let inherited 'MXKRecentsDataSource' class handle this removed data source.
        [self dataSource:recentsDataSource didCellChange:nil];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
    {
        [self.delegate dataSource:self didStateChange:self.state];
    }
}

#pragma mark - Action

- (IBAction)onButtonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        UIButton *shrinkButton = (UIButton*)sender;
        
        if (shrinkButton.tag < displayedRecentsDataSourceArray.count)
        {
            MXKSessionRecentsDataSource *recentsDataSource = [displayedRecentsDataSourceArray objectAtIndex:shrinkButton.tag];
            
            NSUInteger index = [shrinkedRecentsDataSourceArray indexOfObject:recentsDataSource];
            if (index != NSNotFound)
            {
                // Disclose the
                [shrinkedRecentsDataSourceArray removeObjectAtIndex:index];
            }
            else
            {
                // Shrink the recents from this session
                [shrinkedRecentsDataSourceArray addObject:recentsDataSource];
            }
            
            // Loop on 'didCellChange' method to let inherited 'MXKRecentsDataSource' class handle change on this data source.
            [self dataSource:recentsDataSource didCellChange:nil];
        }
    }
}

#pragma mark - room actions
- (MXRoom*)getRoomAtIndexPath:(NSIndexPath *)indexPath
{
    // Leave the selected room
    id<MXKRecentCellDataStoring> recentCellData = [self cellDataAtIndexPath:indexPath];
    
    if (recentCellData)
    {
        return recentCellData.roomDataSource.room;
    }
    
    return nil;
}

- (void)leaveRoomAtIndexPath:(NSIndexPath *)indexPath
{
    MXRoom* room = [self getRoomAtIndexPath:indexPath];
    
    if (room)
    {
        // cancel pending uploads/downloads
        // they are useless by now
        [MXKMediaManager cancelDownloadsInCacheFolder:room.state.roomId];
        
        // TODO GFO cancel pending uploads related to this room
        
        [room leave:^{
            
            // Refresh table display
            if (self.delegate)
            {
                [self.delegate dataSource:self didCellChange:nil];
            }
            
        } failure:^(NSError *error) {
            
            NSLog(@"[MXKRecentsDataSource] Failed to leave room (%@) failed: %@", room.state.roomId, error);
            
            // Notify MatrixKit user
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
        }];
    }
}

/**
 Update the room tag at the index path
 
 @param indexPath the index of the cell
 @param tag the new tag value
 */
- (void)updateRoomTagAtIndexPath:(NSIndexPath *)indexPath to:(NSString*)newtag
{
    MXRoom* room = [self getRoomAtIndexPath:indexPath];
    
    if (room)
    {
        NSString* oldTag = nil;
        
        // sanity cg
        if (room.accountData.tags && room.accountData.tags.count)
        {
            oldTag = [room.accountData.tags.allKeys objectAtIndex:0];
        }
        
        // support only kMXRoomTagFavourite or kMXRoomTagLowPriority tags by now
        if (![newtag isEqualToString:kMXRoomTagFavourite] && ![newtag isEqualToString:kMXRoomTagLowPriority])
        {
            newtag = nil;
        }
        
        NSString* tagOrder = [room.mxSession tagOrderToBeAtIndex:0 withTag:newtag];
        
        NSLog(@"[MXKRecentsDataSource] Update the room %@ tag from %@ to %@ with tag order %@", room.state.roomId, oldTag, newtag, tagOrder);
        
        [room replaceTag:oldTag
                   byTag:newtag
               withOrder:tagOrder
                 success: ^{
            
            // Refresh table display
            if (self.delegate)
            {
                [self.delegate dataSource:self didCellChange:nil];
            }
            
        } failure:^(NSError *error) {
            
            NSLog(@"[MXKRecentsDataSource] Failed to update the tag %@ of room (%@) failed: %@", newtag, room.state.roomId, error);
            
            // Notify MatrixKit user
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
        }];
    }
}

- (MXPushRule*)getPushRulesForRoom:(MXRoom*)room
{
    if (room)
    {
        NSArray* rules = room.mxSession.notificationCenter.rules.global.room;
        
        // sanity checks
        if (rules)
        {
            for(MXPushRule* rule in rules)
            {
                // the rule id is the room Id
                // it is the server trick to avoid duplicated rule on the same room.
                if ([rule.ruleId isEqualToString:room.state.roomId])
                {
                    return rule;
                }
            }
        }
    }
    
    return nil;
}

/**
 Check if there is a push notification rules for the room at the position indexPath
 
 @param indexPath the index of the cell
 @return YES if there is a push rules.
 */
- (BOOL)isRoomNotifiedAtIndexPath:(NSIndexPath *)indexPath
{
    MXRoom* room = [self getRoomAtIndexPath:indexPath];
    MXPushRule* rule = [self getPushRulesForRoom:room];
    
    if (rule)
    {
        for (MXPushRuleAction *ruleAction in rule.actions)
        {
            if (ruleAction.actionType == MXPushRuleActionTypeDontNotify)
            {
                return !rule.enabled;
            }
        }
    }
    
    return YES;
}

- (void)muteRoomNotifications:(BOOL)mute atIndexPath:(NSIndexPath *)indexPath
{
    MXRoom* room = [self getRoomAtIndexPath:indexPath];
 
    // sanity check
    if (room)
    {
        BOOL isNotified = [self isRoomNotifiedAtIndexPath:indexPath];
        
        // check if the state is already in the right state
        if (isNotified == !mute)
        {
            return;
        }
        
        MXNotificationCenter* notificationCenter = room.mxSession.notificationCenter;
        MXPushRule* rule = [self getPushRulesForRoom:room];
        
        if (!mute)
        {
            // let the other notification rules manage the pushes.
            [notificationCenter removeRule:rule];
        }
        else
        {
            // user does not want to have push
            
            // if there is no rule
            if (!rule)
            {
                // add one
                [notificationCenter addRoomRule:room.state.roomId
                                                    notify:NO
                                                     sound:NO
                                                 highlight:NO];
            }
            else
            {
                // check if there is no pending update for this room
                if ([ruleDidUpdateObserverByRoomId objectForKey:room.state.roomId])
                {
                    // if there is one, ignore the current request
                    return;
                }
                
                
                // check if the user did not define one
                BOOL hasDontNotifyRule = NO;
                
                for (MXPushRuleAction *ruleAction in rule.actions)
                {
                    if (ruleAction.actionType == MXPushRuleActionTypeDontNotify)
                    {
                        hasDontNotifyRule = YES;
                        break;
                    }
                }
                
                // if the user defined one, use it
                if (hasDontNotifyRule)
                {
                    [notificationCenter enableRule:rule isEnabled:YES];
                }
                else
                {
                    // if the user defined a room rule
                    // the rule is deleted before adding new one
                    
                    id notificationCenterDidUpdateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXNotificationCenterDidUpdateRules object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

                        MXPushRule* rule = [self getPushRulesForRoom:room];
                        
                        // check if the rule has been deleted
                        // there is no way to know if the notif is really for this rule..
                        if (!rule)
                        {
                            id observer = [ruleDidUpdateObserverByRoomId objectForKey:room.state.roomId];
                            
                            if (observer)
                            {
                                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                                [ruleDidUpdateObserverByRoomId removeObjectForKey:room.state.roomId];
                            }
                            
                            observer = [ruleDidFailUpdateObserverByRoomId objectForKey:room.state.roomId];
                            
                            if (observer)
                            {
                                [[NSNotificationCenter defaultCenter] removeObserver:observer];
                                [ruleDidFailUpdateObserverByRoomId removeObjectForKey:room.state.roomId];
                            }
                            
                            // add one
                            [notificationCenter addRoomRule:room.state.roomId
                                                     notify:NO
                                                      sound:NO
                                                  highlight:NO];
                        }
                    }];
                    
                    id notificationCenterDidFailObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXNotificationCenterDidFailRulesUpdate object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {

                        id observer = [ruleDidUpdateObserverByRoomId objectForKey:room.state.roomId];
                        
                        if (observer)
                        {
                            [[NSNotificationCenter defaultCenter] removeObserver:observer];
                            [ruleDidUpdateObserverByRoomId removeObjectForKey:room.state.roomId];
                        }
                        
                        observer = [ruleDidFailUpdateObserverByRoomId objectForKey:room.state.roomId];
                        
                        if (observer)
                        {
                            [[NSNotificationCenter defaultCenter] removeObserver:observer];
                            [ruleDidFailUpdateObserverByRoomId removeObjectForKey:room.state.roomId];
                        }
                    }];
                    
                    [ruleDidUpdateObserverByRoomId setObject:notificationCenterDidUpdateObserver forKey:room.state.roomId];
                    [ruleDidFailUpdateObserverByRoomId setObject:notificationCenterDidFailObserver forKey:room.state.roomId];
                    
                    // remove the rule notification
                    // the notifications are used to tell
                    [notificationCenter removeRule:rule];
                }
            }
        }
    }
}

@end
