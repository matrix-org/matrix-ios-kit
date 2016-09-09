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

#import <Foundation/Foundation.h>

#import <MatrixSDK/MatrixSDK.h>

#import "MXKSectionedContacts.h"
#import "MXKContact.h"

/**
 Posted when the matrix contact list is loaded or updated.
 The notification object is:
 - a contact Id when a matrix contact has been added/updated/removed.
 or
 - nil when all matrix contacts are concerned.
 */
extern NSString *const kMXKContactManagerDidUpdateMatrixContactsNotification;

/**
 Posted when the local contact list is loaded and updated.
 The notification object is:
 - a contact Id when a local contact has been added/updated/removed.
 or
 - nil when all local contacts are concerned.
 */
extern NSString *const kMXKContactManagerDidUpdateLocalContactsNotification;

/**
 Posted when local contact matrix ids is updated.
 The notification object is:
 - a contact Id when a local contact has been added/updated/removed.
 or
 - nil when all local contacts are concerned.
 */
extern NSString *const kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification;

/**
 Posted when the presence of a matrix user linked at least to one contact has changed.
 The notification object is the matrix Id. The `userInfo` dictionary contains an `MXPresenceString` object under the `kMXKContactManagerMatrixPresenceKey` key, representing the matrix user presence.
 */
extern NSString *const kMXKContactManagerMatrixUserPresenceChangeNotification;
extern NSString *const kMXKContactManagerMatrixPresenceKey;

/**
 Posted when all phonenumbers of local contacts have been internationalized.
 The notification object is nil.
 */
extern NSString *const kMXKContactManagerDidInternationalizeNotification;

/**
 Define the contact creation for the room members
 */
typedef NS_ENUM(NSInteger, MXKContactManagerMXRoomSource) {
    MXKContactManagerMXRoomSourceNone        = 0,   // the MXMember does not create any new contact.
    MXKContactManagerMXRoomSourceOneToOne    = 1,   // the 1:1 room members have their own contact even if they are not defined in the device contacts book
    MXKContactManagerMXRoomSourceAll         = 2,   // all the room members have their own contact even if they are not defined in the device contacts book
};

/**
 This manager handles 2 kinds of contact list:
 - The local contacts retrieved from the device phonebook.
 - The matrix contacts retrieved from the matrix one-to-one rooms.
 
 Note: The local contacts handling depends on the 'syncLocalContacts' and 'phonebookCountryCode' properties
 of the shared application settings object '[MXKAppSettings standardAppSettings]'.
 */
@interface MXKContactManager : NSObject

/**
 The shared instance of contact manager.
 */
+ (MXKContactManager*)sharedManager;

/**
 The identity server URL used to link matrix ids to the local contacts according to their 3PIDs (email, phone number...).
 This property is nil by default.
 
 If this property is not set whereas some matrix sessions are added, the identity server of the first available matrix session is used.
 */
@property (nonatomic) NSString *identityServer;

/**
 Define if the room member must have their dedicated contact even if they are not define in the device contacts book.
 The default value is MXKContactManagerMXRoomSourceOneToOne;
 */
@property (nonatomic) MXKContactManagerMXRoomSource contactManagerMXRoomSource;

/**
 Associated matrix sessions (empty by default).
 */
@property (nonatomic, readonly) NSArray *mxSessions;

/**
 The current list of the contacts extracted from matrix data. Depends on 'contactManagerMXRoomSource'.
 */
@property (nonatomic, readonly) NSArray *matrixContacts;

/**
 The current list of the local contacts (nil by default until the contacts are loaded).
 */
@property (nonatomic, readonly) NSArray *localContacts;

/**
 The current list of contacts used to handle the email addresses retrieved from the local address book.
 Each item of this array is a MXKContact instance with an email address as display name.
 */
@property (nonatomic, readonly) NSArray *localEmailContacts;

/**
 The current list of the contacts for whom a 1:1 room exists.
 */
@property (nonatomic, readonly) NSArray *oneToOneMatrixContacts;

/**
 List the contacts who share at least a private room with the current user of the provided matrix session.
 
 @param mxSession the concerned matrix session.
 */
- (NSArray *)privateMatrixContacts:(MXSession*)mxSession;

/**
 No by default. Set YES to update matrix ids for all the local contacts in only one request
 when device contacts are loaded and an identity server is available.
 */
@property (nonatomic) BOOL enableFullMatrixIdSyncOnLocalContactsDidLoad;

/**
 Add/remove matrix session. The matrix contact list is automatically updated (see kMXKContactManagerDidUpdateMatrixContactsNotification event).
 */
- (void)addMatrixSession:(MXSession*)mxSession;
- (void)removeMatrixSession:(MXSession*)mxSession;

/**
 Load and refresh the local contacts. Observe kMXKContactManagerDidUpdateLocalContactsNotification to know when local contacts are available.
 */
- (void)loadLocalContacts;

/**
 Delete contacts info
 */
- (void)reset;

/**
 Get contact by its identifier.
 
 @param contactID the contact identifier.
 @return the contact defined with the provided id.
 */
- (MXKContact*)contactWithContactID:(NSString*)contactID;

/**
 Refresh matrix IDs for a specific local contact. See kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification
 posted when update is done.
 
 @param contact the local contact to refresh.
 */
- (void)updateMatrixIDsForLocalContact:(MXKContact*)contact;

/**
 Refresh matrix IDs for all local contacts. See kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification
 posted when update for all local contacts is done.
 */
- (void)updateMatrixIDsForAllLocalContacts;

/**
 Sort a contacts array in sectioned arrays to be displayable in a UITableview
 */
- (MXKSectionedContacts*)getSectionedContacts:(NSArray*)contactList;

/**
 Refresh the international phonenumber of the local contacts (See kMXKContactManagerDidInternationalizeNotification).
 
 @param countryCode
 */
- (void)internationalizePhoneNumbers:(NSString*)countryCode;

/**
 Request user permission for syncing local contacts.

 @param viewController the view controller to attach the dialog to the user.
 @param handler the block called with the result of requesting access
 */
+ (void)requestUserConfirmationForLocalContactsSyncInViewController:(UIViewController*)viewController
                                             completionHandler:(void (^)(BOOL granted))handler;

@end
