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
 The notification object is the matrix user id of the new added account.
 */
extern NSString *const kMXKAccountManagerDidAddAccountNotification;

/**
 Posted when an existing account is logged out.
 The notification object is the matrix user id of the removed account.
 */
extern NSString *const kMXKAccountManagerDidRemoveAccountNotification;


/**
 `MXKAccountManager` manages a pool of `MXKAccount` instances.
 */
@interface MXKAccountManager : NSObject

/**
 List of available accounts
 */
@property (nonatomic, readonly) NSArray* accounts;

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
 Retrieve the account for a user id.
 
 @param userId the user id.
 @return the user's account (nil if no account exist).
 */
- (MXKAccount*)accountForUserId:(NSString*)userId;

/**
 Add an account and save the new account list.
 
 @param account a matrix account.
 */
- (void)addAccount:(MXKAccount*)account;

/**
 Remove the provided account. This method is used in case of logout.
 
 @param account a matrix account.
 */
- (void)removeAccount:(MXKAccount*)account;

/**
 Save a snapshot of the current accounts
 */
- (void)saveAccounts;

/**
 Log out all the existing accounts
 */
- (void)logout;

@end
