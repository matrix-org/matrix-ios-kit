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

#import "MXKContactManager.h"

#import "MXKContact.h"
#import "MXKEmail.h"

#import "MXKAppSettings.h"

NSString *const kMXKContactManagerDidUpdateMatrixContactsNotification = @"kMXKContactManagerDidUpdateMatrixContactsNotification";

NSString *const kMXKContactManagerDidUpdateLocalContactsNotification = @"kMXKContactManagerDidUpdateLocalContactsNotification";
NSString *const kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification = @"kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification";

NSString *const kMXKContactManagerMatrixUserPresenceChangeNotification = @"kMXKContactManagerMatrixUserPresenceChangeNotification";
NSString *const kMXKContactManagerMatrixPresenceKey = @"kMXKContactManagerMatrixPresenceKey";

NSString *const kMXKContactManagerDidInternationalizeNotification = @"kMXKContactManagerDidInternationalizeNotification";

@interface MXKContactManager()
{
    /**
     Array of `MXSession` instances.
     */
    NSMutableArray *mxSessionArray;
    id mxSessionStateObserver;
    id mxSessionNewSyncedRoomObserver;
    
    /**
     Listeners registered on matrix presence and membership events (one by matrix session)
     */
    NSMutableArray *mxEventListeners;
    
    /**
     Local contacts handling
     */
    BOOL isLocalContactListLoading;
    dispatch_queue_t processingQueue;
    NSDate *lastSyncDate;
    // Local contacts by contact Id
    NSMutableDictionary* localContactByContactID;
    NSMutableArray* localEmailContacts;
    // Matrix id linked to 3PID.
    NSMutableDictionary* matrixIDBy3PID;
    // Keep history of 3PID lookup requests
    NSMutableArray* pending3PIDs;
    NSMutableArray* checked3PIDs;
    
    /**
     Matrix contacts handling
     */
    // Matrix contacts by contact Id
    NSMutableDictionary* matrixContactByContactID;
    // Matrix contacts by matrix id
    NSMutableDictionary* matrixContactByMatrixID;
}

/**
 The current REST client defined with the identity server.
 */
@property (nonatomic) MXRestClient *identityRESTClient;
@end

@implementation MXKContactManager
@synthesize contactManagerMXRoomSource;

#pragma mark Singleton Methods
static MXKContactManager* sharedMXKContactManager = nil;

+ (id)sharedManager
{
    @synchronized(self)
    {
        if(sharedMXKContactManager == nil)
            sharedMXKContactManager = [[self alloc] init];
    }
    return sharedMXKContactManager;
}

#pragma mark -

