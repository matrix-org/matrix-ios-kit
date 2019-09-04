/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd

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

#import "MXKEventFormatter.h"

#import "MXEvent+MatrixKit.h"
#import "NSBundle+MatrixKit.h"

#import "MXRoomSummaryUpdater.h"
#import "MXKRoomNameStringLocalizations.h"

#import "MXKTools.h"
#import "MXRoom+Sync.h"

#import "DTCoreText.h"
#import "cmark.h"

#import "MXDecryptionResult.h"

@interface MXKEventFormatter ()
{
    /**
     The default room summary updater from the MXSession.
     */
    MXRoomSummaryUpdater *defaultRoomSummaryUpdater;

    /**
     The default CSS converted in DTCoreText object.
     */
    DTCSSStylesheet *dtCSS;

    /**
     Links detector in strings.
     */
    NSDataDetector *linkDetector;
}
@end

@implementation MXKEventFormatter

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    self = [super init];
    if (self)
    {
        mxSession = matrixSession;

        [self initDateTimeFormatters];

        // Use the same list as matrix-react-sdk ( https://github.com/matrix-org/matrix-react-sdk/blob/24223ae2b69debb33fa22fcda5aeba6fa93c93eb/src/HtmlUtils.js#L25 )
        _allowedHTMLTags = @[
                             @"font", // custom to matrix for IRC-style font coloring
                             @"del", // for markdown
                             // deliberately no h1/h2 to stop people shouting.
                             @"h3", @"h4", @"h5", @"h6", @"blockquote", @"p", @"a", @"ul", @"ol",
                             @"nl", @"li", @"b", @"i", @"u", @"strong", @"em", @"strike", @"code", @"hr", @"br", @"div",
                             @"table", @"thead", @"caption", @"tbody", @"tr", @"th", @"td", @"pre"
                             ];

        self.defaultCSS = @" \
            pre,code { \
                background-color: #eeeeee; \
                display: inline; \
                font-family: monospace; \
                white-space: pre; \
                -coretext-fontname: Menlo-Regular; \
                font-size: small; \
            }";

        // Set default colors
        _defaultTextColor = [UIColor blackColor];
        _subTitleTextColor = [UIColor blackColor];
        _prefixTextColor = [UIColor blackColor];
        _bingTextColor = [UIColor blueColor];
        _encryptingTextColor = [UIColor lightGrayColor];
        _sendingTextColor = [UIColor lightGrayColor];
        _errorTextColor = [UIColor redColor];
        _htmlBlockquoteBorderColor = [MXKTools colorWithRGBValue:0xDDDDDD];
        
        _defaultTextFont = [UIFont systemFontOfSize:14];
        _prefixTextFont = [UIFont systemFontOfSize:14];
        _bingTextFont = [UIFont systemFontOfSize:14];
        _stateEventTextFont = [UIFont italicSystemFontOfSize:14];
        _callNoticesTextFont = [UIFont italicSystemFontOfSize:14];
        _encryptedMessagesTextFont = [UIFont italicSystemFontOfSize:14];
        
        _eventTypesFilterForMessages = nil;

        // Consider the shared app settings by default
        _settings = [MXKAppSettings standardAppSettings];

        defaultRoomSummaryUpdater = [MXRoomSummaryUpdater roomSummaryUpdaterForSession:matrixSession];
        defaultRoomSummaryUpdater.ignoreMemberProfileChanges = YES;
        defaultRoomSummaryUpdater.ignoreRedactedEvent = !_settings.showRedactionsInRoomHistory;
        defaultRoomSummaryUpdater.roomNameStringLocalizations = [MXKRoomNameStringLocalizations new];

        linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    }
    return self;
}

- (void)initDateTimeFormatters
{
    // Prepare internal date formatter
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0]]];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    // Set default date format
    [dateFormatter setDateFormat:@"MMM dd"];
    
    // Create a time formatter to get time string by considered the current system time formatting.
    timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [timeFormatter setTimeStyle:NSDateFormatterShortStyle];
}

- (void)setEventTypesFilterForMessages:(NSArray<NSString *> *)eventTypesFilterForMessages
{
    _eventTypesFilterForMessages = eventTypesFilterForMessages;
    
    defaultRoomSummaryUpdater.eventsFilterForMessages = eventTypesFilterForMessages;
}

#pragma mark - Event formatter settings

// Checks whether the event is related to an attachment and if it is supported
- (BOOL)isSupportedAttachment:(MXEvent*)event
{
    BOOL isSupportedAttachment = NO;
    
    if (event.eventType == MXEventTypeRoomMessage)
    {
        NSString *msgtype;
        MXJSONModelSetString(msgtype, event.content[@"msgtype"]);
        
        NSString *urlField;
        NSDictionary *fileField;
        MXJSONModelSetString(urlField, event.content[@"url"]);
        MXJSONModelSetDictionary(fileField, event.content[@"file"]);
        
        BOOL hasUrl = urlField.length;
        BOOL hasFile = NO;
        
        if (fileField)
        {
            NSString *fileUrlField;
            MXJSONModelSetString(fileUrlField, fileField[@"url"]);
            NSString *fileIvField;
            MXJSONModelSetString(fileIvField, fileField[@"iv"]);
            NSDictionary *fileHashesField;
            MXJSONModelSetDictionary(fileHashesField, fileField[@"hashes"]);
            NSDictionary *fileKeyField;
            MXJSONModelSetDictionary(fileKeyField, fileField[@"key"]);
            
            hasFile = fileUrlField.length && fileIvField.length && fileHashesField && fileKeyField;
        }
        
        if ([msgtype isEqualToString:kMXMessageTypeImage])
        {
            isSupportedAttachment = hasUrl || hasFile;
        }
        else if ([msgtype isEqualToString:kMXMessageTypeAudio])
        {
            isSupportedAttachment = hasUrl || hasFile;
        }
        else if ([msgtype isEqualToString:kMXMessageTypeVideo])
        {
            isSupportedAttachment = hasUrl || hasFile;
        }
        else if ([msgtype isEqualToString:kMXMessageTypeLocation])
        {
            // Not supported yet
        }
        else if ([msgtype isEqualToString:kMXMessageTypeFile])
        {
            isSupportedAttachment = hasUrl || hasFile;
        }
    }
    else if (event.eventType == MXEventTypeSticker)
    {
        NSString *urlField;
        NSDictionary *fileField;
        MXJSONModelSetString(urlField, event.content[@"url"]);
        MXJSONModelSetDictionary(fileField, event.content[@"file"]);
        
        BOOL hasUrl = urlField.length;
        BOOL hasFile = NO;
        
        // @TODO: Check whether the encrypted sticker uses the same `file dict than other media
        if (fileField)
        {
            NSString *fileUrlField;
            MXJSONModelSetString(fileUrlField, fileField[@"url"]);
            NSString *fileIvField;
            MXJSONModelSetString(fileIvField, fileField[@"iv"]);
            NSDictionary *fileHashesField;
            MXJSONModelSetDictionary(fileHashesField, fileField[@"hashes"]);
            NSDictionary *fileKeyField;
            MXJSONModelSetDictionary(fileKeyField, fileField[@"key"]);
            
            hasFile = fileUrlField.length && fileIvField.length && fileHashesField && fileKeyField;
        }
        
        isSupportedAttachment = hasUrl || hasFile;
    }
    return isSupportedAttachment;
}


