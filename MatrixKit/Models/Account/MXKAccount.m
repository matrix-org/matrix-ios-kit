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

#import "MXKAccountManager.h"
#import "MXKRoomDataSourceManager.h"

#import "MXKTools.h"

#import "MXKConstants.h"

#import "NSBundle+MatrixKit.h"

#import "MXSession.h"

NSString *const kMXKAccountUserInfoDidChangeNotification = @"kMXKAccountUserInfoDidChangeNotification";
NSString *const kMXKAccountAPNSActivityDidChangeNotification = @"kMXKAccountAPNSActivityDidChangeNotification";

NSString *const kMXKAccountErrorDomain = @"kMXKAccountErrorDomain";

static MXKAccountOnCertificateChange _onCertificateChangeBlock;

@interface MXKAccount ()
{
    // We will notify user only once on session failure
    BOOL notifyOpenSessionFailure;
    
    // The timer used to postpone server sync on failure
    NSTimer* initialServerSyncTimer;
    
    // Reachability observer
    id reachabilityObserver;
    
    // Session state observer
    id sessionStateObserver;
    
    // Handle user's settings change
    id userUpdateListener;
    
    // Used for logging application start up
    NSDate *openSessionStartDate;
    
    // Event notifications listener
    id notificationCenterListener;
    
    // Internal list of ignored rooms
    NSMutableArray* ignoredRooms;
    
    // If a server sync is in progress, the pause is delayed at the end of sync (except if resume is called).
    BOOL isPauseRequested;
    
    // catchup management
    MXOnCatchupDone catchupDone;
    MXOnCatchupFail catchupfails;
    UIBackgroundTaskIdentifier catchupBgTask;
    NSTimer* catchupTimer;
}

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@end

@implementation MXKAccount
@synthesize mxCredentials, mxSession, mxRestClient;
@synthesize userPresence;
@synthesize userTintColor;
@synthesize hideUserPresence;

+ (void)registerOnCertificateChangeBlock:(MXKAccountOnCertificateChange)onCertificateChangeBlock
{
    _onCertificateChangeBlock = onCertificateChangeBlock;
}

+ (UIColor*)presenceColor:(MXPresence)presence
{
    switch (presence)
    {
        case MXPresenceOnline:
            return [[MXKAppSettings standardAppSettings] presenceColorForOnlineUser];
        case MXPresenceUnavailable:
            return [[MXKAppSettings standardAppSettings] presenceColorForUnavailableUser];
        case MXPresenceOffline:
            return [[MXKAppSettings standardAppSettings] presenceColorForOfflineUser];
        case MXPresenceUnknown:
        case MXPresenceFreeForChat:
        case MXPresenceHidden:
        default:
            return nil;
    }
}

- (instancetype)initWithCredentials:(MXCredentials*)credentials
{
    if (self = [super init])
    {
        notifyOpenSessionFailure = YES;
        
        // Report credentials and alloc REST client.
        mxCredentials = credentials;
        [self prepareRESTClient];
        
        userPresence = MXPresenceUnknown;
    }
    return self;
}