-(MXKContactManager *)init
{
    if (self = [super init])
    {
        NSString *label = [NSString stringWithFormat:@"MatrixKit.%@.Contacts", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
        
        processingQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        
        // save the last sync date
        // to avoid resync the whole phonebook
        lastSyncDate = nil;
        
        self.contactManagerMXRoomSource = MXKContactManagerMXRoomSourceOneToOne;
        
        // Observe related settings change
        [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"syncLocalContacts" options:0 context:nil];
        [[MXKAppSettings standardAppSettings]  addObserver:self forKeyPath:@"phonebookCountryCode" options:0 context:nil];
    }
    
    return self;
}

-(void)dealloc
{
    [self reset];
    
    [[MXKAppSettings standardAppSettings] removeObserver:self forKeyPath:@"syncLocalContacts"];
    [[MXKAppSettings standardAppSettings] removeObserver:self forKeyPath:@"phonebookCountryCode"];
    
    processingQueue = nil;
}

#pragma mark -

- (void)addMatrixSession:(MXSession*)mxSession
{
    if (!mxSession)
    {
        return;
    }
    
    // Check conditions to trigger a full refresh of contacts matrix ids
    BOOL shouldUpdateLocalContactsMatrixIDs = (self.enableFullMatrixIdSyncOnLocalContactsDidLoad && !isLocalContactListLoading && !_identityRESTClient);
    
    if (!mxSessionArray)
    {
        mxSessionArray = [NSMutableArray array];
    }
    if (!mxEventListeners)
    {
        mxEventListeners = [NSMutableArray array];
    }
    
    if ([mxSessionArray indexOfObject:mxSession] == NSNotFound)
    {
        [mxSessionArray addObject:mxSession];
        
        // Register a listener on matrix presence and membership events
        id eventListener = [mxSession listenToEventsOfTypes:@[kMXEventTypeStringRoomMember, kMXEventTypeStringPresence]
                                                       onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
                               // Consider only live event
                               if (direction == MXTimelineDirectionForwards)
                               {
                                   // Consider first presence events
                                   if (event.eventType == MXEventTypePresence)
                                   {
                                       // Check whether the concerned matrix user belongs to at least one contact.
                                       BOOL isMatched = ([matrixContactByMatrixID objectForKey:event.sender] != nil);
                                       if (!isMatched)
                                       {
                                           NSArray *matrixIDs = [matrixIDBy3PID allValues];
                                           isMatched = ([matrixIDs indexOfObject:event.sender] != NSNotFound);
                                       }
                                       
                                       if (isMatched) {
                                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerMatrixUserPresenceChangeNotification object:event.sender userInfo:@{kMXKContactManagerMatrixPresenceKey:event.content[@"presence"]}];
                                       }
                                   }
                                   // Else the event type is MXEventTypeRoomMember.
                                   // Ignore here membership events if the session is not running yet,
                                   // Indeed all the contacts are refreshed when session state becomes running.
                                   else if (mxSession.state == MXSessionStateRunning)
                                   {
                                       // Update matrix contact list on membership change
                                       [self updateMatrixContactWithID:event.sender];
                                   }
                               }
                           }];
        
        [mxEventListeners addObject:eventListener];
        
        // Update matrix contact list in case of new synced one-to-one room
        if (!mxSessionNewSyncedRoomObserver)
        {
            mxSessionNewSyncedRoomObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomInitialSyncNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                // create contact for room members
                if (self.contactManagerMXRoomSource != MXKContactManagerMXRoomSourceNone)
                {
                    MXRoom *room = notif.object;
                    NSArray *roomMembers = room.state.members;
                    
                    // Consider only 1:1 chat for MXKMemberContactCreationOneToOneRoom
                    // or adding all
                    if (((roomMembers.count == 2) && (self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceOneToOne)) || (self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll))
                    {
                        NSString* myUserId = room.mxSession.myUser.userId;
                        
                        for (MXRoomMember* member in roomMembers)
                        {
                            if ([member.userId isEqualToString:myUserId])
                            {
                                [self updateMatrixContactWithID:member.userId];
                            }
                        }
                    }
                }
            }];
        }
        
        // Update all matrix contacts as soon as matrix session is ready
        if (!mxSessionStateObserver) {
            mxSessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                
                MXSession *mxSession = notif.object;
                
                if ([mxSessionArray indexOfObject:mxSession] != NSNotFound)
                {
                    if ((mxSession.state == MXSessionStateStoreDataReady) || (mxSession.state == MXSessionStateRunning)) {
                        [self refreshMatrixContacts];
                    }
                }
            }];
        }
        [self refreshMatrixContacts];
    }
    
    if (shouldUpdateLocalContactsMatrixIDs)
    {
        [self updateMatrixIDsForAllLocalContacts];
    }
}

- (void)removeMatrixSession:(MXSession*)mxSession
{
    if (!mxSession)
    {
        return;
    }
    
    NSUInteger index = [mxSessionArray indexOfObject:mxSession];
    if (index != NSNotFound)
    {
        id eventListener = [mxEventListeners objectAtIndex:index];
        [mxSession removeListener:eventListener];
        
        [mxEventListeners removeObjectAtIndex:index];
        [mxSessionArray removeObjectAtIndex:index];
        
        // Reset the current rest client (It will be rebuild if need)
        _identityRESTClient = nil;
        
        // Reset history of 3PID lookup requests
        pending3PIDs = nil;
        checked3PIDs = nil;
        
        if (!mxSessionArray.count) {
            if (mxSessionStateObserver) {
                [[NSNotificationCenter defaultCenter] removeObserver:mxSessionStateObserver];
                mxSessionStateObserver = nil;
            }
            
            if (mxSessionNewSyncedRoomObserver) {
                [[NSNotificationCenter defaultCenter] removeObserver:mxSessionNewSyncedRoomObserver];
                mxSessionNewSyncedRoomObserver = nil;
            }
        }
        
        // Update matrix contacts list
        [self refreshMatrixContacts];
    }
}

- (NSArray*)mxSessions
{
    return [NSArray arrayWithArray:mxSessionArray];
}


- (NSArray*)matrixContacts
{
    return [matrixContactByContactID allValues];
}

