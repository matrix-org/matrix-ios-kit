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

#import "MXKAppSettings.h"

#import "MXKTools.h"


// get ISO country name
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

static MXKAppSettings *standardAppSettings = nil;

@implementation MXKAppSettings
@synthesize showAllEventsInRoomHistory, showRedactionsInRoomHistory, showUnsupportedEventsInRoomHistory, httpLinkScheme, httpsLinkScheme;
@synthesize showLeftMembersInRoomMemberList, sortRoomMembersUsingLastSeenTime;
@synthesize syncLocalContacts, syncLocalContactsPermissionRequested, phonebookCountryCode;
@synthesize presenceColorForOnlineUser, presenceColorForUnavailableUser, presenceColorForOfflineUser;
@synthesize enableCallKit;

+ (MXKAppSettings *)standardAppSettings
{
    @synchronized(self)
    {
        if(standardAppSettings == nil)
        {
            standardAppSettings = [[super allocWithZone:NULL] init];
        }
    }
    return standardAppSettings;
}

#pragma  mark -

-(instancetype)init
{
    if (self = [super init])
    {
        // Use presence to sort room members by default
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"sortRoomMembersUsingLastSeenTime"])
        {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"sortRoomMembersUsingLastSeenTime"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        sortRoomMembersUsingLastSeenTime = YES;
        
        presenceColorForOnlineUser = [UIColor greenColor];
        presenceColorForUnavailableUser = [UIColor yellowColor];
        presenceColorForOfflineUser = [UIColor redColor];

        httpLinkScheme = @"http";
        httpsLinkScheme = @"https";
        
        enableCallKit = YES;
    }
    return self;
}

- (void)dealloc
{
}

- (void)reset
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        // Flush shared user defaults
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showAllEventsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showRedactionsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showUnsupportedEventsInRoomHistory"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"sortRoomMembersUsingLastSeenTime"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"showLeftMembersInRoomMemberList"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"syncLocalContactsPermissionRequested"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"syncLocalContacts"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"phonebookCountryCode"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOnlineUser"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForUnavailableUser"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOfflineUser"];

        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"httpLinkScheme"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"httpsLinkScheme"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"enableCallKit"];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        showAllEventsInRoomHistory = NO;
        showRedactionsInRoomHistory = NO;
        showUnsupportedEventsInRoomHistory = NO;
        
        sortRoomMembersUsingLastSeenTime = YES;
        showLeftMembersInRoomMemberList = NO;
        
        syncLocalContactsPermissionRequested = NO;
        syncLocalContacts = NO;
        phonebookCountryCode = nil;
        
        presenceColorForOnlineUser = [UIColor greenColor];
        presenceColorForUnavailableUser = [UIColor yellowColor];
        presenceColorForOfflineUser = [UIColor redColor];

        httpLinkScheme = @"http";
        httpsLinkScheme = @"https";
        
        enableCallKit = YES;
    }
}

#pragma mark - Room display

- (BOOL)showAllEventsInRoomHistory
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showAllEventsInRoomHistory"];
    }
    else
    {
        return showAllEventsInRoomHistory;
    }
}

- (void)setShowAllEventsInRoomHistory:(BOOL)boolValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showAllEventsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        showAllEventsInRoomHistory = boolValue;
    }
}

- (NSArray *)eventsFilterForMessages
{
    if (showAllEventsInRoomHistory)
    {
        // Consider all the event types
        return self.allEventTypesForMessages;
    }
    else
    {
        // Display only a subset of events
        return @[
                 kMXEventTypeStringRoomName,
                 kMXEventTypeStringRoomTopic,
                 kMXEventTypeStringRoomMember,
                 kMXEventTypeStringRoomEncrypted,
                 kMXEventTypeStringRoomEncryption,
                 kMXEventTypeStringRoomHistoryVisibility,
                 kMXEventTypeStringRoomMessage,
                 kMXEventTypeStringRoomThirdPartyInvite,
                 kMXEventTypeStringCallInvite,
                 kMXEventTypeStringCallAnswer,
                 kMXEventTypeStringCallHangup
                 ];
    }
}