#pragma mark event sender info

- (NSString*)senderDisplayNameForEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState
{
    // Consider first the current display name defined in provided room state (Note: this room state is supposed to not take the new event into account)
    NSString *senderDisplayName = [roomState.members memberName:event.sender];
    // Check whether this sender name is updated by the current event (This happens in case of new joined member)
    NSString* membership;
    MXJSONModelSetString(membership, event.content[@"membership"]);
    NSString* displayname;
    MXJSONModelSetString(displayname, event.content[@"displayname"]);
    
    if (membership && [membership isEqualToString:@"join"] && [displayname length])
    {
        // Use the actual display name
        senderDisplayName = displayname;
    }
    return senderDisplayName;
}

- (NSString*)senderAvatarUrlForEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState
{
    // Consider first the avatar url defined in provided room state (Note: this room state is supposed to not take the new event into account)
    NSString *senderAvatarUrl = [roomState.members memberWithUserId:event.sender].avatarUrl;
    
    // Check whether this avatar url is updated by the current event (This happens in case of new joined member)
    NSString* membership;
    MXJSONModelSetString(membership, event.content[@"membership"]);
    NSString* avatarUrl;
    MXJSONModelSetString(avatarUrl, event.content[@"avatar_url"]);
    
    if (membership && [membership isEqualToString:@"join"] && [avatarUrl length])
    {
        // We ignore non mxc avatar url
        if ([avatarUrl hasPrefix:kMXContentUriScheme])
        {
            // Use the actual avatar
            senderAvatarUrl = avatarUrl;
        }
        else
        {
            senderAvatarUrl = nil;
        }
    }
    
    // Handle here the case where no avatar is defined (Check SDK options before using identicon).
    if (!senderAvatarUrl && ![MXSDKOptions sharedInstance].disableIdenticonUseForUserAvatar)
    {
        senderAvatarUrl = [mxSession.mediaManager urlOfIdenticon:event.sender];
    }
    
    return senderAvatarUrl;
}


#pragma mark - Events to strings conversion methods
- (NSString*)stringFromEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState error:(MXKEventFormatterError*)error
{
    NSString *stringFromEvent;
    NSAttributedString *attributedStringFromEvent = [self attributedStringFromEvent:event withRoomState:roomState error:error];
    if (*error == MXKEventFormatterErrorNone)
    {
        stringFromEvent = attributedStringFromEvent.string;
    }

    return stringFromEvent;
}

