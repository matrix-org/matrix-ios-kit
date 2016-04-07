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

#import "MXKAccount.h"

/**
 Posted when the user logged in with a matrix account.
 The notification object is the new added account.
 */
extern NSString *const kMXKAccountManagerDidAddAccountNotification;

/**
 Posted when an existing account is logged out.
 The notification object is the removed account.
 */
extern NSString *const kMXKAccountManagerDidRemoveAccountNotification;


/**
 `MXKAccountManager` manages a pool of `MXKAccount` instances.
 */
@interface MXKAccountManager : NSObject

/**
 The class of store used to open matrix session for the accounts. This class must be conformed to MXStore protocol.
 By default this class is MXFileStore.
 */
@property (nonatomic) Class storeClass;

/**
 List of all available accounts (enabled and disabled).
 */
@property (nonatomic, readonly) NSArray* accounts;

/**
 List of active accounts (only enabled accounts)
 */
@property (nonatomic, readonly) NSArray* activeAccounts;

/**
 The device token used for Push notifications registration
 */
@property (nonatomic, copy) NSData *apnsDeviceToken;

/**
 In case of multiple accounts, this flag is used to create multiple pushers during Push notifications registration.
 */
@property (nonatomic, readonly) BOOL apnsAppendFlag;

/**
 The APNS status: YES when app is registered for remote notif, and devive token is known.
 */
@property (nonatomic) BOOL isAPNSAvailable;

/**
 Retrieve the MXKAccounts manager.
 
 @return the MXKAccounts manager.
 */
+ (MXKAccountManager*)sharedManager;

/**
 Check for each enabled account if a matrix session is already opened.
 Open a matrix session for each enabled account which doesn't have a session.
 The developper must set 'storeClass' before the first call of this method 
 if the default class is not suitable.
 */
- (void)prepareSessionForActiveAccounts;

/**
 Save a snapshot of the current accounts.
 */
- (void)saveAccounts;

/**
 Add an account and save the new account list. Optionally a matrix session may be opened for the provided account.
 
 @param account a matrix account.
 @param openSession YES to open a matrix session (this value is ignored if the account is disabled).
 */
- (void)addAccount:(MXKAccount *)account andOpenSession:(BOOL)openSession;

/**
 Remove the provided account and save the new account list. This method is used in case of logout.
 
 @param account a matrix account.
 */
- (void)removeAccount:(MXKAccount*)account;

/**
 Log out and remove all the existing accounts
 */
- (void)logout;

/**
 Retrieve the account for a user id.
 
 @param userId the user id.
 @return the user's account (nil if no account exist).
 */
- (MXKAccount*)accountForUserId:(NSString*)userId;

/**
 Retrieve an account that knows the room with the passed id or alias.
 
 Note: The method is not accurate as it returns the first account that matches.

 @param roomIdOrAlias the room id or alias.
 @return the user's account. Nil if no account matches.
 */
- (MXKAccount*)accountKnowingRoomWithRoomIdOrAlias:(NSString*)roomIdOrAlias;

@end
