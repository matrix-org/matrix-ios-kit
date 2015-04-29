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

@interface MXKAccountManager() {
    /**
     The list of accounts. Each value is a `MXKAccount` instance.
     */
    NSMutableArray *mxAccounts;
}

@end

@implementation MXKAccountManager

+ (MXKAccountManager *)sharedManager {
    
    @synchronized(self) {
        if(sharedAccountManager == nil) {
            sharedAccountManager = [[super allocWithZone:NULL] init];
        }
    }
    return sharedAccountManager;
}

- (instancetype)init {

    self = [super init];
    if (self) {
        [self loadAccounts];
    }
    return self;
}

- (void)dealloc {
    
    mxAccounts = nil;
}

- (void)saveAccounts {
    
    if (mxAccounts.count) {
        NSData *accountData = [NSKeyedArchiver archivedDataWithRootObject:mxAccounts];
        
        [[NSUserDefaults standardUserDefaults] setObject:accountData forKey:@"accounts"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"accounts"];
    }
}

- (void)loadAccounts {
    
    NSData *accountData = [[NSUserDefaults standardUserDefaults] objectForKey:@"accounts"];
    if (accountData) {
        mxAccounts = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountData]];
    } else {
        mxAccounts = [NSMutableArray array];
    }
}

#pragma mark -

- (MXKAccount *)accountForUserId:(NSString *)userId {

    for (MXKAccount *account in mxAccounts) {
        if ([account.mxCredentials.userId isEqualToString:userId]) {
            return account;
        }
    }
    return nil;
}

- (void)addAccount:(MXKAccount *)account {
    
    NSLog(@"[MXKAccountManager] login (%@)", account.mxCredentials.userId);
    
    [mxAccounts addObject:account];
    
    [self saveAccounts];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidAddAccountNotification object:account.mxCredentials.userId userInfo:nil];
}

- (void)removeAccount:(MXKAccount*)account {
    
    NSLog(@"[MXKAccountManager] logout (%@)", account.mxCredentials.userId);
    
    [account closeSession];
    
    [mxAccounts removeObject:account];
    [self saveAccounts];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountManagerDidRemoveAccountNotification object:account.mxCredentials.userId userInfo:nil];
}

#pragma mark -

- (NSArray *)accounts {
    return [mxAccounts copy];
}

@end