- (NSAttributedString *)attributedStringFromEvent:(MXEvent *)event withRoomState:(MXRoomState *)roomState error:(MXKEventFormatterError *)error
{
    // Check we can output the error
    NSParameterAssert(error);
    
    *error = MXKEventFormatterErrorNone;
    
    // Filter the events according to their type.
    if (_eventTypesFilterForMessages && ([_eventTypesFilterForMessages indexOfObject:event.type] == NSNotFound))
    {
        // Ignore this event
        return nil;
    }
    
    // Check first whether the event has been redacted
    NSString *redactedInfo = nil;
    BOOL isRedacted = (event.redactedBecause != nil);
    if (isRedacted)
    {
        // Check whether redacted information is required
        if (_settings.showRedactionsInRoomHistory)
        {
            NSLog(@"[MXKEventFormatter] Redacted event %@ (%@)", event.description, event.redactedBecause);
            
            NSString *redactorId = event.redactedBecause[@"sender"];
            NSString *redactedBy = @"";
            // Consider live room state to resolve redactor name if no roomState is provided
            MXRoomState *aRoomState = roomState ? roomState : [mxSession roomWithRoomId:event.roomId].dangerousSyncState;
            redactedBy = [aRoomState.members memberName:redactorId];
            
            NSString *redactedReason = (event.redactedBecause[@"content"])[@"reason"];
            if (redactedReason.length)
            {
                if (redactedBy.length)
                {
                    NSString *formatString = [NSString stringWithFormat:@"%@%@", [NSBundle mxk_localizedStringForKey:@"notice_event_redacted_by"], [NSBundle mxk_localizedStringForKey:@"notice_event_redacted_reason"]];
                    redactedBy = [NSString stringWithFormat:formatString, redactedBy, redactedReason];
                }
                else
                {
                    redactedBy = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_event_redacted_reason"], redactedReason];
                }
            }
            else if (redactedBy.length)
            {
                redactedBy = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_event_redacted_by"], redactedBy];
            }
            
            redactedInfo = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_event_redacted"], redactedBy];
        }
    }
    
    // Prepare returned description
    NSString *displayText = nil;
    NSAttributedString *attributedDisplayText = nil;

    // Prepare the display name of the sender
    NSString *senderDisplayName;
    senderDisplayName = roomState ? [self senderDisplayNameForEvent:event withRoomState:roomState] : event.sender;
    
    switch (event.eventType)
    {
        case MXEventTypeRoomName:
        {
            NSString *roomName;
            MXJSONModelSetString(roomName, event.content[@"name"]);
            
            if (isRedacted)
            {
                if (!redactedInfo)
                {
                    // Here the event is ignored (no display)
                    return nil;
                }
                roomName = redactedInfo;
            }
            
            if (roomName.length)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_name_changed"], senderDisplayName, roomName];
            }
            else
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_name_removed"], senderDisplayName];
            }
            break;
        }
        case MXEventTypeRoomTopic:
        {
            NSString *roomTopic;
            MXJSONModelSetString(roomTopic, event.content[@"topic"]);
            
            if (isRedacted)
            {
                if (!redactedInfo)
                {
                    // Here the event is ignored (no display)
                    return nil;
                }
                roomTopic = redactedInfo;
            }
            
            if (roomTopic.length)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_topic_changed"], senderDisplayName, roomTopic];
            }
            else
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_topic_removed"], senderDisplayName];
            }
            
            break;
        }
        case MXEventTypeRoomMember:
        {
            // Presently only change on membership, display name and avatar are supported
            
            // Check whether the sender has updated his profile
            if (event.isUserProfileChange)
            {
                // Is redacted event?
                if (isRedacted)
                {
                    if (!redactedInfo)
                    {
                        // Here the event is ignored (no display)
                        return nil;
                    }
                    displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_profile_change_redacted"], senderDisplayName, redactedInfo];
                }
                else
                {
                    // Check whether the display name has been changed
                    NSString *displayname;
                    MXJSONModelSetString(displayname, event.content[@"displayname"]);
                    NSString *prevDisplayname;
                    MXJSONModelSetString(prevDisplayname, event.prevContent[@"displayname"]);
                    
                    if (!displayname.length)
                    {
                        displayname = nil;
                    }
                    if (!prevDisplayname.length)
                    {
                        prevDisplayname = nil;
                    }
                    if ((displayname || prevDisplayname) && ([displayname isEqualToString:prevDisplayname] == NO))
                    {
                        if (!prevDisplayname)
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_display_name_set"], event.sender, displayname];
                        }
                        else if (!displayname)
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_display_name_removed"], event.sender];
                        }
                        else
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_display_name_changed_from"], event.sender, prevDisplayname, displayname];
                        }
                    }
                    
                    // Check whether the avatar has been changed
                    NSString *avatar;
                    MXJSONModelSetString(avatar, event.content[@"avatar_url"]);
                    NSString *prevAvatar;
                    MXJSONModelSetString(prevAvatar, event.prevContent[@"avatar_url"]);
                    
                    if (!avatar.length)
                    {
                        avatar = nil;
                    }
                    if (!prevAvatar.length)
                    {
                        prevAvatar = nil;
                    }
                    if ((prevAvatar || avatar) && ([avatar isEqualToString:prevAvatar] == NO))
                    {
                        if (displayText)
                        {
                            displayText = [NSString stringWithFormat:@"%@ %@", displayText, [NSBundle mxk_localizedStringForKey:@"notice_avatar_changed_too"]];
                        }
                        else
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_avatar_url_changed"], senderDisplayName];
                        }
                    }
                }
            }
            else
            {
                // Retrieve membership
                NSString* membership;
                MXJSONModelSetString(membership, event.content[@"membership"]);
                
                // Prepare targeted member display name
                NSString *targetDisplayName = event.stateKey;
                
                // Retrieve content displayname
                NSString *contentDisplayname;
                MXJSONModelSetString(contentDisplayname, event.content[@"displayname"]);
                NSString *prevContentDisplayname;
                MXJSONModelSetString(prevContentDisplayname, event.prevContent[@"displayname"]);
                
                // Consider here a membership change
                if ([membership isEqualToString:@"invite"])
                {
                    if (event.content[@"third_party_invite"])
                    {
                        displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_third_party_registered_invite"], targetDisplayName, event.content[@"third_party_invite"][@"display_name"]];
                    }
                    else
                    {
                        if ([MXCallManager isConferenceUser:event.stateKey])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_conference_call_request"], senderDisplayName];
                        }
                        else
                        {
                            // The targeted member display name (if any) is available in content
                            if (contentDisplayname.length)
                            {
                                targetDisplayName = contentDisplayname;
                            }
                            
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_invite"], senderDisplayName, targetDisplayName];
                        }
                    }
                }
                else if ([membership isEqualToString:@"join"])
                {
                    if ([MXCallManager isConferenceUser:event.stateKey])
                    {
                        displayText = [NSBundle mxk_localizedStringForKey:@"notice_conference_call_started"];
                    }
                    else
                    {
                        // The targeted member display name (if any) is available in content
                        if (contentDisplayname.length)
                        {
                            targetDisplayName = contentDisplayname;
                        }

                        displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_join"], targetDisplayName];
                    }
                }
                else if ([membership isEqualToString:@"leave"])
                {
                    NSString *prevMembership = nil;
                    if (event.prevContent)
                    {
                        MXJSONModelSetString(prevMembership, event.prevContent[@"membership"]);
                    }
                    
                    // The targeted member display name (if any) is available in prevContent
                    if (prevContentDisplayname.length)
                    {
                        targetDisplayName = prevContentDisplayname;
                    }
                    
                    if ([event.sender isEqualToString:event.stateKey])
                    {
                        if ([MXCallManager isConferenceUser:event.stateKey])
                        {
                            displayText = [NSBundle mxk_localizedStringForKey:@"notice_conference_call_finished"];
                        }
                        else
                        {
                            if (prevMembership && [prevMembership isEqualToString:@"invite"])
                            {
                                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_reject"], targetDisplayName];
                            }
                            else
                            {
                               displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_leave"], targetDisplayName];
                            }
                        }
                    }
                    else if (prevMembership)
                    {
                        if ([prevMembership isEqualToString:@"invite"])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_withdraw"], senderDisplayName, targetDisplayName];
                            if (event.content[@"reason"])
                            {
                                displayText = [displayText stringByAppendingString:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_reason"], event.content[@"reason"]]];
                            }

                        }
                        else if ([prevMembership isEqualToString:@"join"])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_kick"], senderDisplayName, targetDisplayName];
                            if (event.content[@"reason"])
                            {
                                displayText = [displayText stringByAppendingString:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_reason"], event.content[@"reason"]]];
                            }
                        }
                        else if ([prevMembership isEqualToString:@"ban"])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_unban"], senderDisplayName, targetDisplayName];
                        }
                    }
                }
                else if ([membership isEqualToString:@"ban"])
                {
                    // The targeted member display name (if any) is available in prevContent
                    if (prevContentDisplayname.length)
                    {
                        targetDisplayName = prevContentDisplayname;
                    }
                    
                    displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_ban"], senderDisplayName, targetDisplayName];
                    if (event.content[@"reason"])
                    {
                        displayText = [displayText stringByAppendingString:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_reason"], event.content[@"reason"]]];
                    }
                }
                
                // Append redacted info if any
                if (redactedInfo)
                {
                    displayText = [NSString stringWithFormat:@"%@ %@", displayText, redactedInfo];
                }
            }
            
            if (!displayText)
            {
                *error = MXKEventFormatterErrorUnexpected;
            }
            break;
        }
        case MXEventTypeRoomCreate:
        {
            NSString *creatorId;
            MXJSONModelSetString(creatorId, event.content[@"creator"]);
            
            if (creatorId)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_created"], (roomState ? [roomState.members memberName:creatorId] : creatorId)];
                // Append redacted info if any
                if (redactedInfo)
                {
                    displayText = [NSString stringWithFormat:@"%@ %@", displayText, redactedInfo];
                }
            }
            break;
        }
        case MXEventTypeRoomJoinRules:
        {
            NSString *joinRule;
            MXJSONModelSetString(joinRule, event.content[@"join_rule"]);
            
            if (joinRule)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_join_rule"], joinRule];
                // Append redacted info if any
                if (redactedInfo)
                {
                    displayText = [NSString stringWithFormat:@"%@ %@", displayText, redactedInfo];
                }
            }
            break;
        }
        case MXEventTypeRoomPowerLevels:
        {
            displayText = [NSBundle mxk_localizedStringForKey:@"notice_room_power_level_intro"];
            NSDictionary *users;
            MXJSONModelSetDictionary(users, event.content[@"users"]);
            
            for (NSString *key in users.allKeys)
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 %@: %@", displayText, key, [users objectForKey:key]];
            }
            if (event.content[@"users_default"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 %@: %@", displayText, [NSBundle mxk_localizedStringForKey:@"default"], event.content[@"users_default"]];
            }
            
            displayText = [NSString stringWithFormat:@"%@\n%@", displayText, [NSBundle mxk_localizedStringForKey:@"notice_room_power_level_acting_requirement"]];
            if (event.content[@"ban"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 ban: %@", displayText, event.content[@"ban"]];
            }
            if (event.content[@"kick"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 kick: %@", displayText, event.content[@"kick"]];
            }
            if (event.content[@"redact"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 redact: %@", displayText, event.content[@"redact"]];
            }
            if (event.content[@"invite"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 invite: %@", displayText, event.content[@"invite"]];
            }
            
            displayText = [NSString stringWithFormat:@"%@\n%@", displayText, [NSBundle mxk_localizedStringForKey:@"notice_room_power_level_event_requirement"]];
            
            NSDictionary *events;
            MXJSONModelSetDictionary(events, event.content[@"events"]);
            for (NSString *key in events.allKeys)
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 %@: %@", displayText, key, [events objectForKey:key]];
            }
            if (event.content[@"events_default"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 %@: %@", displayText, @"events_default", event.content[@"events_default"]];
            }
            if (event.content[@"state_default"])
            {
                displayText = [NSString stringWithFormat:@"%@\n\u2022 %@: %@", displayText, @"state_default", event.content[@"state_default"]];
            }
            
            // Append redacted info if any
            if (redactedInfo)
            {
                displayText = [NSString stringWithFormat:@"%@\n %@", displayText, redactedInfo];
            }
            break;
        }
        case MXEventTypeRoomAliases:
        {
            NSArray *aliases;
            MXJSONModelSetArray(aliases, event.content[@"aliases"]);
            if (aliases)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_aliases"], aliases];
                // Append redacted info if any
                if (redactedInfo)
                {
                    displayText = [NSString stringWithFormat:@"%@\n %@", displayText, redactedInfo];
                }
            }
            break;
        }
        case MXEventTypeRoomRelatedGroups:
        {
            NSArray *groups;
            MXJSONModelSetArray(groups, event.content[@"groups"]);
            if (groups)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_related_groups"], groups];
                // Append redacted info if any
                if (redactedInfo)
                {
                    displayText = [NSString stringWithFormat:@"%@\n %@", displayText, redactedInfo];
                }
            }
            break;
        }
        case MXEventTypeRoomEncrypted:
        {
            // Is redacted?
            if (isRedacted)
            {
                if (!redactedInfo)
                {
                    // Here the event is ignored (no display)
                    return nil;
                }
                displayText = redactedInfo;
            }
            else
            {
                // If the message still appears as encrypted, there was propably an error for decryption
                // Show this error
                if (event.decryptionError)
                {
                    NSString *errorDescription;

                    if ([event.decryptionError.domain isEqualToString:MXDecryptingErrorDomain]
                        && event.decryptionError.code == MXDecryptingErrorUnknownInboundSessionIdCode)
                    {
                        // Make the unknown inbound session id error description more user friendly
                        errorDescription = [NSBundle mxk_localizedStringForKey:@"notice_crypto_error_unknown_inbound_session_id"];
                    }
                    else
                    {
                        errorDescription = event.decryptionError.localizedDescription;
                    }

                    displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_crypto_unable_to_decrypt"], errorDescription];
                }
                else
                {
                    displayText = [NSBundle mxk_localizedStringForKey:@"notice_encrypted_message"];
                }
            }
            
            break;
        }
        case MXEventTypeRoomEncryption:
        {
            NSString *algorithm;
            MXJSONModelSetString(algorithm, event.content[@"algorithm"]);
            
            if (isRedacted)
            {
                if (!redactedInfo)
                {
                    // Here the event is ignored (no display)
                    return nil;
                }
                algorithm = redactedInfo;
            }
            
            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_encryption_enabled"], senderDisplayName, algorithm];
            
            break;
        }
        case MXEventTypeRoomHistoryVisibility:
        {
            if (isRedacted)
            {
                displayText = redactedInfo;
            }
            else
            {
                MXRoomHistoryVisibility historyVisibility;
                MXJSONModelSetString(historyVisibility, event.content[@"history_visibility"]);
                
                if (historyVisibility)
                {
                    NSString *formattedString;
                    
                    if ([historyVisibility isEqualToString:kMXRoomHistoryVisibilityWorldReadable])
                    {
                        formattedString = [NSBundle mxk_localizedStringForKey:@"notice_room_history_visible_to_anyone"];
                    }
                    else if ([historyVisibility isEqualToString:kMXRoomHistoryVisibilityShared])
                    {
                        formattedString = [NSBundle mxk_localizedStringForKey:@"notice_room_history_visible_to_members"];
                    }
                    else if ([historyVisibility isEqualToString:kMXRoomHistoryVisibilityInvited])
                    {
                        formattedString = [NSBundle mxk_localizedStringForKey:@"notice_room_history_visible_to_members_from_invited_point"];
                    }
                    else if ([historyVisibility isEqualToString:kMXRoomHistoryVisibilityJoined])
                    {
                        formattedString = [NSBundle mxk_localizedStringForKey:@"notice_room_history_visible_to_members_from_joined_point"];
                    }
                    
                    if (formattedString)
                    {
                        displayText = [NSString stringWithFormat:formattedString, senderDisplayName];
                    }
                }
            }
            break;
        }
        case MXEventTypeRoomMessage:
        {
            // Is redacted?
            if (isRedacted)
            {
                if (!redactedInfo)
                {
                    // Here the event is ignored (no display)
                    return nil;
                }
                displayText = redactedInfo;
            }
            else if (event.isEditEvent)
            {
                return nil;
            }
            else
            {
                NSString *msgtype;
                MXJSONModelSetString(msgtype, event.content[@"msgtype"]);

                NSString *body;
                BOOL isHTML = NO;

                // Use the HTML formatted string if provided
                if ([event.content[@"format"] isEqualToString:kMXRoomMessageFormatHTML])
                {
                    isHTML =YES;
                    MXJSONModelSetString(body, event.content[@"formatted_body"]);
                }
                else
                {
                    MXJSONModelSetString(body, event.content[@"body"]);
                }

                if (body)
                {
                    if ([msgtype isEqualToString:kMXMessageTypeImage])
                    {
                        body = body? body : [NSBundle mxk_localizedStringForKey:@"notice_image_attachment"];
                        // Check attachment validity
                        if (![self isSupportedAttachment:event])
                        {
                            NSLog(@"[MXKEventFormatter] Warning: Unsupported attachment %@", event.description);
                            body = [NSBundle mxk_localizedStringForKey:@"notice_invalid_attachment"];
                            *error = MXKEventFormatterErrorUnsupported;
                        }
                    }
                    else if ([msgtype isEqualToString:kMXMessageTypeAudio])
                    {
                        body = body? body : [NSBundle mxk_localizedStringForKey:@"notice_audio_attachment"];
                        if (![self isSupportedAttachment:event])
                        {
                            NSLog(@"[MXKEventFormatter] Warning: Unsupported attachment %@", event.description);
                            if (_isForSubtitle || !_settings.showUnsupportedEventsInRoomHistory)
                            {
                                body = [NSBundle mxk_localizedStringForKey:@"notice_invalid_attachment"];
                            }
                            else
                            {
                                body = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_unsupported_attachment"], event.description];
                            }
                            *error = MXKEventFormatterErrorUnsupported;
                        }
                    }
                    else if ([msgtype isEqualToString:kMXMessageTypeVideo])
                    {
                        body = body? body : [NSBundle mxk_localizedStringForKey:@"notice_video_attachment"];
                        if (![self isSupportedAttachment:event])
                        {
                            NSLog(@"[MXKEventFormatter] Warning: Unsupported attachment %@", event.description);
                            if (_isForSubtitle || !_settings.showUnsupportedEventsInRoomHistory)
                            {
                                body = [NSBundle mxk_localizedStringForKey:@"notice_invalid_attachment"];
                            }
                            else
                            {
                                body = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_unsupported_attachment"], event.description];
                            }
                            *error = MXKEventFormatterErrorUnsupported;
                        }
                    }
                    else if ([msgtype isEqualToString:kMXMessageTypeLocation])
                    {
                        body = body? body : [NSBundle mxk_localizedStringForKey:@"notice_location_attachment"];
                        if (![self isSupportedAttachment:event])
                        {
                            NSLog(@"[MXKEventFormatter] Warning: Unsupported attachment %@", event.description);
                            if (_isForSubtitle || !_settings.showUnsupportedEventsInRoomHistory)
                            {
                                body = [NSBundle mxk_localizedStringForKey:@"notice_invalid_attachment"];
                            }
                            else
                            {
                                body = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_unsupported_attachment"], event.description];
                            }
                            *error = MXKEventFormatterErrorUnsupported;
                        }
                    }
                    else if ([msgtype isEqualToString:kMXMessageTypeFile])
                    {
                        body = body? body : [NSBundle mxk_localizedStringForKey:@"notice_file_attachment"];
                        // Check attachment validity
                        if (![self isSupportedAttachment:event])
                        {
                            NSLog(@"[MXKEventFormatter] Warning: Unsupported attachment %@", event.description);
                            body = [NSBundle mxk_localizedStringForKey:@"notice_invalid_attachment"];
                            *error = MXKEventFormatterErrorUnsupported;
                        }
                    }

                    if (isHTML)
                    {
                        // Build the attributed string from the HTML string
                        attributedDisplayText = [self renderHTMLString:body forEvent:event];
                    }
                    else
                    {
                        // Build the attributed string with the right font and color for the event
                        attributedDisplayText = [self renderString:body forEvent:event];
                    }

                    // Build the full emote string after the body message formatting
                    if ([msgtype isEqualToString:kMXMessageTypeEmote])
                    {
                        // Always use default font and color for the emote prefix
                        NSString *emotePrefix = [NSString stringWithFormat:@"* %@ ", senderDisplayName];
                        NSMutableAttributedString *newAttributedDisplayText =
                        [[NSMutableAttributedString alloc] initWithString:emotePrefix
                                                               attributes:@{
                                                                            NSForegroundColorAttributeName: _defaultTextColor,
                                                                            NSFontAttributeName: _defaultTextFont
                                                                            }];

                        // Then, append the styled body message
                        [newAttributedDisplayText appendAttributedString:attributedDisplayText];
                        attributedDisplayText = newAttributedDisplayText;
                    }
                }
            }
            break;
        }
        case MXEventTypeRoomMessageFeedback:
        {
            NSString *type;
            MXJSONModelSetString(type, event.content[@"type"]);
            NSString *eventId;
            MXJSONModelSetString(eventId, event.content[@"target_event_id"]);
            
            if (type && eventId)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_feedback"], eventId, type];
                // Append redacted info if any
                if (redactedInfo)
                {
                    displayText = [NSString stringWithFormat:@"%@ %@", displayText, redactedInfo];
                }
            }
            break;
        }
        case MXEventTypeRoomRedaction:
        {
            NSString *eventId = event.redacts;
            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_redaction"], senderDisplayName, eventId];
            break;
        }
        case MXEventTypeRoomThirdPartyInvite:
        {
            NSString *displayname;
            MXJSONModelSetString(displayname, event.content[@"display_name"]);
            if (displayname)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_third_party_invite"], senderDisplayName, displayname];
            }
            else
            {
                // Consider the invite has been revoked
                MXJSONModelSetString(displayname, event.prevContent[@"display_name"]);
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_third_party_revoked_invite"], senderDisplayName, displayname];
            }
            break;
        }
        case MXEventTypeCallInvite:
        {
            MXCallInviteEventContent *callInviteEventContent = [MXCallInviteEventContent modelFromJSON:event.content];

            if (callInviteEventContent.isVideoCall)
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_placed_video_call"], senderDisplayName];
            }
            else
            {
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_placed_voice_call"], senderDisplayName];
            }
            break;
        }
        case MXEventTypeCallAnswer:
        {
            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_answered_video_call"], senderDisplayName];
            break;
        }
        case MXEventTypeCallHangup:
        {
            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_ended_video_call"], senderDisplayName];
            break;
        }
        case MXEventTypeSticker:
        {
            // Is redacted?
            if (isRedacted)
            {
                if (!redactedInfo)
                {
                    // Here the event is ignored (no display)
                    return nil;
                }
                displayText = redactedInfo;
            }
            else
            {
                NSString *body;
                MXJSONModelSetString(body, event.content[@"body"]);
                
                // Check sticker validity
                if (![self isSupportedAttachment:event])
                {
                    NSLog(@"[MXKEventFormatter] Warning: Unsupported sticker %@", event.description);
                    body = [NSBundle mxk_localizedStringForKey:@"notice_invalid_attachment"];
                    *error = MXKEventFormatterErrorUnsupported;
                }
                
                displayText = body? body : [NSBundle mxk_localizedStringForKey:@"notice_sticker"];
            }
            break;
        }

        default:
            *error = MXKEventFormatterErrorUnknownEventType;
            break;
    }

    if (!attributedDisplayText && displayText)
    {
        // Build the attributed string with the right font and color for the event
        attributedDisplayText = [self renderString:displayText forEvent:event];
    }
    
    if (!attributedDisplayText)
    {
        NSLog(@"[MXKEventFormatter] Warning: Unsupported event %@)", event.description);
        if (_settings.showUnsupportedEventsInRoomHistory)
        {
            if (MXKEventFormatterErrorNone == *error)
            {
                *error = MXKEventFormatterErrorUnsupported;
            }
            
            NSString *shortDescription = nil;
            
            switch (*error)
            {
                case MXKEventFormatterErrorUnsupported:
                    shortDescription = [NSBundle mxk_localizedStringForKey:@"notice_error_unsupported_event"];
                    break;
                case MXKEventFormatterErrorUnexpected:
                    shortDescription = [NSBundle mxk_localizedStringForKey:@"notice_error_unexpected_event"];
                    break;
                case MXKEventFormatterErrorUnknownEventType:
                    shortDescription = [NSBundle mxk_localizedStringForKey:@"notice_error_unknown_event_type"];
                    break;
                    
                default:
                    break;
            }
            
            if (!_isForSubtitle)
            {
                // Return event content as unsupported event
                displayText = [NSString stringWithFormat:@"%@: %@", shortDescription, event.description];
            }
            else
            {
                // Return a short error description
                displayText = shortDescription;
            }

            // Build the attributed string with the right font for the event
            attributedDisplayText = [self renderString:displayText forEvent:event];
        }
    }
    
    return attributedDisplayText;
}