- (NSArray *)allEventTypesForMessages
{
    // List all the event types, except kMXEventTypeStringPresence which are not related to a specific room.
    return @[
             kMXEventTypeStringRoomName,
             kMXEventTypeStringRoomTopic,
             kMXEventTypeStringRoomMember,
             kMXEventTypeStringRoomCreate,
             kMXEventTypeStringRoomEncrypted,
             kMXEventTypeStringRoomEncryption,
             kMXEventTypeStringRoomJoinRules,
             kMXEventTypeStringRoomPowerLevels,
             kMXEventTypeStringRoomAliases,
             kMXEventTypeStringRoomHistoryVisibility,
             kMXEventTypeStringRoomMessage,
             kMXEventTypeStringRoomMessageFeedback,
             kMXEventTypeStringRoomRedaction,
             kMXEventTypeStringRoomThirdPartyInvite,
             kMXEventTypeStringCallInvite,
             kMXEventTypeStringCallAnswer,
             kMXEventTypeStringCallHangup
             ];
}

- (BOOL)showRedactionsInRoomHistory
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showRedactionsInRoomHistory"];
    }
    else
    {
        return showRedactionsInRoomHistory;
    }
}

- (void)setShowRedactionsInRoomHistory:(BOOL)boolValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showRedactionsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        showRedactionsInRoomHistory = boolValue;
    }
}

- (BOOL)showUnsupportedEventsInRoomHistory
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showUnsupportedEventsInRoomHistory"];
    }
    else
    {
        return showUnsupportedEventsInRoomHistory;
    }
}

- (void)setShowUnsupportedEventsInRoomHistory:(BOOL)boolValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showUnsupportedEventsInRoomHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        showUnsupportedEventsInRoomHistory = boolValue;
    }
}

- (NSString *)httpLinkScheme
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        NSString *ret = [[NSUserDefaults standardUserDefaults] stringForKey:@"httpLinkScheme"];
        if (ret == nil) {
            ret = @"http";
        }
        return ret;
    }
    else
    {
        return httpLinkScheme;
    }
}

- (void)setHttpLinkScheme:(NSString *)stringValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setObject:stringValue forKey:@"httpLinkScheme"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        httpLinkScheme = stringValue;
    }
}

- (NSString *)httpsLinkScheme
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        NSString *ret = [[NSUserDefaults standardUserDefaults] stringForKey:@"httpsLinkScheme"];
        if (ret == nil) {
            ret = @"https";
        }
        return ret;
    }
    else
    {
        return httpsLinkScheme;
    }
}

- (void)setHttpsLinkScheme:(NSString *)stringValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setObject:stringValue forKey:@"httpsLinkScheme"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        httpsLinkScheme = stringValue;
    }
}

#pragma mark - Room members

- (BOOL)sortRoomMembersUsingLastSeenTime
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"sortRoomMembersUsingLastSeenTime"];
    }
    else
    {
        return sortRoomMembersUsingLastSeenTime;
    }
}

- (void)setSortRoomMembersUsingLastSeenTime:(BOOL)boolValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"sortRoomMembersUsingLastSeenTime"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        sortRoomMembersUsingLastSeenTime = boolValue;
    }
}

- (BOOL)showLeftMembersInRoomMemberList
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"showLeftMembersInRoomMemberList"];
    }
    else
    {
        return showLeftMembersInRoomMemberList;
    }
}

- (void)setShowLeftMembersInRoomMemberList:(BOOL)boolValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"showLeftMembersInRoomMemberList"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        showLeftMembersInRoomMemberList = boolValue;
    }
}

#pragma mark - Contacts

- (BOOL)syncLocalContacts
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"syncLocalContacts"];
    }
    else
    {
        return syncLocalContacts;
    }
}

- (void)setSyncLocalContacts:(BOOL)boolValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:@"syncLocalContacts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        syncLocalContacts = boolValue;
    }
}

- (BOOL)syncLocalContactsPermissionRequested
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"syncLocalContactsPermissionRequested"];
    }
    else
    {
        return syncLocalContactsPermissionRequested;
    }
}

- (void)setSyncLocalContactsPermissionRequested:(BOOL)theSyncLocalContactsPermissionRequested
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:theSyncLocalContactsPermissionRequested forKey:@"syncLocalContactsPermissionRequested"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        syncLocalContactsPermissionRequested = theSyncLocalContactsPermissionRequested;
    }
}

