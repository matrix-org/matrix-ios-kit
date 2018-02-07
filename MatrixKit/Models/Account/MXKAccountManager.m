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
#import "MXKAppSettings.h"

static NSString *const kMXKAccountsKey = @"accounts";

NSString *const kMXKAccountManagerDidAddAccountNotification = @"kMXKAccountManagerDidAddAccountNotification";
NSString *const kMXKAccountManagerDidRemoveAccountNotification = @"kMXKAccountManagerDidRemoveAccountNotification";

@interface MXKAccountManager()
{
    /**
     The list of all accounts (enabled and disabled). Each value is a `MXKAccount` instance.
     */
    NSMutableArray<MXKAccount *> *mxAccounts;
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
    NSDate *startDate = [NSDate date];
    
    NSLog(@"[MXKAccountManager] saveAccounts...");
    BOOL result = [NSKeyedArchiver archiveRootObject:mxAccounts toFile:[self accountFile]];
    NSLog(@"[MXKAccountManager] saveAccounts. Done (result: %@) in %.0fms", @(result), [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
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

- (void)removeAccount:(MXKAccount*)theAccount completion:(void (^)(void))completion;
{
    NSLog(@"[MXKAccountManager] logout (%@)", theAccount.mxCredentials.userId);
    
    // Close session and clear associated store.
    [theAccount logout:^{
        
        // Retrieve the corresponding account in the internal array
        MXKAccount* removedAccount = nil;
        
        for (MXKAccount *account in mxAccounts)
        {
            if ([account.mxCredentials.userId isEqualToString:theAccount.mxCredentials.userId])
            {
                removedAccount = account;
                break;
            }
        }
        
        if (removedAccount)
        {
            [mxAccounts removeObject:removedAccount];
            
            [self saveAccounts];
            
            // Post notification
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidRemoveAccountNotification object:removedAccount userInfo:nil];
        }
        
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
    
    NSUserDefaults *sharedUserDefaults = [MXKAppSettings standardAppSettings].sharedUserDefaults;
    
    // Remove APNS device token
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
    
    // Remove Push device token
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushDeviceToken"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
    
    // Be sure that no account survive in local storage
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMXKAccountsKey];
    [sharedUserDefaults removeObjectForKey:kMXKAccountsKey];
    [[NSFileManager defaultManager] removeItemAtPath:[self accountFile] error:nil];
    
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

- (MXKAccount *)accountKnowingUserWithUserId:(NSString *)userId
{
    MXKAccount *theAccount = nil;

    NSArray *activeAccounts = self.activeAccounts;

    for (MXKAccount *account in activeAccounts)
    {
        if ([account.mxSession userWithUserId:userId])
        {
            theAccount = account;
            break;
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

- (NSArray<MXKAccount *> *)accounts
{
    return [mxAccounts copy];
}

- (NSArray<MXKAccount *> *)activeAccounts
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

- (NSData *)pushDeviceToken
{
    NSData *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushDeviceToken"];
    if (!token.length)
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushDeviceToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        token = nil;
    }
    return token;
}

- (NSDictionary *)pushOptions
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"pushOptions"];
}

- (void)setPushDeviceToken:(NSData *)pushDeviceToken withPushOptions:(NSDictionary *)pushOptions
{
    NSData *oldToken = self.pushDeviceToken;
    if (!pushDeviceToken.length)
    {
        NSLog(@"[MXKAccountManager] reset Push device token");
        
        if (oldToken)
        {
            // turn off the Push flag for all accounts if any
            for (MXKAccount *account in mxAccounts)
            {
                account.enablePushKitNotifications = NO;
            }
        }
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushDeviceToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        NSArray *activeAccounts = self.activeAccounts;
        
        if (!oldToken)
        {
            NSLog(@"[MXKAccountManager] set Push device token");
            
            [[NSUserDefaults standardUserDefaults] setObject:pushDeviceToken forKey:@"pushDeviceToken"];
            if (pushOptions)
            {
                [[NSUserDefaults standardUserDefaults] setObject:pushOptions forKey:@"pushOptions"];
            }
            else
            {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // turn on the Push flag for all accounts
            for (MXKAccount *account in activeAccounts)
            {
                account.enablePushKitNotifications = YES;
            }
        }
        else if (![oldToken isEqualToData:pushDeviceToken])
        {
            NSLog(@"[MXKAccountManager] update Push device token");
            
            // Delete the pushers related to the old token
            for (MXKAccount *account in activeAccounts)
            {
                [account deletePushKitPusher];
            }
            
            // Update the token
            [[NSUserDefaults standardUserDefaults] setObject:pushDeviceToken forKey:@"pushDeviceToken"];
            if (pushOptions)
            {
                [[NSUserDefaults standardUserDefaults] setObject:pushOptions forKey:@"pushOptions"];
            }
            else
            {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Refresh pushers with the new token.
            for (MXKAccount *account in activeAccounts)
            {
                if (account.isPushKitNotificationActive)
                {
                    NSLog(@"[MXKAccountManager] Resync Push for %@ account", account.mxCredentials.userId);
                    account.enablePushKitNotifications = YES;
                }
            }
        }
    }
}

- (BOOL)isPushAvailable
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
    
    return (isRemoteNotificationsAllowed && self.pushDeviceToken);
}

#pragma mark -

// Return the path of the file containing stored MXAccounts array
- (NSString*)accountFile
{
    NSString *matrixKitCacheFolder = [MXKAppSettings cacheFolder];
    return [matrixKitCacheFolder stringByAppendingPathComponent:kMXKAccountsKey];
}

- (void)loadAccounts
{
    NSLog(@"[MXKAccountManager] loadAccounts");

    NSString *accountFile = [self accountFile];
    if ([[NSFileManager defaultManager] fileExistsAtPath:accountFile])
    {
        NSDate *startDate = [NSDate date];
        mxAccounts = [NSKeyedUnarchiver unarchiveObjectWithFile:accountFile];
        NSLog(@"[MXKAccountManager] loadAccounts. %tu accounts loaded in %.0fms", mxAccounts.count, [[NSDate date] timeIntervalSinceDate:startDate] * 1000);
    }
    else
    {
        // Migration of accountData from sharedUserDefaults to a file
        NSUserDefaults *sharedDefaults = [MXKAppSettings standardAppSettings].sharedUserDefaults;

        NSData *accountData = [sharedDefaults objectForKey:kMXKAccountsKey];
        if (!accountData)
        {
            // Migration of accountData from [NSUserDefaults standardUserDefaults], the first location storage
            accountData = [[NSUserDefaults standardUserDefaults] objectForKey:kMXKAccountsKey];
        }

        if (accountData)
        {
            mxAccounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountData]];
            [self saveAccounts];

            NSLog(@"[MXKAccountManager] loadAccounts: performed data migration");

            // Now that data has been migrated, erase old location of accountData
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMXKAccountsKey];
            [[NSUserDefaults standardUserDefaults] synchronize];

            [sharedDefaults removeObjectForKey:kMXKAccountsKey];
            [sharedDefaults synchronize];
        }
    }

    if (!mxAccounts)
    {
        NSLog(@"[MXKAccountManager] loadAccounts. No accounts");
        mxAccounts = [NSMutableArray array];
    }
}

- (void)forceReloadAccounts
{
    NSLog(@"[MXKAccountManager] Force reload existing accounts from local storage");
    [self loadAccounts];
}

@end
