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

#import "MXKRoomDataSourceManager.h"

@interface MXKAccount () {
    
    // We will notify user only once on session failure
    BOOL notifyOpenSessionFailure;
    
    // The timer used to postpone server sync on failure
    NSTimer* initialServerSyncTimer;
    
    // Reachability observer
    id reachabilityObserver;

    // Handle user's settings change
    id userUpdateListener;
    
    // Used for logging application start up
    NSDate *openSessionStartDate;
    
    // Event notifications listener
    id notificationCenterListener;
    
    // Internal list of ignored rooms
    NSMutableArray* ignoredRooms;
}

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end

@implementation MXKAccount
@synthesize mxCredentials, mxSession, mxRestClient;
@synthesize userPresence;

- (instancetype)initWithCredentials:(MXCredentials*)credentials {
    
    if (self = [super init]) {
        notifyOpenSessionFailure = YES;
        
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
    
    [mxRestClient close];
    mxRestClient = nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    
    notifyOpenSessionFailure = YES;
    
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

-(void)openSessionWithStore:(id<MXStore>)store {
    
    // Sanity check
    if (!mxCredentials || !mxRestClient) {
        NSLog(@"[MXKAccount] Matrix session cannot be created without credentials");
        return;
    }
    
    // Close potential session
    [self closeSession];
    
    openSessionStartDate = [NSDate date];
    
    // Instantiate new session
    mxSession = [[MXSession alloc] initWithMatrixRestClient:mxRestClient];
    
    __weak typeof(self) weakSelf = self;
    [mxSession setStore:store success:^{
        // Complete session registration by launching live stream
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf launchInitialServerSync];
    } failure:^(NSError *error) {
        // This cannot happen. Loading of MXFileStore cannot fail.
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->mxSession = nil;
    }];
}

- (void)closeSession {
    
    [self removeNotificationListener];
    
    if (reachabilityObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
    }
    
    [initialServerSyncTimer invalidate];
    initialServerSyncTimer = nil;
    
    if (userUpdateListener) {
        [mxSession.myUser removeListener:userUpdateListener];
        userUpdateListener = nil;
    }
    
    //FIXME uncomment this line when presence will be handled correctly on multiple devices.
//    [self setUserPresence:MXPresenceOffline andStatusMessage:nil completion:nil];
    
    [mxSession close];
    mxSession = nil;
    
    notifyOpenSessionFailure = YES;
}

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
    else {
        // Cancel pending actions
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
        [initialServerSyncTimer invalidate];
        initialServerSyncTimer = nil;
    }
}

- (void)resume {
    if (mxSession) {
        if (mxSession.state == MXSessionStatePaused) {
            // Resume SDK and update user presence
            [mxSession resume:^{
                [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
            }];
        } else if (mxSession.state == MXSessionStateStoreDataReady) {
            // The session initialisation was uncompleted, we try to complete it here.
            [self launchInitialServerSync];
        }
        
        if (_bgTask) {
            // Cancel background task
            [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
            _bgTask = UIBackgroundTaskInvalid;
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX cancelled", (unsigned long)_bgTask);
        }
    }
}

#pragma mark - Push notification listeners

- (void)listenToNotifications:(MXOnNotification)onNotification {
    
    // Check conditions required to add notification listener
    if (!mxSession || !onNotification) {
        return;
    }
    
    // Remove existing listener (if any)
    [self removeNotificationListener];
    
    // Register on notification center
    notificationCenterListener = [self.mxSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule) {
        
        // Apply first the event filter defined in the related room data source
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:event.roomId create:NO];
        if (!roomDataSource || [roomDataSource.eventsFilterForMessages indexOfObject:event.type] == NSNotFound) {
            // Ignore
            return;
        }
        
        // Check conditions to report this notification
        if ([ignoredRooms indexOfObject:event.roomId] == NSNotFound) {
            onNotification(event, roomState, rule);
        }
    }];
}

- (void)removeNotificationListener {
    
    if (notificationCenterListener) {
        [self.mxSession.notificationCenter removeListener:notificationCenterListener];
        notificationCenterListener = nil;
    }
    ignoredRooms = nil;
}

- (void)updateNotificationListenerForRoomId:(NSString*)roomID ignore:(BOOL)isIgnored {
    
    if (isIgnored) {
        if (!ignoredRooms) {
            ignoredRooms = [[NSMutableArray alloc] init];
        }
        [ignoredRooms addObject:roomID];
    } else if (ignoredRooms) {
        [ignoredRooms removeObject:roomID];
    }
}

#pragma mark -

- (void)launchInitialServerSync {
    // Complete the session registration when store data is ready.
    
    // Cancel potential reachability observer and pending action
    [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
    reachabilityObserver = nil;
    [initialServerSyncTimer invalidate];
    initialServerSyncTimer = nil;
    
    // Sanity check
    if (!mxSession || mxSession.state != MXSessionStateStoreDataReady) {
        NSLog(@"[MXKAccount] Initial server sync is applicable only when store data is ready to complete session initialisation");
        return;
    }
    
    // Launch mxSession
    [mxSession start:^{
        NSLog(@"[MXKAccount] The session is ready. Matrix SDK session has been started in %0.fms.", [[NSDate date] timeIntervalSinceDate:openSessionStartDate] * 1000);
        
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
        
    } failure:^(NSError *error) {
        NSLog(@"[MXKAccount] Initial Sync failed: %@", error);
        if (notifyOpenSessionFailure) {
            //Alert user only once
            notifyOpenSessionFailure = NO;
            // TODO GFO Alert user
//            [[AppDelegate theDelegate] showErrorAsAlert:error];
        }
        
        // Check network reachability
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet) {
            // Add observer to launch a new attempt according to reachability.
            reachabilityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                NSNumber *statusItem = note.userInfo[AFNetworkingReachabilityNotificationStatusItem];
                if (statusItem) {
                    AFNetworkReachabilityStatus reachabilityStatus = statusItem.integerValue;
                    if (reachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi || reachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN) {
                        // New attempt
                        [self launchInitialServerSync];
                    }
                }
            }];
        } else {
            // Postpone a new attempt in 10 sec
            initialServerSyncTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(launchInitialServerSync) userInfo:self repeats:NO];
        }
    }];
}

@end
