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

/**
 `MXKAppSettings` represents the application settings. Most of them are used to handle matrix session data.
 
 The shared object `standardAppSettings` provides the default application settings defined in `standardUserDefaults`.
 Any property change of this shared settings is reported into `standardUserDefaults`.
 
 Developper may define their own `MXKAppSettings` instances to handle specific setting values without impacting the shared object.
 */
@interface MXKAppSettings : NSObject


#pragma mark - Notifications

/**
 Enable In-App notifications based on Remote notifications rules.
 
 This boolean value is defined in shared settings object with the key: `enableInAppNotifications`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL enableInAppNotifications;


#pragma mark - Room display

/**
 Display all received events in room history (Only recognized events are displayed, presently `custom` events are ignored).
 
 This boolean value is defined in shared settings object with the key: `showAllEventsInRoomHistory`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL showAllEventsInRoomHistory;

/**
 Display redacted events in room history.
 
 This boolean value is defined in shared settings object with the key: `showRedactionsInRoomHistory`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL showRedactionsInRoomHistory;

/**
 Display unsupported/unexpected events in room history.
 
 This boolean value is defined in shared settings object with the key: `showUnsupportedEventsInRoomHistory`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL showUnsupportedEventsInRoomHistory;


#pragma mark - Room members

/**
 Sort room members by considering their presence.
 Set NO to sort members in alphabetic order.
 
 This boolean value is defined in shared settings object with the key: `sortRoomMembersUsingLastSeenTime`.
 Return YES if no value is defined.
 */
@property (nonatomic) BOOL sortRoomMembersUsingLastSeenTime;

/**
 Show left members in room member list.
 
 This boolean value is defined in shared settings object with the key: `showLeftMembersInRoomMemberList`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL showLeftMembersInRoomMemberList;


#pragma mark - Contacts

/**
 Return YES if the user allows the local contacts sync.
 
 This boolean value is defined in shared settings object with the key: `syncLocalContacts`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL syncLocalContacts;

/**
 The current selected country code for the phonebook.
 
 This value is defined in shared settings object with the key: `phonebookCountryCode`.
 Return the SIM card information (if any) if no default value is defined.
 */
@property (nonatomic) NSString* phonebookCountryCode;


#pragma mark - Matrix users

/**
 Color associated to online matrix users.
 
 This color value is defined in shared settings object with the key: `presenceColorForOnlineUser`.
 The default color is `[UIColor greenColor]`.
 */
@property (nonatomic) UIColor *presenceColorForOnlineUser;

/**
 Color associated to unavailable matrix users.
 
 This color value is defined in shared settings object with the key: `presenceColorForUnavailableUser`.
 The default color is `[UIColor yellowColor]`.
 */
@property (nonatomic) UIColor *presenceColorForUnavailableUser;

/**
 Color associated to offline matrix users.
 
 This color value is defined in shared settings object with the key: `presenceColorForOfflineUser`.
 The default color is `[UIColor redColor]`.
 */
@property (nonatomic) UIColor *presenceColorForOfflineUser;


#pragma mark - Class methods

/**
 Return the shared application settings object. These settings are retrieved/stored in the shared defaults object (`[NSUserDefaults standardUserDefaults]`).
 */
+ (MXKAppSettings *)standardAppSettings;

/**
 Restore the default values.
 */
- (void)reset;

@end
