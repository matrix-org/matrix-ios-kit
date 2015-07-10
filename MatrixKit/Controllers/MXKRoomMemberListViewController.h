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

#import <UIKit/UIKit.h>

#import "MXKTableViewController.h"
#import "MXKRoomMemberListDataSource.h"

@class MXKRoomMemberListViewController;

/**
 `MXKRoomMemberListViewController` delegate.
 */
@protocol MXKRoomMemberListViewControllerDelegate <NSObject>

/**
 Tells the delegate that the user selected a member.

 @param roomMemberListViewController the `MXKRoomMemberListViewController` instance.
 @param member the selected member.
 */
- (void)roomMemberListViewController:(MXKRoomMemberListViewController *)roomMemberListViewController didSelectMember:(MXRoomMember*)member;

@end


/**
 This view controller displays members of a room. Only one matrix session is handled by this view controller.
 */
@interface MXKRoomMemberListViewController : MXKTableViewController <MXKDataSourceDelegate, UISearchBarDelegate>

/**
 The current data source associated to the view controller.
 */
@property (nonatomic, readonly) MXKRoomMemberListDataSource *dataSource;

/**
 The delegate for the view controller.
 */
@property (nonatomic, weak) id<MXKRoomMemberListViewControllerDelegate> delegate;

/**
 Enable the search in room members list according to the member's display name (YES by default).
 Set NO this property to disable this option and hide the related bar button.
 */
@property (nonatomic) BOOL enableMemberSearch;

/**
 Enable the invitation of a new member (YES by default).
 Set NO this property to disable this option and hide the related bar button.
 */
@property (nonatomic) BOOL enableMemberInvitation;

/**
 Display the members list.

 @param listDataSource the data source providing the members list.
 */
- (void)displayList:(MXKRoomMemberListDataSource*)listDataSource;

@end