- (NSArray*)localContacts
{
    // Return nil if the loading step is in progress.
    if (isLocalContactListLoading)
    {
        return nil;
    }
    
    return [localContactByContactID allValues];
}

- (NSArray*)localEmailContacts
{
    // Return nil if the loading step is in progress.
    if (isLocalContactListLoading)
    {
        return nil;
    }
    
    // Check whether the array must be prepared
    if (!localEmailContacts)
    {
        // List all the known emails from the local contacts
        NSArray *localContacts = self.localContacts;
        NSMutableArray *emailAddresses = [NSMutableArray arrayWithCapacity:localContacts.count];
        
        for (MXKContact* contact in localContacts)
        {
            NSArray *emails = contact.emailAddresses;
            for (MXKEmail *email in emails)
            {
                if (email.emailAddress.length)
                {
                    if ([emailAddresses indexOfObject:email.emailAddress] == NSNotFound)
                    {
                        [emailAddresses addObject:email.emailAddress];
                    }
                }
            }
        }
        
        if (emailAddresses.count)
        {
            // Create here the local email contacts array
            localEmailContacts = [NSMutableArray arrayWithCapacity:localContacts.count];
            
            for (NSString *emailAddress in emailAddresses)
            {
                MXKContact *contact = [[MXKContact alloc] initMatrixContactWithDisplayName:emailAddress andMatrixID:nil];
                [localEmailContacts addObject:contact];
            }
        }
    }
    
    return localEmailContacts;
}

- (void)setIdentityServer:(NSString *)identityServer
{
    _identityServer = identityServer;
    
    if (identityServer)
    {
        _identityRESTClient = [[MXRestClient alloc] initWithHomeServer:nil andOnUnrecognizedCertificateBlock:nil];
        _identityRESTClient.identityServer = identityServer;
        
        if (self.enableFullMatrixIdSyncOnLocalContactsDidLoad) {
            [self updateMatrixIDsForAllLocalContacts];
        }
    }
    else
    {
        _identityRESTClient = nil;
    }
    
    // Reset history of 3PID lookup requests
    pending3PIDs = nil;
    checked3PIDs = nil;
}

- (MXRestClient*)identityRESTClient
{
    if (!_identityRESTClient)
    {
        if (self.identityServer)
        {
            _identityRESTClient = [[MXRestClient alloc] initWithHomeServer:nil andOnUnrecognizedCertificateBlock:nil];
            _identityRESTClient.identityServer = self.identityServer;
        }
        else if (mxSessionArray.count)
        {
            MXSession *mxSession = [mxSessionArray firstObject];
            _identityRESTClient = [[MXRestClient alloc] initWithHomeServer:nil andOnUnrecognizedCertificateBlock:nil];
            _identityRESTClient.identityServer = mxSession.matrixRestClient.identityServer;
        }
    }
    
    return _identityRESTClient;
}

#pragma mark -

