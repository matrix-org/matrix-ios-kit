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

#import "MXKDataSource.h"
#import "MXKSearchCellDataStoring.h"

#import "MXKEventFormatter.h"

/**
 String identifying the object used to store and prepare a search cell data.
 */
extern NSString *const kMXKSearchCellDataIdentifier;

/**
 The data source for `MXKRoomMemberListViewController`.
 
 Use the `initWithMatrixSession:` constructor to search in all user's rooms.
 Use the `initWithRoomId:andMatrixSession: constructor to search in a specific room.
 */
@interface MXKSearchDataSource : MXKDataSource <UITableViewDataSource>

/**
 The current search.
 */
@property (nonatomic, readonly) NSString *searchText;

/**
 If any the id of the room where the search is made.
 */
@property (nonatomic, readonly) NSString *roomId;

/**
 Total number of results available on the server.
 */
@property (nonatomic, readonly) NSUInteger serverCount;

/**
 The events to display texts formatter.
 `MXKSearchCellDataStoring` instances can use it to format text.
 */
@property (nonatomic) MXKEventFormatter *eventFormatter;

/**
 Flag indicating if there are still results (in the past) to get with paginateBack.
 */
@property (nonatomic, readonly) BOOL canPaginate;


/**
 Initialise the data source to search messages in the passed room.

 @param roomId the id of the room to search for.
 @param mxSession the Matrix session to get data from.
 @return the newly created instance.
 */
- (instancetype)initWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)mxSession;

/**
 Launch a message search homeserver side.
 
 @param text the text to search.
 */
- (void)searchMessageText:(NSString*)text;

/**
 Load more results from the past.
 */
- (void)paginateBack;

/**
 Get the data for the cell at the given index.

 @param index the index of the cell in the array
 @return the cell data
 */
- (id<MXKSearchCellDataStoring>)cellDataAtIndex:(NSInteger)index;

@end