- (NSAttributedString*)attributedStringFromEvents:(NSArray<MXEvent*>*)events withRoomState:(MXRoomState*)roomState error:(MXKEventFormatterError*)error
{
    // TODO: Do a full summary
    return nil;
}

- (NSAttributedString*)renderString:(NSString*)string forEvent:(MXEvent*)event
{
    // Sanity check
    if (!string)
    {
        return nil;
    }
    
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:string];

    NSRange wholeString = NSMakeRange(0, str.length);

    // Apply color and font corresponding to the event state
    [str addAttribute:NSForegroundColorAttributeName value:[self textColorForEvent:event] range:wholeString];
    [str addAttribute:NSFontAttributeName value:[self fontForEvent:event] range:wholeString];

    // If enabled, make links clickable
    if (!([[_settings httpLinkScheme] isEqualToString: @"http"] &&
          [[_settings httpsLinkScheme] isEqualToString: @"https"]))
    {
        NSArray *matches = [linkDetector matchesInString:[str string] options:0 range:wholeString];
        for (NSTextCheckingResult *match in matches)
        {
            NSRange matchRange = [match range];
            NSURL *matchUrl = [match URL];
            NSURLComponents *url = [[NSURLComponents new] initWithURL:matchUrl resolvingAgainstBaseURL:NO];

            if (url)
            {
                if ([url.scheme isEqualToString: @"http"])
                {
                    url.scheme = [_settings httpLinkScheme];
                }
                else if ([url.scheme isEqualToString: @"https"])
                {
                    url.scheme = [_settings httpsLinkScheme];
                }

                if (url.URL)
                {
                    [str addAttribute:NSLinkAttributeName value:url.URL range:matchRange];
                }
            }
        }
    }

    // Apply additional treatments
    return [self postRenderAttributedString:str];
}