- (void)loadLocalContacts
{
    // Check if the user allowed to sync local contacts
    if (![[MXKAppSettings standardAppSettings] syncLocalContacts])
    {
        // Local contacts list is empty if the user did not allow to sync local contacts
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
        return;
    }
    
    // Check if the application is allowed to list the contacts
    ABAuthorizationStatus cbStatus = ABAddressBookGetAuthorizationStatus();
    if (cbStatus == kABAuthorizationStatusNotDetermined)
    {
        // request address book access
        ABAddressBookRef ab = ABAddressBookCreateWithOptions(nil, nil);
        
        if (ab)
        {
            ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self loadLocalContacts];
                });
                
            });
            
            CFRelease(ab);
        }
        
        return;
    }
    
    isLocalContactListLoading = YES;
    
    // Reset history of 3PID lookup requests
    pending3PIDs = nil;
    checked3PIDs = nil;
    
    // cold start
    // launch the dict from the file system
    // It is cached to improve UX.
    if (!matrixIDBy3PID)
    {
        [self loadCachedMatrixIDsDict];
    }
    
    dispatch_async(processingQueue, ^{
        
        // in case of cold start
        // get the info from the file system
        if (!lastSyncDate)
        {
            // load cached contacts
            [self loadCachedLocalContacts];
            [self loadCachedContactBookInfo];
            
            // no local contact -> assume that the last sync date is useless
            if (localContactByContactID.count == 0)
            {
                lastSyncDate = nil;
            }
        }
        
        BOOL contactBookUpdate = NO;
        
        NSMutableArray* deletedContactIDs = [NSMutableArray arrayWithArray:[localContactByContactID allKeys]];
        
        // can list local contacts?
        if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
        {
            NSString* countryCode = [[MXKAppSettings standardAppSettings] phonebookCountryCode];
            
            ABAddressBookRef ab = ABAddressBookCreateWithOptions(nil, nil);
            ABRecordRef      contactRecord;
            CFIndex          index;
            CFMutableArrayRef people = (CFMutableArrayRef)ABAddressBookCopyArrayOfAllPeople(ab);
            
            if (nil != people)
            {
                CFIndex peopleCount = CFArrayGetCount(people);
                
                for (index = 0; index < peopleCount; index++)
                {
                    contactRecord = (ABRecordRef)CFArrayGetValueAtIndex(people, index);
                    
                    NSString* contactID = [MXKContact contactID:contactRecord];
                    
                    // the contact still exists
                    [deletedContactIDs removeObject:contactID];
                    
                    if (lastSyncDate)
                    {
                        // ignore unchanged contacts since the previous sync
                        CFDateRef lastModifDate = ABRecordCopyValue(contactRecord, kABPersonModificationDateProperty);
                        if (kCFCompareGreaterThan != CFDateCompare (lastModifDate, (__bridge CFDateRef)lastSyncDate, nil))
                            
                        {
                            CFRelease(lastModifDate);
                            continue;
                        }
                        CFRelease(lastModifDate);
                    }
                    
                    contactBookUpdate = YES;
                    
                    MXKContact* contact = [[MXKContact alloc] initLocalContactWithABRecord:contactRecord];
                    
                    if (countryCode)
                    {
                        [contact internationalizePhonenumbers:countryCode];
                    }
                    
                    // update the local contacts list
                    [localContactByContactID setValue:contact forKey:contactID];
                }
                
                CFRelease(people);
            }
            
            if (ab)
            {
                CFRelease(ab);
            }
        }
        
        // some contacts have been deleted
        for (NSString* contactID in deletedContactIDs)
        {
            contactBookUpdate = YES;
            [localContactByContactID removeObjectForKey:contactID];
        }
        
        // something has been modified in the local contact book
        if (contactBookUpdate)
        {
            // Remove the local email contacts (This array will be prepared only if need)
            localEmailContacts = nil;
            
            [self cacheLocalContacts];
        }
        
        lastSyncDate = [NSDate date];
        [self cacheContactBookInfo];
        
        // Update loaded contacts with the known dict 3PID -> matrix ID
        [self updateAllLocalContactsMatrixIDs];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Contacts are loaded, post a notification
            isLocalContactListLoading = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
            
            if (self.enableFullMatrixIdSyncOnLocalContactsDidLoad) {
                [self updateMatrixIDsForAllLocalContacts];
            }
        });
    });
}

- (void)updateMatrixIDsForLocalContact:(MXKContact *)contact
{
    if (!contact.isMatrixContact && self.identityRESTClient)
    {
        if (!pending3PIDs)
        {
            pending3PIDs = [[NSMutableArray alloc] init];
            checked3PIDs = [[NSMutableArray alloc] init];
        }
        
        // Retrieve all 3PIDs of the contact by checking pending requests
        NSMutableArray* pids = [[NSMutableArray alloc] init];
        NSMutableArray* medias = [[NSMutableArray alloc] init];
        for(MXKEmail* email in contact.emailAddresses)
        {
            if (([pending3PIDs indexOfObject:email.emailAddress] == NSNotFound) && ([checked3PIDs indexOfObject:email.emailAddress] == NSNotFound))
            {
                [pids addObject:email.emailAddress];
                [medias addObject:@"email"];
            }
        }
        
        if (pids.count > 0)
        {
            [pending3PIDs addObjectsFromArray:pids];
            
            [self.identityRESTClient lookup3pids:pids
                                        forMedia:medias
                                         success:^(NSArray *userIds) {
                                             // sanity check
                                             if (userIds.count == pids.count)
                                             {
                                                 // Update status table
                                                 [checked3PIDs addObjectsFromArray:pids];
                                                 for(NSString* pid in pids)
                                                 {
                                                     [pending3PIDs removeObject:pid];
                                                 }
                                                 
                                                 // Look for updates
                                                 BOOL isUpdated = NO;
                                                 for (int index = 0; index < pids.count; index++)
                                                 {
                                                     id matrixID = [userIds objectAtIndex:index];
                                                     NSString* pid = [pids objectAtIndex:index];
                                                     NSString *currentMatrixID = [matrixIDBy3PID valueForKey:pid];
                                                     
                                                     if ([matrixID isEqual:[NSNull null]])
                                                     {
                                                         if (currentMatrixID)
                                                         {
                                                             [matrixIDBy3PID removeObjectForKey:pid];
                                                             isUpdated = YES;
                                                         }
                                                     }
                                                     else if ([matrixID isKindOfClass:[NSString class]])
                                                     {
                                                         if (![currentMatrixID isEqualToString:matrixID])
                                                         {
                                                             [matrixIDBy3PID setValue:matrixID forKey:pid];
                                                             isUpdated = YES;
                                                         }
                                                     }
                                                 }
                                                 
                                                 if (isUpdated)
                                                 {
                                                     [self cacheMatrixIDsDict];
                                                 }
                                                 
                                                 // Update only this contact
                                                 [self updateLocalContactMatrixIDs:contact];
                                                 
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:contact.contactID userInfo:nil];
                                                 });
                                             }
                                         }
                                         failure:^(NSError *error) {
                                             NSLog(@"[MXKContactManager] lookup3pids failed %@", error);
                                             
                                             // try later
                                             dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                                 [self updateMatrixIDsForLocalContact:contact];
                                             });
                                         }];
        }
    }
}