- (void)dealloc
{
    [self closeSession:NO];
    mxSession = nil;
    
    [mxRestClient close];
    mxRestClient = nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    if (self)
    {
        notifyOpenSessionFailure = YES;
        
        NSString *homeServerURL = [coder decodeObjectForKey:@"homeserverurl"];
        NSString *userId = [coder decodeObjectForKey:@"userid"];
        NSString *accessToken = [coder decodeObjectForKey:@"accesstoken"];
        
        mxCredentials = [[MXCredentials alloc] initWithHomeServer:homeServerURL
                                                           userId:userId
                                                      accessToken:accessToken];
        
        mxCredentials.allowedCertificate = [coder decodeObjectForKey:@"allowedCertificate"];
        
        [self prepareRESTClient];
        
        userPresence = MXPresenceUnknown;
        
        if ([coder decodeObjectForKey:@"identityserverurl"])
        {
            _identityServerURL = [coder decodeObjectForKey:@"identityserverurl"];
            if (_identityServerURL.length)
            {
                // Update the current restClient
                [mxRestClient setIdentityServer:_identityServerURL];
            }
        }
        
        _enablePushNotifications = [coder decodeBoolForKey:@"_enablePushNotifications"];
        _enableInAppNotifications = [coder decodeBoolForKey:@"enableInAppNotifications"];
        
        _disabled = [coder decodeBoolForKey:@"disabled"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:mxCredentials.homeServer forKey:@"homeserverurl"];
    [coder encodeObject:mxCredentials.userId forKey:@"userid"];
    [coder encodeObject:mxCredentials.accessToken forKey:@"accesstoken"];
    
    if (mxCredentials.allowedCertificate)
    {
        [coder encodeObject:mxCredentials.allowedCertificate forKey:@"allowedCertificate"];
    }
    
    if (self.identityServerURL)
    {
        [coder encodeObject:_identityServerURL forKey:@"identityserverurl"];
    }
    
    [coder encodeBool:_enablePushNotifications forKey:@"_enablePushNotifications"];
    [coder encodeBool:_enableInAppNotifications forKey:@"enableInAppNotifications"];
    
    [coder encodeBool:_disabled forKey:@"disabled"];
}

#pragma mark - Properties

- (void)setIdentityServerURL:(NSString *)identityServerURL
{
    if (identityServerURL.length)
    {
        _identityServerURL = identityServerURL;
        // Update the current restClient
        [mxRestClient setIdentityServer:identityServerURL];
    }
    else
    {
        _identityServerURL = nil;
        // By default, use the same address for the identity server
        [mxRestClient setIdentityServer:mxCredentials.homeServer];
    }
    
    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

- (NSString*)userDisplayName
{
    if (mxSession)
    {
        return mxSession.myUser.displayname;
    }
    return nil;
}

- (NSString*)userAvatarUrl
{
    if (mxSession)
    {
        return mxSession.myUser.avatarUrl;
    }
    return nil;
}

- (NSString*)fullDisplayName
{
    if (self.userDisplayName.length)
    {
        return [NSString stringWithFormat:@"%@ (%@)", self.userDisplayName, mxCredentials.userId];
    }
    else
    {
        return mxCredentials.userId;
    }
}

- (UIColor*)userTintColor
{
    if (!userTintColor)
    {
        userTintColor = [MXKTools colorWithRGBValue:[mxCredentials.userId hash]];
    }
    
    return userTintColor;
}

- (BOOL)pushNotificationServiceIsActive
{
    return ([[MXKAccountManager sharedManager] isAPNSAvailable] && _enablePushNotifications && mxSession);
}

- (void)setEnablePushNotifications:(BOOL)enablePushNotifications
{
    // Update the pusher, report the new value only on success.
    [self enablePusher:enablePushNotifications
               success:^{
                   
                   _enablePushNotifications = enablePushNotifications;
                   
                   // Archive updated field
                   [[MXKAccountManager sharedManager] saveAccounts];
               }
               failure:nil];
}

- (void)setEnableInAppNotifications:(BOOL)enableInAppNotifications
{
    _enableInAppNotifications = enableInAppNotifications;
    
    // Archive updated field
    [[MXKAccountManager sharedManager] saveAccounts];
}

- (void)setDisabled:(BOOL)disabled
{
    if (_disabled != disabled)
    {
        _disabled = disabled;
        
        if (_disabled)
        {
            // Close session (keep the storage).
            [self closeSession:NO];
	    if (_enablePushNotifications)
	    {
		// Turn off pusher
		[self enablePusher:NO success:nil failure:nil];
	    }
    
        }
        else if (!mxSession)
        {
            // Open a new matrix session
            id<MXStore> store = [[[MXKAccountManager sharedManager].storeClass alloc] init];
            
            [self openSessionWithStore:store];
        }
        
        // Archive updated field
        [[MXKAccountManager sharedManager] saveAccounts];
    }
}

#pragma mark - Matrix user's profile

- (void)setUserDisplayName:(NSString*)displayname success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    if (mxSession && mxSession.myUser)
    {
        [mxSession.myUser setDisplayName:displayname
                                 success:^{
                                     if (success) {
                                         success();
                                     }
                                     
                                     [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
                                 }
                                 failure:failure];
    }
    else if (failure)
    {
        failure ([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"account_error_matrix_session_is_not_opened"]}]);
    }
}

