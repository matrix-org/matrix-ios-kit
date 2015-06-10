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

#import "MXKRecentListDataSource.h"

#import "MXKRecentTableViewCell.h"

@interface MXKRecentListDataSource ()
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
     Array of shrinked sources.
     */
    NSMutableArray *shrinkedRecentsDataSourceArray;
}

@end

@implementation MXKRecentListDataSource

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        mxSessionArray = [NSMutableArray array];
        recentsDataSourceArray = [NSMutableArray array];
        shrinkedRecentsDataSourceArray = [NSMutableArray array];
        
        // Set default data and view classes
        [self registerCellDataClass:MXKRecentCellData.class forCellIdentifier:kMXKRecentCellIdentifier];
        [self registerCellViewClass:MXKRecentTableViewCell.class forCellIdentifier:kMXKRecentCellIdentifier];
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
        
        // Set the actual data and view classes
        [self registerCellDataClass:[self cellDataClassForCellIdentifier:kMXKRecentCellIdentifier] forCellIdentifier:kMXKRecentCellIdentifier];
        [self registerCellViewClass:[self cellViewClassForCellIdentifier:kMXKRecentCellIdentifier] forCellIdentifier:kMXKRecentCellIdentifier];
        
        [mxSessionArray addObject:matrixSession];
        
        recentsDataSource.delegate = self;
        [recentsDataSourceArray addObject:recentsDataSource];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didAddMatrixSession:)])
        {
            [self.delegate dataSource:self didAddMatrixSession:matrixSession];
        }
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
            
            [recentsDataSourceArray removeObjectAtIndex:index];
            [mxSessionArray removeObjectAtIndex:index];
            
            [self.delegate dataSource:self didCellChange:nil];
            
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
        NSLog(@"[MXKRecentListDataSource] CAUTION: mxSession property is not relevant in case of multi-sessions (%tu)", mxSessionArray.count);
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
    // Presently only a global state is available.
    // TODO: state of each internal recents data source should be public.
    
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

- (void)registerCellDataClass:(Class)cellDataClass forCellIdentifier:(NSString *)identifier
{
    [super registerCellDataClass:cellDataClass forCellIdentifier:identifier];
    
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        [recentsDataSource registerCellDataClass:cellDataClass forCellIdentifier:identifier];
    }
}

- (void)registerCellViewClass:(Class<MXKCellRendering>)cellViewClass forCellIdentifier:(NSString *)identifier
{
    [super registerCellViewClass:cellViewClass forCellIdentifier:identifier];
    
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        [recentsDataSource registerCellViewClass:cellViewClass forCellIdentifier:identifier];
    }
}

- (void)destroy
{
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        [recentsDataSource destroy];
    }
    recentsDataSourceArray = nil;
    shrinkedRecentsDataSourceArray = nil;
    mxSessionArray = nil;
    
    [super destroy];
}

#pragma mark -

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}

- (NSUInteger)unreadCount
{
    NSUInteger unreadCount = 0;
    
    // Sum unreadCount of all current data sources
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        unreadCount += recentsDataSource.unreadCount;
    }
    return unreadCount;
}

- (void)markAllAsRead
{
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        [recentsDataSource markAllAsRead];
    }
}

- (void)searchWithPatterns:(NSArray*)patternsList
{
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        [recentsDataSource searchWithPatterns:patternsList];
    }
}

- (UIView *)viewForHeaderInSection:(NSInteger)section withFrame:(CGRect)frame
{
    UIView *sectionHeader = nil;
    
    if (recentsDataSourceArray.count > 1 && section < recentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:section];
        
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
            chevron = [UIImage imageNamed:@"disclosure"];
        }
        else
        {
            chevron =[UIImage imageNamed:@"shrink"];
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
    if (indexPath.section < recentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:indexPath.section];
        
        return [recentsDataSource cellDataAtIndex:indexPath.row];
    }
    return nil;
}

- (CGFloat)cellHeightAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < recentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:indexPath.section];
        
        return [recentsDataSource cellHeightAtIndex:indexPath.row];
    }
    return 0;
}

- (NSIndexPath*)cellIndexPathWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)matrixSession
{
    NSIndexPath *indexPath = nil;
    
    // Look for the right data source
    for (NSInteger section = 0; section < mxSessionArray.count; section++)
    {
        MXSession *mxSession = [mxSessionArray objectAtIndex:section];
        if (mxSession == matrixSession)
        {
            MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:section];
            
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
    NSInteger count = 0;
    
    for (MXKSessionRecentsDataSource *recentsDataSource in recentsDataSourceArray)
    {
        if (recentsDataSource.state == MXKDataSourceStateReady && recentsDataSource.numberOfCells)
        {
            count ++;
        }
    }
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < recentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:section];
        
        // Check whether the source is shrinked
        if ([shrinkedRecentsDataSourceArray indexOfObject:recentsDataSource] == NSNotFound)
        {
            return recentsDataSource.numberOfCells;
        }
    }
    
    return 0;
}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
//
//    NSString *title = nil;
//
//    if (mxSessionArray.count > 1 && section < mxSessionArray.count){
//        MXSession *mxSession = [mxSessionArray objectAtIndex:section];
//
//        title = mxSession.myUser.displayname;
//        if (!title.length){
//            title = mxSession.myUser.userId;
//        }
//    }
//
//    return title;
//}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < recentsDataSourceArray.count)
    {
        MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:indexPath.section];
        
        id<MXKRecentCellDataStoring> roomData = [recentsDataSource cellDataAtIndex:indexPath.row];
        
        MXKRecentTableViewCell *cell  = [tableView dequeueReusableCellWithIdentifier:kMXKRecentCellIdentifier forIndexPath:indexPath];
        
        // Make the bubble display the data
        [cell render:roomData];
        
        return cell;
    }
    return nil;
}

#pragma mark - MXKDataSourceDelegate

- (void)dataSource:(MXKDataSource*)dataSource didCellChange:(id)changes
{
    [self.delegate dataSource:self didCellChange:changes];
}

- (void)dataSource:(MXKDataSource*)dataSource didStateChange:(MXKDataSourceState)state
{
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
        
        if (shrinkButton.tag < recentsDataSourceArray.count)
        {
            MXKSessionRecentsDataSource *recentsDataSource = [recentsDataSourceArray objectAtIndex:shrinkButton.tag];
            
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
            
            // Notify delegate
            [self.delegate dataSource:self didCellChange:nil];
        }
    }
}

@end
