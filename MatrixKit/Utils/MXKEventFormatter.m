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

#import "MXKEventFormatter.h"

#import "MXEvent+MatrixKit.h"
#import "NSBundle+MatrixKit.h"

#import "MXKTools.h"

#import "DTCoreText.h"
#import "GHMarkdownParser.h"

NSString *const kMXKEventFormatterLocalEventIdPrefix = @"MXKLocalId_";

@interface MXKEventFormatter ()
{
    /**
     The matrix session. Used to get contextual data.
     */
    MXSession *mxSession;

    /**
     The Markdown to HTML parser.
     */
    GHMarkdownParser *markdownParser;

    /**
     The default CSS converted in DTCoreText object.
     */
    DTCSSStylesheet *dtCSS;
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

        markdownParser = [[GHMarkdownParser alloc] init];
        markdownParser.options = kGHMarkdownAutoLink | kGHMarkdownNoSmartQuotes;
        markdownParser.githubFlavored = YES;        // This is the Markdown flavor we use in Matrix apps

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
                -coretext-fontname: Menlo; \
                font-size: small; \
            }";

        // Set default colors
        _defaultTextColor = [UIColor blackColor];
        _subTitleTextColor = [UIColor blackColor];
        _prefixTextColor = [UIColor blackColor];
        _bingTextColor = [UIColor blueColor];
        _sendingTextColor = [UIColor lightGrayColor];
        _errorTextColor = [UIColor redColor];
        
        _defaultTextFont = [UIFont systemFontOfSize:14];
        _prefixTextFont = [UIFont systemFontOfSize:14];
        _bingTextFont = [UIFont systemFontOfSize:14];
        _stateEventTextFont = [UIFont italicSystemFontOfSize:14];
        _callNoticesTextFont = [UIFont italicSystemFontOfSize:14];
        
        // Consider the shared app settings by default
        _settings = [MXKAppSettings standardAppSettings];
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

// Checks whether the event is related to an attachment and if it is supported
- (BOOL)isSupportedAttachment:(MXEvent*)event
{
    BOOL isSupportedAttachment = NO;
    
    if (event.eventType == MXEventTypeRoomMessage)
    {
        NSString *msgtype;
        MXJSONModelSetString(msgtype, event.content[@"msgtype"]);
        
        NSString *requiredField;
        
        if ([msgtype isEqualToString:kMXMessageTypeImage])
        {
            MXJSONModelSetString(requiredField, event.content[@"url"]);
            if (requiredField.length)
            {
                isSupportedAttachment = YES;
            }
        }
        else if ([msgtype isEqualToString:kMXMessageTypeAudio])
        {
            // Not supported yet
        }
        else if ([msgtype isEqualToString:kMXMessageTypeVideo])
        {
            MXJSONModelSetString(requiredField, event.content[@"url"]);
            if (requiredField)
            {
                isSupportedAttachment = YES;
            }
        }
        else if ([msgtype isEqualToString:kMXMessageTypeLocation])
        {
            // Not supported yet
        }
        else if ([msgtype isEqualToString:kMXMessageTypeFile])
        {
            MXJSONModelSetString(requiredField, event.content[@"url"]);
            if (requiredField)
            {
                isSupportedAttachment = YES;
            }
        }
    }
    return isSupportedAttachment;
}


#pragma mark event sender info