- (NSAttributedString*)renderHTMLString:(NSString*)htmlString forEvent:(MXEvent*)event
{
    NSString *html = htmlString;

    // Special treatment for "In reply to" message
    NSDictionary *relatesTo;
    MXJSONModelSetDictionary(relatesTo, event.content[@"m.relates_to"]);
    if ([relatesTo[@"m.in_reply_to"] isKindOfClass:NSDictionary.class])
    {
        html = [self renderReplyTo:html];
    }

    // Do some sanitisation before rendering the string
    html = [MXKTools sanitiseHTML:html withAllowedHTMLTags:_allowedHTMLTags imageHandler:nil];

    // Apply the css style that corresponds to the event state
    UIFont *font = [self fontForEvent:event];
    NSDictionary *options = @{
                              DTUseiOS6Attributes: @(YES),              // Enable it to be able to display the attributed string in a UITextView
                              DTDefaultFontFamily: font.familyName,
                              DTDefaultFontName: font.fontName,
                              DTDefaultFontSize: @(font.pointSize),
                              DTDefaultTextColor: [self textColorForEvent:event],
                              DTDefaultLinkDecoration: @(NO),
                              DTDefaultStyleSheet: dtCSS
                              };

    // Do not use the default HTML renderer of NSAttributedString because this method
    // runs on the UI thread which we want to avoid because renderHTMLString is called
    // most of the time from a background thread.
    // Use DTCoreText HTML renderer instead.
    // Using DTCoreText, which renders static string, helps to avoid code injection attacks
    // that could happen with the default HTML renderer of NSAttributedString which is a
    // webview.
    NSAttributedString *str = [[NSAttributedString alloc] initWithHTMLData:[html dataUsingEncoding:NSUTF8StringEncoding] options:options documentAttributes:NULL];
        
    // Apply additional treatments
    str = [self postRenderAttributedString:str];

    // Finalize the attributed string by removing DTCoreText artifacts (Trim trailing newlines).
    str = [MXKTools removeDTCoreTextArtifacts:str];

    // Finalize HTML blockquote blocks marking
    str = [MXKTools removeMarkedBlockquotesArtifacts:str];

    return str;
}

