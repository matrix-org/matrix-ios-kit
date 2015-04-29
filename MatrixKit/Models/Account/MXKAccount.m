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

#import "MXKAccount.h"

@interface MXKAccount () {
    id<MXStore> mxStore;
    
    // Handle user's settings change
    id userUpdateListener;
}

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end

@implementation MXKAccount
@synthesize mxCredentials, mxSession, mxRestClient;
@synthesize userPresence;

- (instancetype)initWithCredentials:(MXCredentials*)credentials {
    
    if (self = [super init]) {
        // Report credentials and alloc REST client.
        mxCredentials = credentials;
        mxRestClient = [[MXRestClient alloc] initWithCredentials:credentials];
        
        userPresence = MXPresenceUnknown;
    }
    return self;
}

- (void)dealloc {
    
    [self closeSession];
    mxSession = nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    
    NSString *homeServerURL = [coder decodeObjectForKey:@"homeserverurl"];
    NSString *userId = [coder decodeObjectForKey:@"userid"];
    NSString *accessToken = [coder decodeObjectForKey:@"accesstoken"];
    
    mxCredentials = [[MXCredentials alloc] initWithHomeServer:homeServerURL
                                                       userId:userId
                                                  accessToken:accessToken];
    
    mxRestClient = [[MXRestClient alloc] initWithCredentials:mxCredentials];
    
    userPresence = MXPresenceUnknown;
    
    if ([coder decodeObjectForKey:@"identityserverurl"]) {
        self.identityServerURL = [coder decodeObjectForKey:@"identityserverurl"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    
    [coder encodeObject:mxCredentials.homeServer forKey:@"homeserverurl"];
    [coder encodeObject:mxCredentials.userId forKey:@"userid"];
    [coder encodeObject:mxCredentials.accessToken forKey:@"accesstoken"];
    
    if (self.identityServerURL) {
        [coder encodeObject:self.identityServerURL forKey:@"identityserverurl"];
    }
}

#pragma mark -

- (void)setIdentityServerURL:(NSString *)identityServerURL {
    
    if (identityServerURL.length) {
        _identityServerURL = identityServerURL;
        // Update the current restClient
        [mxRestClient setIdentityServer:identityServerURL];
    } else {
        _identityServerURL = nil;
        // By default, use the same address for the identity server
        [mxRestClient setIdentityServer:mxCredentials.homeServer];
    }
}

#pragma mark - Matrix user's presence

- (void)setUserPresence:(MXPresence)presence andStatusMessage:(NSString *)statusMessage completion:(void (^)(void))completion {
    
    userPresence = presence;
    
    if (mxSession) {
        // Update user presence on server side
        [mxSession.myUser setPresence:userPresence andStatusMessage:statusMessage success:^{
            NSLog(@"[MXKAccount] %@: set user presence (%lu) succeeded", mxCredentials.userId, (unsigned long)userPresence);
            if (completion) {
                completion();
            }
        } failure:^(NSError *error) {
            NSLog(@"[MXKAccount] %@: set user presence (%lu) failed: %@", mxCredentials.userId, (unsigned long)userPresence, error);
        }];
    }
}

#pragma mark -

-(void)createSessionWithStore:(id<MXStore>)store success:(void (^)())onStoreDataReady failure:(void (^)(NSError *))failure {
    
    // Sanity check
    if (!mxCredentials) {
        NSLog(@"[MXKAccount] Matrix session cannot be created without credentials");
        return;
    }
    
    // Close potential session
    [self closeSession];
    
    if (mxRestClient) {
        
        mxSession = [[MXSession alloc] initWithMatrixRestClient:mxRestClient];
        
        __weak typeof(self) weakSelf = self;
        [mxSession setStore:store success:^() {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->mxStore = store;
            
            if (onStoreDataReady) {
                onStoreDataReady ();
            }
            
        }failure:^(NSError *error) {
            // This cannot happen. Loading of MXFileStore cannot fail.
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->mxSession = nil;
            
            if (failure) {
                failure (error);
            }
        }];
    }
}

- (void)startSession:(void (^)())onServerSyncDone failure:(void (^)(NSError *))failure {
    
    // Complete the session registration when store data is ready.
    
    // Sanity check
    if (!mxSession || mxSession.state != MXSessionStateStoreDataReady) {
        NSLog(@"[MXKAccount] Initial server sync is applicable only when store data is ready to complete session initialisation");
        return;
    }
    
    // Launch mxSession
    [mxSession start:^{
        
        [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
        
        // Register listener to update user's information
        userUpdateListener = [mxSession.myUser listenToUserUpdate:^(MXEvent *event) {
            // Consider only events related to user's presence
            if (event.eventType == MXEventTypePresence) {
                MXPresence presence = [MXTools presence:event.content[@"presence"]];
                if (userPresence != presence) {
                    // Handle user presence on multiple devices (keep the more pertinent)
                    if (userPresence == MXPresenceOnline) {
                        if (presence == MXPresenceUnavailable || presence == MXPresenceOffline) {
                            // Force the local presence to overwrite the user presence on server side
                            [self setUserPresence:userPresence andStatusMessage:nil completion:nil];
                            return;
                        }
                    } else if (userPresence == MXPresenceUnavailable) {
                        if (presence == MXPresenceOffline) {
                            // Force the local presence to overwrite the user presence on server side
                            [self setUserPresence:userPresence andStatusMessage:nil completion:nil];
                            return;
                        }
                    }
                    userPresence = presence;
                }
            }
        }];
        
        if (onServerSyncDone) {
            onServerSyncDone ();
        }
    } failure:^(NSError *error) {
        NSLog(@"[MXKAccount] Initial Sync failed: %@", error);
        
        if (failure) {
            failure (error);
        }
    }];
}

- (void)closeSession {
    
    if (userUpdateListener) {
        [mxSession.myUser removeListener:userUpdateListener];
        userUpdateListener = nil;
    }
    
    //FIXME uncomment this line when presence will be handled correctly on multiple devices.
//    [self setUserPresence:MXPresenceOffline andStatusMessage:nil completion:nil];
    
    [mxSession close];
    mxSession = nil;
    
    [mxRestClient close];
    mxRestClient = nil;
}

#pragma mark -

- (void)pauseInBackgroundTask {
    
    if (mxSession && mxSession.state == MXSessionStateRunning) {
        _bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
            _bgTask = UIBackgroundTaskInvalid;
            
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX expired", (unsigned long)_bgTask);
        }];
        
        NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX starts", (unsigned long)_bgTask);
        // Pause SDK
        [mxSession pause];
        
        // Update user presence
        __weak typeof(self) weakSelf = self;
        [self setUserPresence:MXPresenceUnavailable andStatusMessage:nil completion:^{
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX ends", (unsigned long)weakSelf.bgTask);
            [[UIApplication sharedApplication] endBackgroundTask:weakSelf.bgTask];
            weakSelf.bgTask = UIBackgroundTaskInvalid;
            NSLog(@"[MXKAccount] >>>>> background pause task finished");
        }];
    }
}

- (void)resume {
    if (mxSession) {
        if (mxSession.state == MXSessionStatePaused) {
            // Resume SDK and update user presence
            [mxSession resume:^{
                [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
            }];
        }
        
        if (_bgTask) {
            // Cancel background task
            [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
            _bgTask = UIBackgroundTaskInvalid;
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX cancelled", (unsigned long)_bgTask);
        }
    }
}

@end