- (void)setUserAvatarUrl:(NSString*)avatarUrl success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    if (mxSession && mxSession.myUser)
    {
        [mxSession.myUser setAvatarUrl:avatarUrl
                               success:^{
                                   if (success) {
                                       success();
                                   }
                                   
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
                               }
                               failure:failure];
    }
    else if (failure)
    {
        failure ([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"account_error_matrix_session_is_not_opened"]}]);
    }
}

- (void)changePassword:(NSString*)oldPassword with:(NSString*)newPassword success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    if (mxSession)
    {
        [mxRestClient changePassword:oldPassword
                                with:newPassword
                             success:^{
                                 
                                 if (success) {
                                     success();
                                 }
                                 
                             }
                             failure:failure];
    }
    else if (failure)
    {
        failure ([NSError errorWithDomain:kMXKAccountErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"account_error_matrix_session_is_not_opened"]}]);
    }
}

- (void)setUserPresence:(MXPresence)presence andStatusMessage:(NSString *)statusMessage completion:(void (^)(void))completion
{
    userPresence = presence;
    
    if (mxSession && !hideUserPresence)
    {
        // Update user presence on server side
        [mxSession.myUser setPresence:userPresence
                     andStatusMessage:statusMessage
                              success:^{
                                  NSLog(@"[MXKAccount] %@: set user presence (%lu) succeeded", mxCredentials.userId, (unsigned long)userPresence);
                                  if (completion)
                                  {
                                      completion();
                                  }
                                  
                                  [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
                              }
                              failure:^(NSError *error) {
                                  NSLog(@"[MXKAccount] %@: set user presence (%lu) failed: %@", mxCredentials.userId, (unsigned long)userPresence, error);
                              }];
    }
    else if (hideUserPresence)
    {
        NSLog(@"[MXKAccount] %@: set user presence is disabled.", mxCredentials.userId);
    }
}

#pragma mark -

/**
 Create a matrix session based on the provided store.
 When store data is ready, the live stream is automatically launched by synchronising the session with the server.
 
 In case of failure during server sync, the method is reiterated until the data is up-to-date with the server.
 This loop is stopped if you call [MXCAccount closeSession:], it is suspended if you call [MXCAccount pauseInBackgroundTask].
 
 @param store the store to use for the session.
 */
-(void)openSessionWithStore:(id<MXStore>)store
{
    // Sanity check
    if (!mxCredentials || !mxRestClient)
    {
        NSLog(@"[MXKAccount] Matrix session cannot be created without credentials");
        return;
    }
    
    // Close potential session (keep associated store).
    [self closeSession:NO];
    
    openSessionStartDate = [NSDate date];
    
    // Instantiate new session
    mxSession = [[MXSession alloc] initWithMatrixRestClient:mxRestClient];

    // Register session state observer
    sessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        // Check whether the concerned session is the associated one
        if (notif.object == mxSession)
        {
            [self onMatrixSessionStateChange];
        }
    }];
    
    __weak typeof(self) weakSelf = self;
    [mxSession setStore:store success:^{
        
        // Complete session registration by launching live stream
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        
        // Restore pusher (if it is enabled)
        if (strongSelf->_enablePushNotifications)
        {
            [strongSelf enablePusher:strongSelf->_enablePushNotifications
                             success:nil
                             failure:^(NSError *error) {
                                 
                                 strongSelf->_enablePushNotifications = NO;
                                 
                                 // Archive updated field
                                 [[MXKAccountManager sharedManager] saveAccounts];
                             }];
        }
        
        // Launch server sync
        [strongSelf launchInitialServerSync];
        
    } failure:^(NSError *error) {
        
        // This cannot happen. Loading of MXFileStore cannot fail.
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->mxSession = nil;
        
        [[NSNotificationCenter defaultCenter] removeObserver:strongSelf->sessionStateObserver];
        strongSelf->sessionStateObserver = nil;
        
    }];
}

