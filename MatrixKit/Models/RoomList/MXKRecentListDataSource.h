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

#import "MXKSessionRecentsDataSource.h"

/**
 The recents data source for `MXKRecentsViewController`. This data source handles one or more matrix sessions.
 */
@interface MXKRecentListDataSource : MXKDataSource <UITableViewDataSource, MXKDataSourceDelegate>

/**
 List of associated matrix sessions.
 */
@property (nonatomic, readonly) NSArray* mxSessions;

/**
 The total count of unread messages.
 */
@property (nonatomic, readonly) NSUInteger unreadCount;

/**
 Add recents data from a matrix session.
 
 @param mxSession the Matrix session to retrieve contextual data.
 */
- (void)addMatrixSession:(MXSession*)mxSession;

/**
 Remove recents data related to a matrix session.
 
 @param mxSession the session to remove.
 */
- (void)removeMatrixSession:(MXSession*)mxSession;

/**
 Mark all messages as read
 */
- (void)markAllAsRead;

/**
 Filter the current recents list according to the provided patterns.
 
 @param patternsList the list of patterns (`NSString` instances) to match with. Set nil to cancel search.
 */
- (void)searchWithPatterns:(NSArray*)patternsList;

/**
 Get the section header view.
 
 @param section the section  index
 @param frame the drawing area for the header of the specified section.
 @return the section header.
 */
- (UIView *)viewForHeaderInSection:(NSInteger)section withFrame:(CGRect)frame;

/**
 Get the data for the cell at the given index path.

 @param indexPath the index of the cell
 @return the cell data
 */
- (id<MXKRecentCellDataStoring>)cellDataAtIndexPath:(NSIndexPath*)indexPath;

/**
 Get the height of the cell at the given index path.

 @param indexPath the index of the cell
 @return the cell height
 */
- (CGFloat)cellHeightAtIndexPath:(NSIndexPath*)indexPath;

/**
 Get the index path of the cell related to the provided roomId and session.
 
 @param roomId the room identifier.
 @param mxSession the matrix session in which the room should be available.
 @return indexPath the index of the cell (nil if not found).
 */
- (NSIndexPath*)cellIndexPathWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)mxSession;

@end