- (NSString*)senderDisplayNameForEvent:(MXEvent*)event withRoomState:(MXRoomState*)roomState
{
    // Consider first the current display name defined in provided room state (Note: this room state is supposed to not take the new event into account)
    NSString *senderDisplayName = [roomState memberName:event.sender];
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
    NSString *senderAvatarUrl = [roomState memberWithUserId:event.sender].avatarUrl;
    
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
        senderAvatarUrl = [mxSession.matrixRestClient urlOfIdenticon:event.sender];
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
            MXRoomState *aRoomState = roomState ? roomState : [mxSession roomWithRoomId:event.roomId].state;
            redactedBy = [aRoomState memberName:redactorId];
            
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

    // Prepare display name for concerned users
    NSString *senderDisplayName;
    senderDisplayName = roomState ? [self senderDisplayNameForEvent:event withRoomState:roomState] : event.sender;
    NSString *targetDisplayName = nil;
    if (event.stateKey)
    {
        targetDisplayName = roomState ? [roomState memberName:event.stateKey] : event.stateKey;
    }
    
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
                
                // Consider here a membership change
                if ([membership isEqualToString:@"invite"])
                {
                    if (event.content[@"third_party_invite"])
                    {
                        displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_third_party_registered_invite"], event.content[@"third_party_invite"][@"display_name"], targetDisplayName, senderDisplayName];
                    }
                    else
                    {
                        if ([MXCallManager isConferenceUser:event.stateKey])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_conference_call_request"], senderDisplayName];
                        }
                        else
                        {
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
                        displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_join"], senderDisplayName];
                    }
                }
                else if ([membership isEqualToString:@"leave"])
                {
                    NSString *prevMembership = nil;
                    if (event.prevContent)
                    {
                        MXJSONModelSetString(prevMembership, event.prevContent[@"membership"]);
                    }
                    
                    if ([event.sender isEqualToString:event.stateKey])
                    {
                        if ([MXCallManager isConferenceUser:event.stateKey])
                        {
                            displayText = [NSBundle mxk_localizedStringForKey:@"notice_conference_call_finished"];
                        }
                        else
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_leave"], senderDisplayName];
                        }
                    }
                    else if (prevMembership)
                    {
                        if ([prevMembership isEqualToString:@"invite"])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_withdraw"], senderDisplayName, targetDisplayName];
                        }
                        else if ([prevMembership isEqualToString:@"join"])
                        {
                            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_kick"], senderDisplayName, targetDisplayName];
                            if (event.content[@"reason"])
                            {
                                displayText = [NSString stringWithFormat:@"%@: %@", displayText, event.content[@"reason"]];
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
                    displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_ban"], senderDisplayName, targetDisplayName];
                    if (event.content[@"reason"])
                    {
                        displayText = [NSString stringWithFormat:@"%@: %@", displayText, event.content[@"reason"]];
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
                displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_created"], (roomState ? [roomState memberName:creatorId] : creatorId)];
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
            else
            {
                NSString *msgtype;
                MXJSONModelSetString(msgtype, event.content[@"msgtype"]);

                NSString *body;
                BOOL isHTML = NO;

                // Use the HTML formatted string if provided
                if ([event.content[@"format"] isEqualToString:kMXRoomMessageFormatHTML]
                    && [event.content[@"formatted_body"] isKindOfClass:[NSString class]])
                {
                    isHTML =YES;
                    body = event.content[@"formatted_body"];
                }
                else if ([event.content[@"body"] isKindOfClass:[NSString class]])
                {
                    body = event.content[@"body"];
                }

                if (body)
                {
                    if ([msgtype isEqualToString:kMXMessageTypeEmote])
                    {
                        body = [NSString stringWithFormat:@"* %@ %@", senderDisplayName, body];
                    }
                    else if ([msgtype isEqualToString:kMXMessageTypeImage])
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
            displayText = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"notice_room_third_party_invite"], senderDisplayName, event.content[@"display_name"]];
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

    // If enabled, make links clicable
    if (!([[_settings httpLinkScheme] isEqualToString: @"http"] &&
          [[_settings httpsLinkScheme] isEqualToString: @"https"]))
    {
        NSError *error = NULL;
        NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];

        NSArray *matches = [detector matchesInString:[str string] options:0 range:wholeString];
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

    return str;
}

- (NSAttributedString*)renderHTMLString:(NSString*)htmlString forEvent:(MXEvent*)event
{
    // Do some sanitisation before rendering the string
    NSString *html = [self sanitiseHTML:htmlString];

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

    // DTCoreText adds a newline at the end of plain text ( https://github.com/Cocoanetics/DTCoreText/issues/779 )
    // or after a blockquote section.
    // Trim trailing newlines
    return [self removeTrailingNewlines:str];
}

- (NSAttributedString*)removeTrailingNewlines:(NSAttributedString*)attributedString
{
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];

    // Trim trailing whitespace and newlines in the string content
    while ([str.string hasSuffixCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]])
    {
        [str deleteCharactersInRange:NSMakeRange(str.length - 1, 1)];
    }

    // New lines may have also been introduced by the paragraph style
    // Make sure the last paragraph style has no spacing
    [str enumerateAttributesInRange:NSMakeRange(0, str.length) options:(NSAttributedStringEnumerationReverse) usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        if (attrs[NSParagraphStyleAttributeName])
        {
            NSMutableParagraphStyle *paragraphStyle = attrs[NSParagraphStyleAttributeName];
            paragraphStyle.paragraphSpacing = 0;
        }

        // Check only the last paragraph
        *stop = YES;
    }];

    return str;
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

- (NSString*)sanitiseHTML:(NSString*)htmlString
{
    NSString *html = htmlString;

    // List all HTML tags used in htmlString
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<(\\w+)[^>]*>" options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray<NSTextCheckingResult *> *tagsInTheHTML = [regex matchesInString:htmlString options:0 range:NSMakeRange(0, htmlString.length)];

    // Find those that are not allowed
    NSMutableSet *tagsToRemoveSet = [NSMutableSet set];
    for (NSTextCheckingResult *result in tagsInTheHTML)
    {
        NSString *tag = [htmlString substringWithRange:[result rangeAtIndex:1]].lowercaseString;
        if ([_allowedHTMLTags indexOfObject:tag] == NSNotFound)
        {
            [tagsToRemoveSet addObject:tag];
        }
    }

    // And remove them from the HTML string
    if (tagsToRemoveSet.count)
    {
        NSArray *tagsToRemove = tagsToRemoveSet.allObjects;

        NSString *tagsToRemoveString = tagsToRemove[0];
        for (NSInteger i = 1; i < tagsToRemove.count; i++)
        {
            tagsToRemoveString  = [tagsToRemoveString stringByAppendingString:[NSString stringWithFormat:@"|%@", tagsToRemove[i]]];
        }

        html = [html stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"<\\/?(%@)[^>]*>", tagsToRemoveString]
                                               withString:@""
                                                  options:NSRegularExpressionSearch | NSCaseInsensitiveSearch
                                                    range:NSMakeRange(0, html.length)];
    }

    // TODO: Sanitise other things: attributes, URL schemes, etc
    
    return html;
}