/**
 Close the matrix session.
 
 @param clearStore set YES to delete all store data.
 */
- (void)closeSession:(BOOL)clearStore
{
    [self removeNotificationListener];
    
    if (reachabilityObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
    }
    
    if (sessionStateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:sessionStateObserver];
        sessionStateObserver = nil;
    }
    
    [initialServerSyncTimer invalidate];
    initialServerSyncTimer = nil;
    
    if (userUpdateListener)
    {
        [mxSession.myUser removeListener:userUpdateListener];
        userUpdateListener = nil;
    }
    
    if (mxSession)
    {
        // Reset room data stored in memory
        [MXKRoomDataSourceManager removeSharedManagerForMatrixSession:mxSession];
        
        // Close session
        [mxSession close];
        
        if (clearStore)
        {
            [mxSession.store deleteAllData];
        }
        
        mxSession = nil;
    }
    
    notifyOpenSessionFailure = YES;
}

- (void)logout
{
    [self closeSession:YES];
    if (_enablePushNotifications)
    {
        // Turn off pusher
        [self enablePusher:NO success:nil failure:nil];
    }
    
}

- (void)pauseInBackgroundTask
{
    if (mxSession && mxSession.state == MXSessionStateRunning)
    {
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
    else
    {
        // Cancel pending actions
        [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
        reachabilityObserver = nil;
        [initialServerSyncTimer invalidate];
        initialServerSyncTimer = nil;
        
        if (mxSession.state == MXSessionStateSyncInProgress)
        {
            isPauseRequested = YES;
        }
    }
}

- (void)resume
{
    isPauseRequested = NO;
    
    if (mxSession)
    {
        [self cancelCatchup];
        
        if (mxSession.state == MXSessionStatePaused)
        {
            // Resume SDK and update user presence
            [mxSession resume:^{
                [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
            }];
        }
        else if (mxSession.state == MXSessionStateStoreDataReady)
        {
            // The session initialisation was uncompleted, we try to complete it here.
            [self launchInitialServerSync];
        }
        
        if (_bgTask)
        {
            // Cancel background task
            [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
            _bgTask = UIBackgroundTaskInvalid;
            NSLog(@"[MXKAccount] pauseInBackgroundTask : %08lX cancelled", (unsigned long)_bgTask);
        }
    }
}

- (void)reload:(BOOL)clearCache
{
    // close potential session
    [self closeSession:clearCache];
    
    if (!_disabled)
    {
        // Open a new matrix session
        id<MXStore> store = [[[MXKAccountManager sharedManager].storeClass alloc] init];
        [self openSessionWithStore:store];
    }
}

#pragma mark - Push notifications

// Update the pusher for this device and this account on the Home Server.
- (void)enablePusher:(BOOL)enabled success:(void (^)())success failure:(void (^)(NSError *))failure
{
    // Refuse to try & turn push on if we're not logged in, it's nonsensical.
    if (!mxCredentials)
    {
        NSLog(@"[MXKAccount] Not setting push token because we're not logged in");
        return;
    }
    
#ifdef DEBUG
    NSString *appId = [[NSUserDefaults standardUserDefaults] objectForKey:@"pusherAppIdDev"];
#else
    NSString *appId = [[NSUserDefaults standardUserDefaults] objectForKey:@"pusherAppIdProd"];
#endif
    
    if (!appId)
    {
        NSLog(@"[MXKAccount] Not setting pusher because pusher app id is undefined");
        return;
    }
    
    NSString *appDisplayName = [NSString stringWithFormat:@"%@ (iOS)", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
    
    NSString *b64Token = [[MXKAccountManager sharedManager].apnsDeviceToken base64EncodedStringWithOptions:0];
    NSDictionary *pushData = @{
                               @"url": @"https://matrix.org/_matrix/push/v1/notify",
                               };
    
    NSString *deviceLang = [NSLocale preferredLanguages][0];
    
    NSString * profileTag = [[NSUserDefaults standardUserDefaults] valueForKey:@"pusherProfileTag"];
    if (!profileTag)
    {
        profileTag = @"";
        NSString *alphabet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        for (int i = 0; i < 16; ++i)
        {
            unsigned char c = [alphabet characterAtIndex:arc4random() % alphabet.length];
            profileTag = [profileTag stringByAppendingFormat:@"%c", c];
        }
        NSLog(@"[MXKAccount] Generated fresh profile tag: %@", profileTag);
        [[NSUserDefaults standardUserDefaults] setValue:profileTag forKey:@"pusherProfileTag"];
    }
    else
    {
        NSLog(@"[MXKAccount] Using existing profile tag: %@", profileTag);
    }
    
    NSObject *kind = enabled ? @"http" : [NSNull null];
    
    // Retrieve the append flag from manager to handle multiple accounts registration
    BOOL append = [MXKAccountManager sharedManager].apnsAppendFlag;
    NSLog(@"[MXKAccount] append flag: %d", append);
    
    MXRestClient *restCli = self.mxRestClient;
    
    [restCli setPusherWithPushkey:b64Token kind:kind appId:appId appDisplayName:appDisplayName deviceDisplayName:[[UIDevice currentDevice] name] profileTag:profileTag lang:deviceLang data:pushData append:append success:^{
        NSLog(@"[MXKAccount] Succeeded to update pusher for %@", self.mxCredentials.userId);
        
        if (success)
        {
            success();
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountAPNSActivityDidChangeNotification object:mxCredentials.userId];
    } failure:^(NSError *error) {

        // Ignore error if the client try to disable an unknown token
        if (!enabled)
        {
            // Check whether the token was unknown
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringUnknown])
            {
                NSLog(@"[MXKAccount] APNS was already disabled for %@! (%@)", self.mxCredentials.userId, error);
                
                // Ignore the error
                if (success)
                {
                    success();
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountAPNSActivityDidChangeNotification object:mxCredentials.userId];
                
                return;
            }
            
            NSLog(@"[MXKAccount] Failed to disable APNS %@! (%@)", self.mxCredentials.userId, error);
        }
        else
        {
            NSLog(@"[MXKAccount] Failed to send APNS token for %@! (%@)", self.mxCredentials.userId, error);
        }
        
        if (failure)
        {
            failure(error);
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountAPNSActivityDidChangeNotification object:mxCredentials.userId];
    }];
}

#pragma mark - InApp notifications

- (void)listenToNotifications:(MXOnNotification)onNotification
{
    // Check conditions required to add notification listener
    if (!mxSession || !onNotification)
    {
        return;
    }
    
    // Remove existing listener (if any)
    [self removeNotificationListener];
    
    // Register on notification center
    notificationCenterListener = [self.mxSession.notificationCenter listenToNotifications:^(MXEvent *event, MXRoomState *roomState, MXPushRule *rule)
    {
        // Apply first the event filter defined in the related room data source
        MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:mxSession];
        MXKRoomDataSource *roomDataSource = [roomDataSourceManager roomDataSourceForRoom:event.roomId create:NO];
        if (!roomDataSource || [roomDataSource.eventsFilterForMessages indexOfObject:event.type] == NSNotFound)
        {
            // Ignore
            return;
        }
        
        // Check conditions to report this notification
        if (nil == ignoredRooms || [ignoredRooms indexOfObject:event.roomId] == NSNotFound)
        {
            onNotification(event, roomState, rule);
        }
    }];
}

- (void)removeNotificationListener
{
    if (notificationCenterListener)
    {
        [self.mxSession.notificationCenter removeListener:notificationCenterListener];
        notificationCenterListener = nil;
    }
    ignoredRooms = nil;
}

- (void)updateNotificationListenerForRoomId:(NSString*)roomID ignore:(BOOL)isIgnored
{
    if (isIgnored)
    {
        if (!ignoredRooms)
        {
            ignoredRooms = [[NSMutableArray alloc] init];
        }
        [ignoredRooms addObject:roomID];
    }
    else if (ignoredRooms)
    {
        [ignoredRooms removeObject:roomID];
    }
}

#pragma mark - Internals

- (void)launchInitialServerSync
{
    // Complete the session registration when store data is ready.
    
    // Cancel potential reachability observer and pending action
    [[NSNotificationCenter defaultCenter] removeObserver:reachabilityObserver];
    reachabilityObserver = nil;
    [initialServerSyncTimer invalidate];
    initialServerSyncTimer = nil;
    
    // Sanity check
    if (!mxSession || mxSession.state != MXSessionStateStoreDataReady)
    {
        NSLog(@"[MXKAccount] Initial server sync is applicable only when store data is ready to complete session initialisation");
        return;
    }
    
    // Launch mxSession
    [mxSession start:^{
        
        NSLog(@"[MXKAccount] %@: The session is ready. Matrix SDK session has been started in %0.fms.", mxCredentials.userId, [[NSDate date] timeIntervalSinceDate:openSessionStartDate] * 1000);
        
        [self setUserPresence:MXPresenceOnline andStatusMessage:nil completion:nil];
        
    } failure:^(NSError *error) {
        
        NSLog(@"[MXKAccount] Initial Sync failed: %@", error);
        if (notifyOpenSessionFailure && error)
        {
            // Notify MatrixKit user only once
            notifyOpenSessionFailure = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
        }
        
        // Check network reachability
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorNotConnectedToInternet)
        {
            // Add observer to launch a new attempt according to reachability.
            reachabilityObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AFNetworkingReachabilityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
            {
                NSNumber *statusItem = note.userInfo[AFNetworkingReachabilityNotificationStatusItem];
                if (statusItem)
                {
                    AFNetworkReachabilityStatus reachabilityStatus = statusItem.integerValue;
                    if (reachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi || reachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN)
                    {
                        // New attempt
                        [self launchInitialServerSync];
                    }
                }
            }];
        }
        else
        {
            // Postpone a new attempt in 10 sec
            initialServerSyncTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(launchInitialServerSync) userInfo:self repeats:NO];
        }
    }];
}