- (void)updateMatrixIDsForAllLocalContacts
{
    // Check if at least an identity server is available, and if the loading step is not in progress
    if (!self.identityRESTClient || isLocalContactListLoading)
    {
        return;
    }
    
    // Refresh the 3PIDs -> Matrix ID mapping
    dispatch_async(processingQueue, ^{
        
        NSArray* contactsSnapshot = [localContactByContactID allValues];
        
        // Retrieve all 3PIDs
        NSMutableArray* pids = [[NSMutableArray alloc] init];
        NSMutableArray* medias = [[NSMutableArray alloc] init];
        for(MXKContact* contact in contactsSnapshot)
        {
            // the phonenumbers are not managed
            /*for(MXKPhoneNumber* pn in contact.phoneNumbers)
             {
             if (pn.textNumber.length > 0)
             {
             
             // not yet added
             if ([pids indexOfObject:pn.textNumber] == NSNotFound)
             {
             [pids addObject:pn.textNumber];
             [medias addObject:@"msisdn"];
             }
             }
             }*/
            
            for(MXKEmail* email in contact.emailAddresses)
            {
                if (email.emailAddress.length > 0)
                {
                    // not yet added
                    if ([pids indexOfObject:email.emailAddress] == NSNotFound)
                    {
                        [pids addObject:email.emailAddress];
                        [medias addObject:@"email"];
                    }
                }
            }
        }
        
        // Update 3PIDs mapping
        if (pids.count > 0)
        {
            [self.identityRESTClient lookup3pids:pids
                                        forMedia:medias
                                         success:^(NSArray *userIds) {
                                             // Sanity check
                                             if (userIds.count == pids.count)
                                             {
                                                 matrixIDBy3PID = [[NSMutableDictionary alloc] initWithObjects:userIds forKeys:pids];
                                                 [self cacheMatrixIDsDict];
                                                 [self updateAllLocalContactsMatrixIDs];
                                                 
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactMatrixIDsNotification object:nil userInfo:nil];
                                                 });
                                             }
                                         }
                                         failure:^(NSError *error) {
                                             NSLog(@"[MXKContactManager] lookup3pids failed %@", error);
                                             
                                             // try later
                                             dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                                 [self updateMatrixIDsForAllLocalContacts];
                                             });
                                         }];
        }
        else
        {
            matrixIDBy3PID = nil;
            [self cacheMatrixIDsDict];
        }
    });
}

- (void)reset
{
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionStateDidChangeNotification object:nil];
    
    matrixIDBy3PID = nil;
    [self cacheMatrixIDsDict];
    
    isLocalContactListLoading = NO;
    localContactByContactID = nil;
    localEmailContacts = nil;
    [self cacheLocalContacts];
    
    matrixContactByContactID = nil;
    matrixContactByMatrixID = nil;
    [self cacheMatrixContacts];
    
    lastSyncDate = nil;
    [self cacheContactBookInfo];
    
    while (mxSessionArray.count) {
        [self removeMatrixSession:mxSessionArray.lastObject];
    }
    mxSessionArray = nil;
    mxEventListeners = nil;
    _identityServer = nil;
    _identityRESTClient = nil;
    
    pending3PIDs = nil;
    checked3PIDs = nil;
    
    // warn of the contacts list update
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateLocalContactsNotification object:nil userInfo:nil];
}

