/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 Copyright 2019 The Matrix.org Foundation C.I.C

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

#import "MXKTools.h"

static NSString *const kMXKAccountsKeyOld = @"accounts";
static NSString *const kMXKAccountsKey = @"accountsV2";

NSString *const kMXKAccountManagerDidAddAccountNotification = @"kMXKAccountManagerDidAddAccountNotification";
NSString *const kMXKAccountManagerDidRemoveAccountNotification = @"kMXKAccountManagerDidRemoveAccountNotification";
NSString *const kMXKAccountManagerDidSoftlogoutAccountNotification = @"kMXKAccountManagerDidSoftlogoutAccountNotification";
NSString *const MXKAccountManagerDataType = @"org.matrix.kit.MXKAccountManagerDataType";

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
        
        // Migrate old account file to new format
        [self migrateAccounts];
        
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
        if (!account.isDisabled && !account.isSoftLogout && !account.mxSession)
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
    
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];

    [encoder encodeObject:mxAccounts forKey:@"mxAccounts"];

    [encoder finishEncoding];

    [data setData:[self encryptData:data]];

    BOOL result = [data writeToFile:[self accountFile] atomically:YES];

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

- (void)removeAccount:(MXKAccount*)theAccount completion:(void (^)(void))completion
{
    [self removeAccount:theAccount sendLogoutRequest:YES completion:completion];
}