/**
 Special treatment for "In reply to" message.

 According to https://docs.google.com/document/d/1BPd4lBrooZrWe_3s_lHw_e-Dydvc7bXbm02_sV2k6Sc/edit.

 @param htmlString an html string containing a reply-to message.
 @return a displayable internationalised html string.
 */
- (NSString*)renderReplyTo:(NSString*)htmlString
{
    NSString *html = htmlString;

    // Replace <mx-reply><blockquote><a href=\"__permalink__\">In reply to</a>
    // By <mx-reply><blockquote><a href=\"#\">['In reply to' from resources]</a>
    // To disable the link and to localize the "In reply to" string
    // This link is the first <a> HTML node of the html string
    NSRange hyperlinkTagStart = [html rangeOfString:@"<a"];
    NSRange hyperlinkTagEnd = [html rangeOfString:@"</a>"];
    if (hyperlinkTagStart.location != NSNotFound && hyperlinkTagEnd.location != NSNotFound)
    {
        NSString *inReplyToATag = [NSString stringWithFormat:@"<a href=\"#\">%@", [NSBundle mxk_localizedStringForKey:@"notice_in_reply_to"]];
        html = [html stringByReplacingCharactersInRange:NSMakeRange(hyperlinkTagStart.location, hyperlinkTagEnd.location - hyperlinkTagStart.location) withString:inReplyToATag];
    }

    // <blockquote> content in a reply-to message must be under a <p> child like
    // other quoted messages. Else it breaks the workaround we use to display
    // the vertical bar on blockquotes with DTCoreText
    html = [html stringByReplacingOccurrencesOfString:@"<mx-reply><blockquote>" withString:@"<blockquote><p>"];
    html = [html stringByReplacingOccurrencesOfString:@"</blockquote></mx-reply>" withString:@"</p></blockquote>"];

    return html;
}