- (MXKContact*)contactWithContactID:(NSString*)contactID
{
    if ([contactID hasPrefix:kMXKContactLocalContactPrefixId])
    {
        return [localContactByContactID objectForKey:contactID];
    }
    else
    {
        return [matrixContactByContactID objectForKey:contactID];
    }
}

// refresh the international phonenumber of the contacts
- (void)internationalizePhoneNumbers:(NSString*)countryCode
{
    dispatch_async(processingQueue, ^{
        NSArray* contactsSnapshot = [localContactByContactID allValues];
        
        for(MXKContact* contact in contactsSnapshot)
        {
            [contact internationalizePhonenumbers:countryCode];
        }
        
        [self cacheLocalContacts];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidInternationalizeNotification object:nil userInfo:nil];
        });
    });
}

- (MXKSectionedContacts *)getSectionedContacts:(NSArray*)contactsList
{
    if (!contactsList.count)
    {
        return nil;
    }
    
    UILocalizedIndexedCollation *collation = [UILocalizedIndexedCollation currentCollation];
    
    int indexOffset = 0;
    
    NSInteger index, sectionTitlesCount = [[collation sectionTitles] count];
    NSMutableArray *tmpSectionsArray = [[NSMutableArray alloc] initWithCapacity:(sectionTitlesCount)];
    
    sectionTitlesCount += indexOffset;
    
    for (index = 0; index < sectionTitlesCount; index++)
    {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        [tmpSectionsArray addObject:array];
    }
    
    int contactsCount = 0;
    
    for (MXKContact *aContact in contactsList)
    {
        NSInteger section = [collation sectionForObject:aContact collationStringSelector:@selector(displayName)] + indexOffset;
        
        [[tmpSectionsArray objectAtIndex:section] addObject:aContact];
        ++contactsCount;
    }
    
    NSMutableArray *tmpSectionedContactsTitle = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
    NSMutableArray *shortSectionsArray = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
    
    for (index = indexOffset; index < sectionTitlesCount; index++)
    {
        NSMutableArray *usersArrayForSection = [tmpSectionsArray objectAtIndex:index];
        
        if ([usersArrayForSection count] != 0)
        {
            NSArray* sortedUsersArrayForSection = [collation sortedArrayFromArray:usersArrayForSection collationStringSelector:@selector(displayName)];
            [shortSectionsArray addObject:sortedUsersArrayForSection];
            [tmpSectionedContactsTitle addObject:[[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:(index - indexOffset)]];
        }
    }
    
    return [[MXKSectionedContacts alloc] initWithContacts:shortSectionsArray andTitles:tmpSectionedContactsTitle andCount:contactsCount];
}

#pragma mark - Internals

- (void)refreshMatrixContacts
{
    NSArray *mxSessions = self.mxSessions;
    
    // Check whether at least one session is available
    if (!mxSessions.count)
    {
        matrixContactByMatrixID = nil;
        matrixContactByContactID = nil;
        [self cacheMatrixContacts];
    }
    else  if (self.contactManagerMXRoomSource != MXKContactManagerMXRoomSourceNone)
    {
        if (!matrixContactByContactID)
        {
            [self loadCachedMatrixContacts];
        }
    
        // The existing dictionary of contacts will be replaced by this one
        NSMutableDictionary *updatedMatrixContactByMatrixID = [[NSMutableDictionary alloc] initWithCapacity:matrixContactByMatrixID.count];
        for (MXSession *mxSession in mxSessions)
        {
            // Check for all users if a one-to-one room exist
            NSArray *mxUsers = mxSession.users;

            for (MXUser *user in mxUsers)
            {
                // Check whether this user has already been added
                if (![updatedMatrixContactByMatrixID objectForKey:user.userId])
                {
                    if ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll) || ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceOneToOne) && [mxSession privateOneToOneRoomWithUserId:user.userId]))
                    {
                        // Check whether a contact is already defined for this id in previous dictionary
                        // (avoid delete and create the same ones, it could save thumbnail downloads).
                        MXKContact* contact = [matrixContactByMatrixID objectForKey:user.userId];
                        if (contact)
                        {
                            contact.displayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                        }
                        else
                        {
                            contact = [[MXKContact alloc] initMatrixContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andMatrixID:user.userId];
                        }
                        
                        [updatedMatrixContactByMatrixID setValue:contact forKey:user.userId];
                    }
                }
            }
        }
        
        // Update the matrix contacts list
        matrixContactByMatrixID = updatedMatrixContactByMatrixID;
        [matrixContactByContactID removeAllObjects];
        for (MXKContact *contact in matrixContactByMatrixID.allValues)
        {
            [matrixContactByContactID setValue:contact forKey:contact.contactID];
        }
        
        [self cacheMatrixContacts];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
}