- (void)onMatrixSessionStateChange
{
    if (mxSession.state == MXSessionStateRunning)
    {
        // Check if pause has been requested
        if (isPauseRequested)
        {
            [self pauseInBackgroundTask];
            return;
        }
        
        // Check whether the session was not already running
        if (!userUpdateListener)
        {
            // Register listener to user's information change
            userUpdateListener = [mxSession.myUser listenToUserUpdate:^(MXEvent *event) {
                // Consider events related to user's presence
                if (event.eventType == MXEventTypePresence)
                {
                    userPresence = [MXTools presence:event.content[@"presence"]];
                }
                
                // Here displayname or other information have been updated, post update notification.
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
            }];
            
            // User information are just up-to-date (`mxSession` is running), post update notification.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
        }
    }
    else if (mxSession.state == MXSessionStateStoreDataReady || mxSession.state == MXSessionStateSyncInProgress)
    {
        // Remove listener (if any), this action is required to handle correctly matrix sdk handler reload (see clear cache)
        if (userUpdateListener)
        {
            [mxSession.myUser removeListener:userUpdateListener];
            userUpdateListener = nil;
        }
        else
        {
            // Here the initial server sync is in progress. The session is not running yet, but some user's information are available (from local storage).
            // We post update notification to let observer take into account this user's information even if they may not be up-to-date.
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKAccountUserInfoDidChangeNotification object:mxCredentials.userId];
        }
    }
}

