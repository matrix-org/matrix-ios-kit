/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd

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
#import <MatrixSDK/MatrixSDK.h>

/**
 `MXKAppSettings` represents the application settings. Most of them are used to handle matrix session data.
 
 The shared object `standardAppSettings` provides the default application settings defined in `standardUserDefaults`.
 Any property change of this shared settings is reported into `standardUserDefaults`.
 
 Developper may define their own `MXKAppSettings` instances to handle specific setting values without impacting the shared object.
 */
@interface MXKAppSettings : NSObject

#pragma mark - Room display

/**
 Display all received events in room history (Only recognized events are displayed, presently `custom` events are ignored).
 
 This boolean value is defined in shared settings object with the key: `showAllEventsInRoomHistory`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL showAllEventsInRoomHistory;

/**
 The types of events allowed to be displayed in room history.
 Its value depends on `showAllEventsInRoomHistory`.
 */
@property (nonatomic, readonly) NSArray *eventsFilterForMessages;

/**
 All the event types which may be displayed in the room history.
 */
@property (nonatomic, readonly) NSArray *allEventTypesForMessages;

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

/**
 Scheme with which to open HTTP links. e.g. if this is set to "googlechrome", any http:// links displayed in a room will be rewritten to use the googlechrome:// scheme.
 Defaults to "http".
 */
@property (nonatomic) NSString *httpLinkScheme;

/**
 Scheme with which to open HTTPS links. e.g. if this is set to "googlechromes", any https:// links displayed in a room will be rewritten to use the googlechromes:// scheme.
 Defaults to "https".
 */
@property (nonatomic) NSString *httpsLinkScheme;


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
 Return YES if the user has been already asked for local contacts sync permission.

 This boolean value is defined in shared settings object with the key: `syncLocalContactsRequested`.
 Return NO if no value is defined.
 */
@property (nonatomic) BOOL syncLocalContactsPermissionRequested;

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

#pragma mark - Calls

/**
 Return YES if the user enable CallKit support.
 
 This boolean value is defined in shared settings object with the key: `enableCallKit`.
 Return YES if no value is defined.
 */
@property (nonatomic, getter=isCallKitEnabled) BOOL enableCallKit;

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
