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

#import "MXKAccountManager.h"

NSString *const kMXKAccountManagerDidAddAccountNotification = @"kMXKAccountManagerDidAddAccountNotification";
NSString *const kMXKAccountManagerDidRemoveAccountNotification = @"kMXKAccountManagerDidRemoveAccountNotification";

static MXKAccountManager *sharedAccountManager = nil;

@interface MXKAccountManager()
{
    /**
     The list of all accounts (enabled and disabled). Each value is a `MXKAccount` instance.
     */
    NSMutableArray *mxAccounts;
}

@end

@implementation MXKAccountManager

+ (MXKAccountManager *)sharedManager
{
    @synchronized(self)
    {
        if (sharedAccountManager == nil)
        {
            sharedAccountManager = [[super allocWithZone:NULL] init];
        }
    }
    return sharedAccountManager;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.storeClass = [MXFileStore class];
    }
    return self;
}

- (void)dealloc
{
    mxAccounts = nil;
}

#pragma mark -

- (void)loadAccounts
{
    NSData *accountData = [[NSUserDefaults standardUserDefaults] objectForKey:@"accounts"];
    if (accountData)
    {
        mxAccounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountData]];
    }
    else
    {
        mxAccounts = [NSMutableArray array];
    }
}

- (void)saveAccounts
{
    if (mxAccounts.count)
    {
        NSData *accountData = [NSKeyedArchiver archivedDataWithRootObject:mxAccounts];
        
        [[NSUserDefaults standardUserDefaults] setObject:accountData forKey:@"accounts"];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"accounts"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)addAccount:(MXKAccount *)account
{
    NSLog(@"[MXKAccountManager] login (%@)", account.mxCredentials.userId);
    
    if (!mxAccounts)
    {
         mxAccounts = [NSMutableArray array];
    }
    
    [mxAccounts addObject:account];
    [self saveAccounts];
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidAddAccountNotification object:account userInfo:nil];
}

- (void)removeAccount:(MXKAccount*)account
{
    NSLog(@"[MXKAccountManager] logout (%@)", account.mxCredentials.userId);
    
    // Close session and clear associated store.
    [account logout];
    
    [mxAccounts removeObject:account];
    [self saveAccounts];
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidRemoveAccountNotification object:account userInfo:nil];
}

- (void)logout
{
    // Remove APNS device token
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsAppendFlag"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Logout all existing accounts
    while (mxAccounts.lastObject)
    {
        [self removeAccount:mxAccounts.lastObject];
    }
}

- (MXKAccount *)accountForUserId:(NSString *)userId
{
    for (MXKAccount *account in mxAccounts)
    {
        if ([account.mxCredentials.userId isEqualToString:userId])
        {
            return account;
        }
    }
    return nil;
}

#pragma mark -

- (void)setStoreClass:(Class)storeClass
{
    // Sanity check
    NSAssert([storeClass conformsToProtocol:@protocol(MXStore)], @"MXKAccountManager only manages store class that conforms to MXStore protocol");
    
    _storeClass = storeClass;
}

- (NSArray *)accounts
{
    if (!mxAccounts)
    {
        [self loadAccounts];
    }
    
    return [mxAccounts copy];
}

- (NSArray *)activeAccounts
{
    if (!mxAccounts)
    {
        [self loadAccounts];
    }
    
    NSMutableArray *activeAccounts = [NSMutableArray arrayWithCapacity:mxAccounts.count];
    for (MXKAccount *account in mxAccounts)
    {
        if (!account.disabled)
        {
            [activeAccounts addObject:account];
        }
    }
    return activeAccounts;
}

- (NSData *)apnsDeviceToken
{
    NSData *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnsDeviceToken"];
    if (!token.length)
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsAppendFlag"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        token = nil;
    }
    return token;
}

- (void)setApnsDeviceToken:(NSData *)apnsDeviceToken
{
    NSData *oldToken = self.apnsDeviceToken;
    if (!apnsDeviceToken.length)
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsAppendFlag"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject:apnsDeviceToken forKey:@"apnsDeviceToken"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (!oldToken)
        {
            // Reset the append flag before resync APNS for active account
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsAppendFlag"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // turn on the Apns flag for all accounts, when the Apns registration succeeds for the first time
            for (MXKAccount *account in mxAccounts)
            {
                account.enablePushNotifications = YES;
            }
        }
        else if (![oldToken isEqualToData:apnsDeviceToken])
        {
            // Reset the append flag before resync APNS for active account
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsAppendFlag"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Resync APNS to on if we think APNS is on, but the token has changed.
            for (MXKAccount *account in mxAccounts)
            {
                if (account.pushNotificationServiceIsActive)
                {
                    account.enablePushNotifications = YES;
                }
            }
        }
    }
}

- (BOOL)apnsAppendFlag
{
    BOOL appendFlag = [[NSUserDefaults standardUserDefaults] boolForKey:@"apnsAppendFlag"];
    if (!appendFlag)
    {
        // Turn on 'append' flag to be able to add another pusher with the given pushkey and App ID to any others user IDs
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"apnsAppendFlag"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return appendFlag;
}

- (BOOL)isAPNSAvailable
{
    BOOL isRegisteredForRemoteNotifications = NO;
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)])
    {
        // iOS 8 and later
        isRegisteredForRemoteNotifications = [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
    }
    else
    {
        isRegisteredForRemoteNotifications = [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone;
    }
    
    return (isRegisteredForRemoteNotifications && self.apnsDeviceToken);
}

@end