- (void)updateMatrixContactWithID:(NSString*)matrixId
{
    // Check if a one-to-one room exist for this matrix user in at least one matrix session.
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        if ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceAll) || ((self.contactManagerMXRoomSource == MXKContactManagerMXRoomSourceOneToOne) && [mxSession privateOneToOneRoomWithUserId:matrixId]))
        {
            // Retrieve the user object related to this contact
            MXUser* user = [mxSession userWithUserId:matrixId];
            
            // This user may not exist (if the oneToOne room is a pending invitation to him).
            if (user)
            {
                // Update or create a contact for this user
                MXKContact* contact = [matrixContactByMatrixID objectForKey:matrixId];
                
                // already defined
                if (contact)
                {
                    NSString *userDisplayName = (user.displayname.length > 0) ? user.displayname : user.userId;
                    if (![contact.displayName isEqualToString:userDisplayName])
                    {
                        contact.displayName = userDisplayName;
                        
                        [self cacheMatrixContacts];
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
                    }
                }
                else
                {
                    contact = [[MXKContact alloc] initMatrixContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andMatrixID:user.userId];
                    [matrixContactByMatrixID setValue:contact forKey:matrixId];
                    
                    // update the matrix contacts list
                    [matrixContactByContactID setValue:contact forKey:contact.contactID];
                    
                    [self cacheMatrixContacts];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
                }
                
                // Done
                return;
            }
        }
    }
    
    // Here no one-to-one room exist, remove the contact if any
    MXKContact* contact = [matrixContactByMatrixID objectForKey:matrixId];
    if (contact)
    {
        [matrixContactByContactID removeObjectForKey:contact.contactID];
        [matrixContactByMatrixID removeObjectForKey:matrixId];
        
        [self cacheMatrixContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKContactManagerDidUpdateMatrixContactsNotification object:nil userInfo:nil];
    }
}

- (void)updateLocalContactMatrixIDs:(MXKContact*) contact
{
    // the phonenumbers wil be managed later
    /*for(MXKPhoneNumber* pn in contact.phoneNumbers)
     {
     if (pn.textNumber.length > 0)
     {
     
     // not yet added
     if ([pids indexOfObject:pn.textNumber] == NSNotFound)
     {
     [pids addObject:pn.textNumber];
     [medias addObject:@"msisdn"];
     }
     }
     }*/
    
    for(MXKEmail* email in contact.emailAddresses)
    {
        if (email.emailAddress.length > 0)
        {
            id matrixID = [matrixIDBy3PID valueForKey:email.emailAddress];
            
            if ([matrixID isKindOfClass:[NSString class]])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [email setMatrixID:matrixID];
                });
            }
        }
    }
}

- (void)updateAllLocalContactsMatrixIDs
{
    NSArray* localContacts = [localContactByContactID allValues];
    
    // update the contacts info
    for(MXKContact* contact in localContacts)
    {
        [self updateLocalContactMatrixIDs:contact];
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"syncLocalContacts" isEqualToString:keyPath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadLocalContacts];
        });
    }
    else if ([@"phonebookCountryCode" isEqualToString:keyPath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self internationalizePhoneNumbers:[[MXKAppSettings standardAppSettings] phonebookCountryCode]];
            [self loadLocalContacts];
        });
    }
}

#pragma mark - file caches

static NSString *matrixContactsFile = @"matrixContacts";
static NSString *matrixIDsDictFile = @"matrixIDsDict";
static NSString *localContactsFile = @"localContacts";
static NSString *contactsBookInfoFile = @"contacts";

- (NSString*)dataFilePathForComponent:(NSString*)component
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:component];
}

