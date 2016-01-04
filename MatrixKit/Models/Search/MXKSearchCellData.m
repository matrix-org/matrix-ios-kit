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

#import "MXKSearchCellData.h"

#import "MXKSearchDataSource.h"


@implementation MXKSearchCellData
@synthesize searchResult, title, message, date;

- (instancetype)initWithSearchResult:(MXSearchResult *)searchResult2 andSearchDataSource:(MXKSearchDataSource *)searchDataSource
{
    self = [super init];
    if (self)
    {
        searchResult = searchResult2;

        if (nil == searchDataSource.roomId)
        {
            // We are displaying a search over all user's rooms
            // As title, display the room name of this search result
            MXRoom *room = [searchDataSource.mxSession roomWithRoomId:searchResult.result.roomId];
            if (room)
            {
                title = room.state.displayname;
            }
            else
            {
                title = searchResult.result.roomId;
            }
        }
        else
        {
            // We are displaying a search within a room
            // As title, display the user id
            title = searchResult.result.userId;
        }

        date = [searchDataSource.eventFormatter dateStringFromEvent:searchResult.result withTime:YES];

        // Code from [MXEventFormatter stringFromEvent] for the particular case of a text message
        message = [searchResult.result.content[@"body"] isKindOfClass:[NSString class]] ? searchResult.result.content[@"body"] : nil;
    }
    return self;
}

@end