- (NSAttributedString*)postRenderAttributedString:(NSAttributedString*)attributedString
{
    if (!attributedString)
    {
        return nil;
    }
    
    NSInteger enabledMatrixIdsBitMask= 0;

    // If enabled, make user id clickable
    if (_treatMatrixUserIdAsLink)
    {
        enabledMatrixIdsBitMask |= MXKTOOLS_USER_IDENTIFIER_BITWISE;
    }

    // If enabled, make room id clickable
    if (_treatMatrixRoomIdAsLink)
    {
        enabledMatrixIdsBitMask |= MXKTOOLS_ROOM_IDENTIFIER_BITWISE;
    }

    // If enabled, make room alias clickable
    if (_treatMatrixRoomAliasAsLink)
    {
        enabledMatrixIdsBitMask |= MXKTOOLS_ROOM_ALIAS_BITWISE;
    }

    // If enabled, make event id clickable
    if (_treatMatrixEventIdAsLink)
    {
        enabledMatrixIdsBitMask |= MXKTOOLS_EVENT_IDENTIFIER_BITWISE;
    }
    
    // If enabled, make group id clickable
    if (_treatMatrixGroupIdAsLink)
    {
        enabledMatrixIdsBitMask |= MXKTOOLS_GROUP_IDENTIFIER_BITWISE;
    }

    return [MXKTools createLinksInAttributedString:attributedString forEnabledMatrixIds:enabledMatrixIdsBitMask];
}

- (NSAttributedString *)renderString:(NSString *)string withPrefix:(NSString *)prefix forEvent:(MXEvent *)event
{
    NSMutableAttributedString *str;

    if (prefix)
    {
        str = [[NSMutableAttributedString alloc] initWithString:prefix];

        // Apply the prefix font and color on the prefix
        NSRange prefixRange = NSMakeRange(0, prefix.length);
        [str addAttribute:NSForegroundColorAttributeName value:_prefixTextColor range:prefixRange];
        [str addAttribute:NSFontAttributeName value:_prefixTextFont range:prefixRange];

        // And append the string rendered according to event state
        [str appendAttributedString:[self renderString:string forEvent:event]];

        return str;
    }
    else
    {
        // Use the legacy method
        return [self renderString:string forEvent:event];
    }
}

- (void)setDefaultCSS:(NSString*)defaultCSS
{
    // Make sure we mark HTML blockquote blocks for later computation
    _defaultCSS = [NSString stringWithFormat:@"%@%@", [MXKTools cssToMarkBlockquotes], defaultCSS];

    dtCSS = [[DTCSSStylesheet alloc] initWithStyleBlock:_defaultCSS];
}

#pragma mark - MXRoomSummaryUpdating
- (BOOL)session:(MXSession *)session updateRoomSummary:(MXRoomSummary *)summary withStateEvents:(NSArray<MXEvent *> *)stateEvents roomState:(MXRoomState *)roomState
{
    // We build strings containing the sender displayname (ex: "Bob: Hello!")
    // If a sender changes his displayname, we need to update the lastMessage.
    MXEvent *lastMessageEvent;
    for (MXEvent *event in stateEvents)
    {
        if (event.isUserProfileChange)
        {
            if (!lastMessageEvent)
            {
                // Load lastMessageEvent on demand to save I/O
                lastMessageEvent = summary.lastMessageEvent;
            }

            if ([event.sender isEqualToString:lastMessageEvent.sender])
            {
                // The last message must be recomputed
                [summary resetLastMessage:nil failure:nil commit:YES];
                break;
            }
        }
        else if (event.eventType == MXEventTypeRoomJoinRules)
        {
            summary.others[@"mxkEventFormatterisJoinRulePublic"] = @(roomState.isJoinRulePublic);
        }
    }

    return [defaultRoomSummaryUpdater session:session updateRoomSummary:summary withStateEvents:stateEvents roomState:roomState];
}

- (BOOL)session:(MXSession *)session updateRoomSummary:(MXRoomSummary *)summary withLastEvent:(MXEvent *)event eventState:(MXRoomState *)eventState roomState:(MXRoomState *)roomState
{
    // Use the default updater as first pass
    BOOL updated = [defaultRoomSummaryUpdater session:session updateRoomSummary:summary withLastEvent:event eventState:eventState roomState:roomState];
    if (updated)
    {
        // Then customise

        // Compute the text message
        // Note that we use the current room state (roomState) because when we display
        // users displaynames, we want current displaynames
        MXKEventFormatterError error;
        summary.lastMessageString = [self stringFromEvent:event withRoomState:roomState error:&error];

        // Store the potential error
        summary.lastMessageOthers[@"mxkEventFormatterError"] = @(error);

        if (0 == summary.lastMessageString.length)
        {
            // @TODO: there is a conflict with what [defaultRoomSummaryUpdater updateRoomSummary] did :/
            updated = NO;
        }
        else
        {
            summary.lastMessageOthers[@"lastEventDate"] = [self dateStringFromEvent:event withTime:YES];

            // Check whether the sender name has to be added
            NSString *prefix = nil;

            if (event.eventType == MXEventTypeRoomMessage)
            {
                NSString *msgtype = event.content[@"msgtype"];
                if ([msgtype isEqualToString:kMXMessageTypeEmote] == NO)
                {
                    NSString *senderDisplayName = [self senderDisplayNameForEvent:event withRoomState:roomState];
                    prefix = [NSString stringWithFormat:@"%@: ", senderDisplayName];
                }
            }
            else if (event.eventType == MXEventTypeSticker)
            {
                NSString *senderDisplayName = [self senderDisplayNameForEvent:event withRoomState:roomState];
                prefix = [NSString stringWithFormat:@"%@: ", senderDisplayName];
            }

            // Compute the attribute text message
            summary.lastMessageAttributedString = [self renderString:summary.lastMessageString withPrefix:prefix forEvent:event];
        }
    }
    
    return updated;
}