- (void)prepareRESTClient
{
    if (!mxCredentials)
    {
        return;
    }
    
    mxRestClient = [[MXRestClient alloc] initWithCredentials:mxCredentials andOnUnrecognizedCertificateBlock:^BOOL(NSData *certificate) {
        
        // Check whether the provided certificate is the one trusted by the user during login/registration step.
        if (mxCredentials.allowedCertificate && [mxCredentials.allowedCertificate isEqualToData:certificate])
        {
            return YES;
        }
        
        // Check whether the user has already ignored this certificate change.
        if (mxCredentials.ignoredCertificate && [mxCredentials.ignoredCertificate isEqualToData:certificate])
        {
            return NO;
        }
        
        if (_onCertificateChangeBlock)
        {
            if (_onCertificateChangeBlock (self, certificate))
            {
                // Update the certificate in credentials
                mxCredentials.allowedCertificate = certificate;
                
                // Archive updated field
                [[MXKAccountManager sharedManager] saveAccounts];
                
                return YES;
            }
            
            mxCredentials.ignoredCertificate = certificate;
            
            // Archive updated field
            [[MXKAccountManager sharedManager] saveAccounts];
        }
        return NO;
    
    }];
}

#pragma mark - catchup management

- (void)cancelCatchup
{
    if (catchupBgTask != UIBackgroundTaskInvalid)
    {
        NSLog(@"[MXKAccount] The catchup is cancelled.");

        if (mxSession)
        {
            if (mxSession.state == MXSessionStateCatchingUp)
            {
                [mxSession pause];
            }
        }
        
        [self onCatchupDoneWithError:[[NSError alloc] init]];
    }
}

