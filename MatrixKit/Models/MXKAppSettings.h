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

@interface MXKAppSettings : NSObject

/**
 Enable In-App notifications based on Remote notifications rules.
 
 This boolean value is stored in shared defaults object with `enableInAppNotifications` key.
 Return NO if no default value is defined.
 */
@property (nonatomic) BOOL enableInAppNotifications;

/**
 Display all received events in room history (Only recognized events are displayed, presently `custom` events are ignored).
 
 This boolean value is stored in shared defaults object with `showAllEventsInRoomHistory` key.
 Return NO if no default value is defined.
 */
@property (nonatomic) BOOL showAllEventsInRoomHistory;

/**
 Display redacted events in room history.
 
 This boolean value is stored in shared defaults object with `showRedactionsInRoomHistory` key.
 Return NO if no default value is defined.
 */
@property (nonatomic) BOOL showRedactionsInRoomHistory;

/**
 Display unsupported/unexpected events in room history.
 
 This boolean value is stored in shared defaults object with `showUnsupportedEventsInRoomHistory` key.
 Return NO if no default value is defined.
 */
@property (nonatomic) BOOL showUnsupportedEventsInRoomHistory;

/**
 Sort room members by considering their presence.
 Set NO to sort members in alphabetic order.
 
 This boolean value is stored in shared defaults object with `sortRoomMembersUsingLastSeenTime` key.
 Return YES if no default value is defined.
 */
@property (nonatomic) BOOL sortRoomMembersUsingLastSeenTime;

/**
 Show left members in room member list.
 
 This boolean value is stored in shared defaults object with `showLeftMembersInRoomMemberList` key.
 Return NO if no default value is defined.
 */
@property (nonatomic) BOOL showLeftMembersInRoomMemberList;

/**
 Return YES if the user allows the local contacts sync.
 
 This boolean value is stored in shared defaults object with `syncLocalContacts` key.
 Return NO if no default value is defined.
 */
@property (nonatomic) BOOL syncLocalContacts;

/**
 The current selected country code for the phonebook.
 
 This value is stored in shared defaults object with `phonebookCountryCode` key.
 Return the SIM card information (if any) if no default value is defined.
 */
@property (nonatomic) NSString* phonebookCountryCode;

/**
 Return the current application settings.
 */
+ (MXKAppSettings *)sharedSettings;

/**
 Restore the default values
 */
- (void)reset;

@end