- (NSString*)phonebookCountryCode
{
    NSString* res = phonebookCountryCode;
    
    if (self == [MXKAppSettings standardAppSettings])
    {
        res = [[NSUserDefaults standardUserDefaults] stringForKey:@"phonebookCountryCode"];
    }
    
    // does not exist : try to get the SIM card information
    if (!res)
    {
        // get the current MCC
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [netInfo subscriberCellularProvider];
        
        if (carrier)
        {
            res = [[carrier isoCountryCode] uppercaseString];
            
            if (res)
            {
                [self setPhonebookCountryCode:res];
            }
        }
    }
    
    return res;
}

- (void)setPhonebookCountryCode:(NSString *)stringValue
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setObject:stringValue forKey:@"phonebookCountryCode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        phonebookCountryCode = stringValue;
    }
}

#pragma mark - Matrix users

- (UIColor*)presenceColorForOnlineUser
{
    UIColor *color = presenceColorForOnlineUser;
    
    if (self == [MXKAppSettings standardAppSettings])
    {
        NSNumber *rgbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"presenceColorForOnlineUser"];
        if (rgbValue)
        {
            color = [MXKTools colorWithRGBValue:[rgbValue unsignedIntegerValue]];
        }
        else
        {
            color = [UIColor greenColor];
        }
    }
    
    return color;
}

- (void)setPresenceColorForOnlineUser:(UIColor*)color
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        if (color)
        {
            NSUInteger rgbValue = [MXKTools rgbValueWithColor:color];
            [[NSUserDefaults standardUserDefaults] setInteger:rgbValue forKey:@"presenceColorForOnlineUser"];
        }
        else
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOnlineUser"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        presenceColorForOnlineUser = color ? color : [UIColor greenColor];
    }
}

- (UIColor*)presenceColorForUnavailableUser
{
    UIColor *color = presenceColorForUnavailableUser;
    
    if (self == [MXKAppSettings standardAppSettings])
    {
        NSNumber *rgbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"presenceColorForUnavailableUser"];
        if (rgbValue)
        {
            color = [MXKTools colorWithRGBValue:[rgbValue unsignedIntegerValue]];
        }
        else
        {
            color = [UIColor yellowColor];
        }
    }
    
    return color;
}

- (void)setPresenceColorForUnavailableUser:(UIColor*)color
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        if (color)
        {
            NSUInteger rgbValue = [MXKTools rgbValueWithColor:color];
            [[NSUserDefaults standardUserDefaults] setInteger:rgbValue forKey:@"presenceColorForUnavailableUser"];
        }
        else
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForUnavailableUser"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        presenceColorForUnavailableUser = color ? color : [UIColor yellowColor];
    }
}

- (UIColor*)presenceColorForOfflineUser
{
    UIColor *color = presenceColorForOfflineUser;
    
    if (self == [MXKAppSettings standardAppSettings])
    {
        NSNumber *rgbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"presenceColorForOfflineUser"];
        if (rgbValue)
        {
            color = [MXKTools colorWithRGBValue:[rgbValue unsignedIntegerValue]];
        }
        else
        {
            color = [UIColor redColor];
        }
    }
    
    return color;
}

- (void)setPresenceColorForOfflineUser:(UIColor *)color
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        if (color)
        {
            NSUInteger rgbValue = [MXKTools rgbValueWithColor:color];
            [[NSUserDefaults standardUserDefaults] setInteger:rgbValue forKey:@"presenceColorForOfflineUser"];
        }
        else
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"presenceColorForOfflineUser"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        presenceColorForOfflineUser = color ? color : [UIColor redColor];
    }
}

#pragma mark - Calls

- (BOOL)isCallKitEnabled
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"enableCallKit"];
        if (storedValue)
        {
            return [(NSNumber *)storedValue boolValue];
        }
        else
        {
            return YES;
        }
    }
    else
    {
        return enableCallKit;
    }
}

- (void)setEnableCallKit:(BOOL)enable
{
    if (self == [MXKAppSettings standardAppSettings])
    {
        [[NSUserDefaults standardUserDefaults] setBool:enable forKey:@"enableCallKit"];
    }
    else
    {
        enableCallKit = enable;
    }
}

@end