- (BOOL)session:(MXSession *)session updateRoomSummary:(MXRoomSummary *)summary withServerRoomSummary:(MXRoomSyncSummary *)serverRoomSummary roomState:(MXRoomState *)roomState
{
    return [defaultRoomSummaryUpdater session:session updateRoomSummary:summary withServerRoomSummary:serverRoomSummary roomState:roomState];
}


#pragma mark - Conversion private methods

/**
 Get the text color to use according to the event state.
 
 @param event the event.
 @return the text color.
 */
- (UIColor*)textColorForEvent:(MXEvent*)event
{
    // Select the text color
    UIColor *textColor;
    
    // Check whether an error occurred during event formatting.
    if (event.mxkEventFormatterError != MXKEventFormatterErrorNone)
    {
        textColor = _errorTextColor;
    }
    // Check whether the message is highlighted.
    else if (event.mxkIsHighlighted)
    {
        textColor = _bingTextColor;
    }
    else
    {
        // Consider here the sending state of the event, and the property `isForSubtitle`.
        switch (event.sentState)
        {
            case MXEventSentStateSent:
                if (_isForSubtitle)
                {
                    textColor = _subTitleTextColor;
                }
                else
                {
                    textColor = _defaultTextColor;
                }
                break;
            case MXEventSentStateEncrypting:
                textColor = _encryptingTextColor;
                break;
            case MXEventSentStatePreparing:
            case MXEventSentStateUploading:
            case MXEventSentStateSending:
                textColor = _sendingTextColor;
                break;
            case MXEventSentStateFailed:
                textColor = _errorTextColor;
                break;
            default:
                if (_isForSubtitle)
                {
                    textColor = _subTitleTextColor;
                }
                else
                {
                    textColor = _defaultTextColor;
                }
                break;
        }
    }
    
    return textColor;
}

/**
 Get the text font to use according to the event state.

 @param event the event.
 @return the text font.
 */
- (UIFont*)fontForEvent:(MXEvent*)event
{
    // Select text font
    UIFont *font = _defaultTextFont;
    if (event.isState)
    {
        font = _stateEventTextFont;
    }
    else if (event.eventType == MXEventTypeCallInvite || event.eventType == MXEventTypeCallAnswer || event.eventType == MXEventTypeCallHangup)
    {
        font = _callNoticesTextFont;
    }
    else if (event.mxkIsHighlighted)
    {
        font = _bingTextFont;
    }
    else if (event.eventType == MXEventTypeRoomEncrypted)
    {
        font = _encryptedMessagesTextFont;
    }
    else if (!_isForSubtitle && event.eventType == MXEventTypeRoomMessage && (_emojiOnlyTextFont || _singleEmojiTextFont))
    {
        NSString *message;
        MXJSONModelSetString(message, event.content[@"body"]);

        if (_emojiOnlyTextFont && [MXKTools isEmojiOnlyString:message])
        {
            font = _emojiOnlyTextFont;
        }
        else if (_singleEmojiTextFont && [MXKTools isSingleEmojiString:message])
        {
            font = _singleEmojiTextFont;
        }
    }
    return font;
}

#pragma mark - Conversion tools

- (NSString *)htmlStringFromMarkdownString:(NSString *)markdownString
{
    const char *cstr = [markdownString cStringUsingEncoding: NSUTF8StringEncoding];
    const char *htmlCString = cmark_markdown_to_html(cstr, strlen(cstr), CMARK_OPT_HARDBREAKS);
    NSString *htmlString = [[NSString alloc] initWithCString:htmlCString encoding:NSUTF8StringEncoding];

    // Strip off the trailing newline, if it exists.
    if ([htmlString hasSuffix:@"\n"])
    {
        htmlString = [htmlString substringToIndex:htmlString.length - 1];
    }

    // Strip start and end <p> tags else you get 'orrible spacing.
    // But only do this if it's a single paragraph we're dealing with,
    // otherwise we'll produce some garbage (`something</p><p>another`).
    if ([htmlString hasPrefix:@"<p>"] && [htmlString hasSuffix:@"</p>"])
    {
        NSArray *components = [htmlString componentsSeparatedByString:@"<p>"];
        NSUInteger paragrapsCount = components.count - 1;

        if (paragrapsCount == 1) {
            htmlString = [htmlString substringFromIndex:3];
            htmlString = [htmlString substringToIndex:htmlString.length - 4];
        }
    }

    return htmlString;
}

#pragma mark - Timestamp formatting

- (NSString*)dateStringFromDate:(NSDate *)date withTime:(BOOL)time
{
    // Get first date string without time (if a date format is defined, else only time string is returned)
    NSString *dateString = nil;
    if (dateFormatter.dateFormat)
    {
        dateString = [dateFormatter stringFromDate:date];
    }
    
    if (time)
    {
        NSString *timeString = [self timeStringFromDate:date];
        if (dateString.length)
        {
            // Add time string
            dateString = [NSString stringWithFormat:@"%@ %@", dateString, timeString];
        }
        else
        {
            dateString = timeString;
        }
    }
    
    return dateString;
}

- (NSString*)dateStringFromTimestamp:(uint64_t)timestamp withTime:(BOOL)time
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp / 1000];
    
    return [self dateStringFromDate:date withTime:time];
}

- (NSString*)dateStringFromEvent:(MXEvent *)event withTime:(BOOL)time
{
    if (event.originServerTs != kMXUndefinedTimestamp)
    {
        return [self dateStringFromTimestamp:event.originServerTs withTime:time];
    }
    
    return nil;
}

- (NSString*)timeStringFromDate:(NSDate *)date
{
    NSString *timeString = [timeFormatter stringFromDate:date];
    
    return timeString.lowercaseString;
}

@end