- (void)setDefaultCSS:(NSString*)defaultCSS
{
    _defaultCSS = defaultCSS;
    dtCSS = [[DTCSSStylesheet alloc] initWithStyleBlock:_defaultCSS];
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
    switch (event.mxkState)
    {
        case MXKEventStateDefault:
            if (_isForSubtitle)
            {
                textColor = _subTitleTextColor;
            }
            else
            {
                textColor = _defaultTextColor;
            }
            break;
        case MXKEventStateBing:
            textColor = _bingTextColor;
            break;
        case MXKEventStateSending:
            textColor = _sendingTextColor;
            break;
        case MXKEventStateSendingFailed:
        case MXKEventStateUnsupported:
        case MXKEventStateUnexpected:
        case MXKEventStateUnknownType:
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
    else if (event.mxkState == MXKEventStateBing)
    {
        font = _bingTextFont;
    }
    return font;
}

#pragma mark - Conversion tools

- (NSString *)htmlStringFromMarkdownString:(NSString *)markdownString
{
    // In GitHub Flavored Mardown, the '#' sign creates an HTML header only if it is
    // followed by the space char.
    // But GHMarkdownParser creates an HTML header everytime it finds a '#' sign which
    // kills room aliases (like #matrix:matrix.org).
    // So, escape them if they are not followed by a space
    NSString *str = [markdownString stringByReplacingOccurrencesOfString:@"(#+)[^( |#)]" withString:@"\\\\$0" options:NSRegularExpressionSearch range:NSMakeRange(0, markdownString.length)];

    NSString *htmlString = [markdownParser HTMLStringFromMarkdownString:str];

    // Strip start and end <p> tags else you get 'orrible spacing
    if ([htmlString hasPrefix:@"<p>"])
    {
        htmlString = [htmlString substringFromIndex:3];
    }
    if ([htmlString hasSuffix:@"</p>"])
    {
        htmlString = [htmlString substringToIndex:htmlString.length - 4];
    }

    return htmlString;
}

#pragma mark - Fake event objects creation

- (MXEvent*)fakeRoomMessageEventForRoomId:(NSString*)roomId withEventId:(NSString*)eventId andContent:(NSDictionary*)content
{
    if (!eventId)
    {
        eventId = [NSString stringWithFormat:@"%@%@", kMXKEventFormatterLocalEventIdPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
    }
    
    MXEvent *event = [[MXEvent alloc] init];
    event.roomId = roomId;
    event.eventId = eventId;
    event.type = kMXEventTypeStringRoomMessage;
    event.originServerTs = (uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000);
    event.sender = mxSession.myUser.userId;
    event.content = content;
    
    return event;
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
