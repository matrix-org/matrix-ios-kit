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

#import "MXKAccountManager.h"

NSString *const kMXKAccountManagerDidAddAccountNotification = @"kMXKAccountManagerDidAddAccountNotification";
NSString *const kMXKAccountManagerDidRemoveAccountNotification = @"kMXKAccountManagerDidRemoveAccountNotification";

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
    static MXKAccountManager *sharedAccountManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAccountManager = [[super allocWithZone:NULL] init];
    });
    
    return sharedAccountManager;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _storeClass = [MXFileStore class];
        
        // Load existing accounts from local storage
        [self loadAccounts];
    }
    return self;
}

- (void)dealloc
{
    mxAccounts = nil;
}

#pragma mark -

- (void)prepareSessionForActiveAccounts
{
    for (MXKAccount *account in mxAccounts)
    {
        // Check whether the account is enabled. Open a new matrix session if none.
        if (!account.isDisabled && !account.mxSession)
        {
            NSLog(@"[MXKAccountManager] openSession for %@ account", account.mxCredentials.userId);
            
            id<MXStore> store = [[_storeClass alloc] init];
            [account openSessionWithStore:store];
        }
    }
}

- (void)saveAccounts
{
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.matrix.riot"];
    if (mxAccounts.count)
    {
        NSData *accountData = [NSKeyedArchiver archivedDataWithRootObject:mxAccounts];
        
        [userDefaults setObject:accountData forKey:@"accounts"];
    }
    else
    {
        [userDefaults removeObjectForKey:@"accounts"];
    }
    [userDefaults synchronize];
}

- (void)addAccount:(MXKAccount *)account andOpenSession:(BOOL)openSession
{
    NSLog(@"[MXKAccountManager] login (%@)", account.mxCredentials.userId);
    
    [mxAccounts addObject:account];
    [self saveAccounts];
    
    // Check conditions to open a matrix session
    if (openSession && !account.disabled)
    {
        // Open a new matrix session by default
        NSLog(@"[MXKAccountManager] openSession for %@ account", account.mxCredentials.userId);
        
        id<MXStore> store = [[_storeClass alloc] init];
        [account openSessionWithStore:store];
    }
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidAddAccountNotification object:account userInfo:nil];
}

- (void)removeAccount:(MXKAccount*)account completion:(void (^)())completion;
{
    NSLog(@"[MXKAccountManager] logout (%@)", account.mxCredentials.userId);
    
    // Close session and clear associated store.
    [account logout:^{
        
        [mxAccounts removeObject:account];
        [self saveAccounts];
        
        // Post notification
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidRemoveAccountNotification object:account userInfo:nil];
        
        if (completion)
        {
            completion();
        }
        
    }];
}

- (void)logout
{
    // Logout one by one the existing accounts
    if (mxAccounts.count)
    {
        [self removeAccount:mxAccounts.lastObject completion:^{
            
            // loop: logout the next existing account (if any)
            [self logout];
            
        }];
        
        return;
    }
    
    NSUserDefaults *sharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.matrix.riot"];
    
    // Remove APNS device token
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
    
    // Be sure that no account survive in local storage
    [sharedUserDefaults removeObjectForKey:@"accounts"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    [sharedUserDefaults synchronize];
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

- (MXKAccount *)accountKnowingRoomWithRoomIdOrAlias:(NSString *)roomIdOrAlias
{
    MXKAccount *theAccount = nil;

    NSArray *activeAccounts = self.activeAccounts;

    for (MXKAccount *account in activeAccounts)
    {
        if ([roomIdOrAlias hasPrefix:@"#"])
        {
            if ([account.mxSession roomWithAlias:roomIdOrAlias])
            {
                theAccount = account;
                break;
            }
        }
        else
        {
            if ([account.mxSession roomWithRoomId:roomIdOrAlias])
            {
                theAccount = account;
                break;
            }
        }
    }
    return theAccount;
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
    return [mxAccounts copy];
}

- (NSArray *)activeAccounts
{
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
        NSLog(@"[MXKAccountManager] reset APNS device token");
        
        if (oldToken)
        {
            // turn off the Apns flag for all accounts if any
            for (MXKAccount *account in mxAccounts)
            {
                account.enablePushNotifications = NO;
            }
        }
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        NSArray *activeAccounts = self.activeAccounts;
        
        if (!oldToken)
        {
            NSLog(@"[MXKAccountManager] set APNS device token");
            
            [[NSUserDefaults standardUserDefaults] setObject:apnsDeviceToken forKey:@"apnsDeviceToken"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // turn on the Apns flag for all accounts, when the Apns registration succeeds for the first time
            for (MXKAccount *account in activeAccounts)
            {
                account.enablePushNotifications = YES;
            }
        }
        else if (![oldToken isEqualToData:apnsDeviceToken])
        {
            NSLog(@"[MXKAccountManager] update APNS device token");
            
            // Delete the pushers related to the old token
            for (MXKAccount *account in activeAccounts)
            {
                [account deletePusher];
            }
            
            // Update the token
            [[NSUserDefaults standardUserDefaults] setObject:apnsDeviceToken forKey:@"apnsDeviceToken"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Refresh pushers with the new token.
            for (MXKAccount *account in activeAccounts)
            {
                if (account.pushNotificationServiceIsActive)
                {
                    NSLog(@"[MXKAccountManager] Resync APNS for %@ account", account.mxCredentials.userId);
                    account.enablePushNotifications = YES;
                }
            }
        }
    }
}

- (BOOL)isAPNSAvailable
{
    // [UIApplication isRegisteredForRemoteNotifications] tells whether your app can receive
    // remote notifications or not. However receiving remote notifications does not mean it
    // will also display them to the user.
    // To check whether the user allowed or denied remote notification or in fact changed
    // the notifications permissions later in iOS setting, we have to call
    // [UIApplication currentUserNotificationSettings].
    
    BOOL isRemoteNotificationsAllowed = NO;
    
    UIApplication *sharedApplication = [UIApplication performSelector:@selector(sharedApplication)];
    if (sharedApplication)
    {
        UIUserNotificationSettings *settings = [sharedApplication currentUserNotificationSettings];
        isRemoteNotificationsAllowed = (settings.types != UIUserNotificationTypeNone);
        
        NSLog(@"[MXKAccountManager] the user %@ remote notification", (isRemoteNotificationsAllowed ? @"allowed" : @"denied"));
    }
    
    return (isRemoteNotificationsAllowed && self.apnsDeviceToken);
}

#pragma mark -

- (void)loadAccounts
{
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.org.matrix.riot"];
    
    NSData *oldAccountData = [[NSUserDefaults standardUserDefaults] objectForKey:@"accounts"];
    if (oldAccountData) {
        [sharedDefaults setObject:oldAccountData forKey:@"accounts"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"accounts"];
    }
    
    NSData *accountData = [sharedDefaults objectForKey:@"accounts"];
    //TEST
    
    if (accountData)
    {
        mxAccounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:oldAccountData]];
    }
    else
    {
        mxAccounts = [NSMutableArray array];
    }
}

@end