- (void)removeAccount:(MXKAccount*)theAccount
    sendLogoutRequest:(BOOL)sendLogoutRequest
           completion:(void (^)(void))completion
{
    NSLog(@"[MXKAccountManager] logout (%@), send logout request to homeserver: %d", theAccount.mxCredentials.userId, sendLogoutRequest);
    
    // Close session and clear associated store.
    [theAccount logoutSendingServerRequest:sendLogoutRequest completion:^{
        
        // Retrieve the corresponding account in the internal array
        MXKAccount* removedAccount = nil;
        
        for (MXKAccount *account in self->mxAccounts)
        {
            if ([account.mxCredentials.userId isEqualToString:theAccount.mxCredentials.userId])
            {
                removedAccount = account;
                break;
            }
        }
        
        if (removedAccount)
        {
            [self->mxAccounts removeObject:removedAccount];
            
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


- (void)logoutWithCompletion:(void (^)(void))completion
{
    // Logout one by one the existing accounts
    if (mxAccounts.count)
    {
        [self removeAccount:mxAccounts.lastObject completion:^{
            
            // loop: logout the next existing account (if any)
            [self logoutWithCompletion:completion];
            
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

    if (completion)
    {
        completion();
    }
}

- (void)softLogout:(MXKAccount*)account
{
    [account softLogout];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidSoftlogoutAccountNotification
                                                        object:account
                                                      userInfo:nil];
}

- (void)hydrateAccount:(MXKAccount*)account withCredentials:(MXCredentials*)credentials
{
    NSLog(@"[MXKAccountManager] hydrateAccount: %@", account.mxCredentials.userId);

    if ([account.mxCredentials.userId isEqualToString:credentials.userId])
    {
        // Restart the account
        [account hydrateWithCredentials:credentials];

        NSLog(@"[MXKAccountManager] hydrateAccount: Open session");

        id<MXStore> store = [[_storeClass alloc] init];
        [account openSessionWithStore:store];

        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidAddAccountNotification
                                                            object:account
                                                          userInfo:nil];
    }
    else
    {
        NSLog(@"[MXKAccountManager] hydrateAccount: Credentials given for another account: %@", credentials.userId);

        // Logout the old account and create a new one with the new credentials
        [self removeAccount:account sendLogoutRequest:YES completion:nil];

        MXKAccount *newAccount = [[MXKAccount alloc] initWithCredentials:credentials];
        [self addAccount:newAccount andOpenSession:YES];
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
        if (!account.disabled && !account.isSoftLogout)
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
        token = nil;
    }

    NSLog(@"[MXKAccountManager][Push] apnsDeviceToken: %@", [MXKTools logForPushToken:token]);
    return token;
}

- (void)setApnsDeviceToken:(NSData *)apnsDeviceToken
{
    NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: %@", [MXKTools logForPushToken:apnsDeviceToken]);

    NSData *oldToken = self.apnsDeviceToken;
    if (!apnsDeviceToken.length)
    {
        NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: reset APNS device token");
        
        if (oldToken)
        {
            // turn off the Apns flag for all accounts if any
            for (MXKAccount *account in mxAccounts)
            {
                [account enablePushNotifications:NO success:nil failure:nil];
            }
        }
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apnsDeviceToken"];
    }
    else
    {
        NSArray *activeAccounts = self.activeAccounts;
        
        if (!oldToken)
        {
            NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: set APNS device token");
            
            [[NSUserDefaults standardUserDefaults] setObject:apnsDeviceToken forKey:@"apnsDeviceToken"];

            // turn on the Apns flag for all accounts, when the Apns registration succeeds for the first time
            for (MXKAccount *account in activeAccounts)
            {
                [account enablePushNotifications:YES success:nil failure:nil];
            }
        }
        else if (![oldToken isEqualToData:apnsDeviceToken])
        {
            NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: update APNS device token");

            NSMutableArray<MXKAccount*> *accountsWithAPNSPusher = [NSMutableArray new];

            // Delete the pushers related to the old token
            for (MXKAccount *account in activeAccounts)
            {
                if (account.hasPusherForPushNotifications)
                {
                    [accountsWithAPNSPusher addObject:account];
                }

                [account enablePushNotifications:NO success:nil failure:nil];
            }
            
            // Update the token
            [[NSUserDefaults standardUserDefaults] setObject:apnsDeviceToken forKey:@"apnsDeviceToken"];

            // Refresh pushers with the new token.
            for (MXKAccount *account in activeAccounts)
            {
                if ([accountsWithAPNSPusher containsObject:account])
                {
                    NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: Resync APNS for %@ account", account.mxCredentials.userId);
                    [account enablePushNotifications:YES success:nil failure:nil];
                }
                else
                {
                    NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: hasPusherForPushNotifications = NO for %@ account. Do not enable Push", account.mxCredentials.userId);
                }
            }
        }
        else
        {
            NSLog(@"[MXKAccountManager][Push] setApnsDeviceToken: Same token. Nothing to do.");
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
        
        NSLog(@"[MXKAccountManager][Push] isAPNSAvailable: The user %@ remote notification", (isRemoteNotificationsAllowed ? @"allowed" : @"denied"));
    }

    BOOL isAPNSAvailable = (isRemoteNotificationsAllowed && self.apnsDeviceToken);

    NSLog(@"[MXKAccountManager][Push] isAPNSAvailable: %@", @(isAPNSAvailable));

    return isAPNSAvailable;
}

- (NSData *)pushDeviceToken
{
    NSData *token = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushDeviceToken"];
    if (!token.length)
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushDeviceToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
        token = nil;
    }

    NSLog(@"[MXKAccountManager][Push] pushDeviceToken: %@", [MXKTools logForPushToken:token]);
    return token;
}

- (NSDictionary *)pushOptions
{
    NSDictionary *pushOptions = [[NSUserDefaults standardUserDefaults] objectForKey:@"pushOptions"];

    NSLog(@"[MXKAccountManager][Push] pushOptions: %@", pushOptions);
    return pushOptions;
}

- (void)setPushDeviceToken:(NSData *)pushDeviceToken withPushOptions:(NSDictionary *)pushOptions
{
    NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: %@ withPushOptions: %@", [MXKTools logForPushToken:pushDeviceToken], pushOptions);

    NSData *oldToken = self.pushDeviceToken;
    if (!pushDeviceToken.length)
    {
        NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: Reset Push device token");
        
        if (oldToken)
        {
            // turn off the Push flag for all accounts if any
            for (MXKAccount *account in mxAccounts)
            {
                [account enablePushKitNotifications:NO success:^{
                    //  make sure pusher really removed before losing token.
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushDeviceToken"];
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
                } failure:nil];
            }
        }
    }
    else
    {
        NSArray *activeAccounts = self.activeAccounts;
        
        if (!oldToken)
        {
            NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: Set Push device token");
            
            [[NSUserDefaults standardUserDefaults] setObject:pushDeviceToken forKey:@"pushDeviceToken"];
            if (pushOptions)
            {
                [[NSUserDefaults standardUserDefaults] setObject:pushOptions forKey:@"pushOptions"];
            }
            else
            {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pushOptions"];
            }

            // turn on the Push flag for all accounts
            for (MXKAccount *account in activeAccounts)
            {
                [account enablePushKitNotifications:YES success:nil failure:nil];
            }
        }
        else if (![oldToken isEqualToData:pushDeviceToken])
        {
            NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: Update Push device token");

            NSMutableArray<MXKAccount*> *accountsWithPushKitPusher = [NSMutableArray new];

            // Delete the pushers related to the old token
            for (MXKAccount *account in activeAccounts)
            {
                if (account.hasPusherForPushKitNotifications)
                {
                    [accountsWithPushKitPusher addObject:account];
                }

                [account enablePushKitNotifications:NO success:nil failure:nil];
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

            // Refresh pushers with the new token.
            for (MXKAccount *account in activeAccounts)
            {
                if ([accountsWithPushKitPusher containsObject:account])
                {
                    NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: Resync Push for %@ account", account.mxCredentials.userId);
                    [account enablePushKitNotifications:YES success:nil failure:nil];
                }
                else
                {
                    NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: hasPusherForPushKitNotifications = NO for %@ account. Do not enable Push", account.mxCredentials.userId);
                }
            }
        }
        else
        {
            NSLog(@"[MXKAccountManager][Push] setPushDeviceToken: Same token. Nothing to do.");
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
        
        NSLog(@"[MXKAccountManager][Push] isPushAvailable: The user %@ remote notification", (isRemoteNotificationsAllowed ? @"allowed" : @"denied"));
    }

    BOOL isPushAvailable = (isRemoteNotificationsAllowed && self.pushDeviceToken);

    NSLog(@"[MXKAccountManager][Push] isPushAvailable: %@", @(isPushAvailable));
    return isPushAvailable;
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
        
        NSError *error = nil;
        NSData* filecontent = [NSData dataWithContentsOfFile:accountFile options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:&error];
        
        if (!error)
        {
            // Decrypt data if encryption method is provided
            NSData *unciphered = [self decryptData:filecontent];
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:unciphered];
            mxAccounts = [decoder decodeObjectForKey:@"mxAccounts"];
            
            if (!mxAccounts && [[MXKeyProvider sharedInstance] isEncryptionAvailableForDataOfType:MXKAccountManagerDataType])
            {
                // This happens if the V2 file has not been encrypted -> read file content then save encrypted accounts
                NSLog(@"[MXKAccountManager] loadAccounts. Failed to read decrypted data: reading file data without encryption.");
                decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
                mxAccounts = [decoder decodeObjectForKey:@"mxAccounts"];
                
                if (mxAccounts)
                {
                    NSLog(@"[MXKAccountManager] loadAccounts. saving encrypted accounts");
                    [self saveAccounts];
                }
            }
        }

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

            [sharedDefaults removeObjectForKey:kMXKAccountsKey];
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

- (NSData*)encryptData:(NSData*)data
{
    // Exceptions are not caught as the key is always needed if the KeyProviderDelegate
    // is provided.
    MXKeyData *keyData = [[MXKeyProvider sharedInstance] requestKeyForDataOfType:MXKAccountManagerDataType isMandatory:YES expectedKeyType:kAes];
    if (keyData && [keyData isKindOfClass:[MXAesKeyData class]])
    {
        MXAesKeyData *aesKey = (MXAesKeyData *) keyData;
        NSData *cipher = [MXAes encrypt:data aesKey:aesKey.key iv:aesKey.iv error:nil];
        return cipher;
    }

    NSLog(@"[MXKAccountManager] encryptData: no key method provided for encryption.");
    return data;
}

- (NSData*)decryptData:(NSData*)data
{
    // Exceptions are not cached as the key is always needed if the KeyProviderDelegate
    // is provided.
    MXKeyData *keyData = [[MXKeyProvider sharedInstance] requestKeyForDataOfType:MXKAccountManagerDataType isMandatory:YES expectedKeyType:kAes];
    if (keyData && [keyData isKindOfClass:[MXAesKeyData class]])
    {
        MXAesKeyData *aesKey = (MXAesKeyData *) keyData;
        NSData *decrypt = [MXAes decrypt:data aesKey:aesKey.key iv:aesKey.iv error:nil];
        return decrypt;
    }

    NSLog(@"[MXKAccountManager] decryptData: no key method provided for decryption.");
    return data;
}

- (void)migrateAccounts
{
    NSString *pathOld = [[MXKAppSettings cacheFolder] stringByAppendingPathComponent:kMXKAccountsKeyOld];
    NSString *pathNew = [[MXKAppSettings cacheFolder] stringByAppendingPathComponent:kMXKAccountsKey];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:pathOld])
    {
        if (![fileManager fileExistsAtPath:pathNew])
        {
            NSLog(@"[MXKAccountManager] migrateAccounts: reading account");
            mxAccounts = [NSKeyedUnarchiver unarchiveObjectWithFile:pathOld];
            NSLog(@"[MXKAccountManager] migrateAccounts: writing to accountV2");
            [self saveAccounts];
        }
        
        NSLog(@"[MXKAccountManager] migrateAccounts: removing account");
        [fileManager removeItemAtPath:pathOld error:nil];
    }
}

@end