- (void)onCatchupDoneWithError:(NSError*)error
{
    if (catchupTimer)
    {
        [catchupTimer invalidate];
        catchupTimer = NULL;
    }
    
    if (catchupfails && error)
    {
        catchupfails(error);
    }
    
    if (catchupDone && !error)
    {
        catchupDone();
    }
    
    catchupDone = NULL;
    catchupfails = NULL;
    
    if (catchupBgTask != UIBackgroundTaskInvalid)
    {
        UIBackgroundTaskIdentifier localCatchupBgTask = catchupBgTask;
        catchupBgTask = UIBackgroundTaskInvalid;
        
        // give some times to perform other stuff like store saving...
        dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            if (localCatchupBgTask != UIBackgroundTaskInvalid)
            {
                // Cancel background task
                [[UIApplication sharedApplication] endBackgroundTask:localCatchupBgTask];
                NSLog(@"[MXKAccount] onCatchupDoneWithError : %08lX stop", (unsigned long)localCatchupBgTask);
            }
        });
    }
}

- (void)onCatchupTimerOut
{
    [self cancelCatchup];
}

- (void)catchup:(unsigned int)timeout success:(void (^)())success failure:(void (^)(NSError *))failure
{
    isPauseRequested = NO;
    
    // only work when the application is suspended
    
    // FIXME SYNCV2 enable it when V2 will be released
    if (false)//(mxSession && mxSession.state == MXSessionStatePaused)
    {
        NSLog(@"[MXKAccount] starts a catchup");
        
        catchupDone = success;
        catchupfails = failure;
        
        if (catchupBgTask != UIBackgroundTaskInvalid)
        {
             [[UIApplication sharedApplication] endBackgroundTask:catchupBgTask];
        }
        
        catchupBgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            NSLog(@"[MXKAccount] the catchup fails because of the bg task timeout");
            [self cancelCatchup];
            
        }];
        
        // ensure that the catchup will be really done in the expected time
        // the request could be done but the treatment could be long so add a timer to cancel it
        // if it takes too much time
        catchupTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:(timeout - 1) / 1000]
                                                interval:0
                                                  target:self
                                                selector:@selector(onCatchupTimerOut)
                                                userInfo:nil
                                                 repeats:NO];
        
        [[NSRunLoop mainRunLoop] addTimer:catchupTimer forMode:NSDefaultRunLoopMode];
        
            [mxSession catchup:timeout success:^{
                NSLog(@"[MXKAccount] the catchup succeeds");
                [self onCatchupDoneWithError:NULL];
                
            }
                failure:^(NSError* error) {

                NSLog(@"[MXKAccount] the catchup fails");
                [self onCatchupDoneWithError:error];
                       
            }

         ];
    }
    else
    {
        NSLog(@"[MXKAccount] cannot start catchup (invalid state)");
        failure([[NSError alloc] init]);
    }
}


@end
