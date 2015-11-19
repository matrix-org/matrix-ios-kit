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

#import "MXKRoomDetailsViewController.h"

@implementation MXKRoomDetailsViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomDetailsViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRoomDetailsViewController class]]];
}

+ (instancetype)roomDetailsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRoomDetailsViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRoomDetailsViewController class]]];
}

#pragma mark - Public API

/**
 Set the dedicated session and the room Id
 */
- (void) initWithSession:(MXSession*)aSession andRoomId:(NSString*)aRoomId
{
    _session = aSession;
    _roomId = aRoomId;
}


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

@end