- (void)cacheMatrixContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixContactsFile];
    
    if (matrixContactByContactID && (matrixContactByContactID.count > 0))
    {
        // Switch on processing queue because matrixContactByContactID dictionary may be huge.
        NSDictionary *matrixContactByContactIDCpy = [matrixContactByContactID copy];
        
        dispatch_async(processingQueue, ^{
            
            NSMutableData *theData = [NSMutableData data];
            NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
            
            [encoder encodeObject:matrixContactByContactIDCpy forKey:@"matrixContactByContactID"];
            
            [encoder finishEncoding];
            
            [theData writeToFile:dataFilePath atomically:YES];
            
        });
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedMatrixContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixContactsFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    __block NSDictionary *matrixContactByContactIDCpy = nil;
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // Use here processing queue because this queue is used during encoding.
        dispatch_sync(processingQueue, ^{
            
            // The file content could be corrupted
            @try
            {
                NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
                
                NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
                
                id object = [decoder decodeObjectForKey:@"matrixContactByContactID"];
                
                if ([object isKindOfClass:[NSDictionary class]])
                {
                    matrixContactByContactIDCpy = object;
                }
                
                [decoder finishDecoding];
            }
            @catch (NSException *exception)
            {
            }
            
        });
        
    }
    
    if (!matrixContactByContactIDCpy)
    {
        matrixContactByContactID = [[NSMutableDictionary alloc] init];
    }
    else
    {
        matrixContactByContactID = [matrixContactByContactIDCpy mutableCopy];
    }
    
    matrixContactByMatrixID = [[NSMutableDictionary alloc] initWithCapacity:matrixContactByContactID.count];
    
    for (MXKContact *contact in matrixContactByContactID.allValues)
    {
        // One and only one matrix id is expected for each listed contact.
        [matrixContactByMatrixID setObject:contact forKey:contact.matrixIdentifiers.firstObject];
    }
}

- (void)cacheMatrixIDsDict
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixIDsDictFile];
    
    if (matrixIDBy3PID)
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:matrixIDBy3PID forKey:@"matrixIDsDict"];
        [encoder finishEncoding];
        
        [theData writeToFile:dataFilePath atomically:YES];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedMatrixIDsDict
{
    NSString *dataFilePath = [self dataFilePathForComponent:matrixIDsDictFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            id object = [decoder decodeObjectForKey:@"matrixIDsDict"];
            
            if ([object isKindOfClass:[NSDictionary class]])
            {
                matrixIDBy3PID = [object mutableCopy];
            }
            
            [decoder finishDecoding];
        }
        @catch (NSException *exception)
        {
        }
    }
    
    if (!matrixIDBy3PID)
    {
        matrixIDBy3PID = [[NSMutableDictionary alloc] init];
    }
}

- (void)cacheLocalContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:localContactsFile];
    
    if (localContactByContactID && (localContactByContactID.count > 0))
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:localContactByContactID forKey:@"localContactByContactID"];
        
        [encoder finishEncoding];
        
        [theData writeToFile:dataFilePath atomically:YES];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedLocalContacts
{
    NSString *dataFilePath = [self dataFilePathForComponent:localContactsFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            id object = [decoder decodeObjectForKey:@"localContactByContactID"];
            
            if ([object isKindOfClass:[NSDictionary class]])
            {
                localContactByContactID = [object mutableCopy];
            }
            
            [decoder finishDecoding];
        } @catch (NSException *exception)
        {
            lastSyncDate = nil;
        }
    }
    
    if (!localContactByContactID)
    {
        localContactByContactID = [[NSMutableDictionary alloc] init];
    }
}

- (void)cacheContactBookInfo
{
    NSString *dataFilePath = [self dataFilePathForComponent:contactsBookInfoFile];
    
    if (lastSyncDate)
    {
        NSMutableData *theData = [NSMutableData data];
        NSKeyedArchiver *encoder = [[NSKeyedArchiver alloc] initForWritingWithMutableData:theData];
        
        [encoder encodeObject:lastSyncDate forKey:@"lastSyncDate"];
        
        [encoder finishEncoding];
        
        [theData writeToFile:dataFilePath atomically:YES];
    }
    else
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        [fileManager removeItemAtPath:dataFilePath error:nil];
    }
}

- (void)loadCachedContactBookInfo
{
    NSString *dataFilePath = [self dataFilePathForComponent:contactsBookInfoFile];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    if ([fileManager fileExistsAtPath:dataFilePath])
    {
        // the file content could be corrupted
        @try
        {
            NSData* filecontent = [NSData dataWithContentsOfFile:dataFilePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
            
            NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:filecontent];
            
            lastSyncDate = [decoder decodeObjectForKey:@"lastSyncDate"];
            
            [decoder finishDecoding];
        } @catch (NSException *exception)
        {
            lastSyncDate = nil;
        }
    }
}

@end
