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

#import "MXKRoomDataSource.h"

#import "MXKQueuedEvent.h"
#import "MXKRoomBubbleTableViewCell.h"

#import "MXKRoomBubbleCellData.h"

#import "MXKTools.h"

#import "MXKAppSettings.h"

#import "MXEncryptedAttachments.h"

#pragma mark - Constant definitions

NSString *const kMXKRoomBubbleCellDataIdentifier = @"kMXKRoomBubbleCellDataIdentifier";

NSString *const kMXKRoomDataSourceMetaDataChanged = @"kMXKRoomDataSourceMetaDataChanged";
NSString *const kMXKRoomDataSourceSyncStatusChanged = @"kMXKRoomDataSourceSyncStatusChanged";
NSString *const kMXKRoomDataSourceFailToLoadTimelinePosition = @"kMXKRoomDataSourceFailToLoadTimelinePosition";
NSString *const kMXKRoomDataSourceTimelineError = @"kMXKRoomDataSourceTimelineError";
NSString *const kMXKRoomDataSourceTimelineErrorErrorKey = @"kMXKRoomDataSourceTimelineErrorErrorKey";

@interface MXKRoomDataSource ()
{
    /**
     If the data is not from a live timeline, `initialEventId` is the event in the past
     where the timeline starts.
     */
    NSString *initialEventId;

    /**
     Current pagination request (if any)
     */
    MXHTTPOperation *paginationRequest;
    
    /**
     The actual listener related to the current pagination in the timeline.
     */
    id paginationListener;
    
    /**
     The listener to incoming events in the room.
     */
    id liveEventsListener;
    
    /**
     The listener to redaction events in the room.
     */
    id redactionListener;
    
    /**
     The listener to receipts events in the room.
     */
    id receiptsListener;
    
    /**
     Mapping between events ids and bubbles.
     */
    NSMutableDictionary *eventIdToBubbleMap;
    
    /**
     Typing notifications listener.
     */
    id typingNotifListener;
    
    /**
     List of members who are typing in the room.
     */
    NSArray *currentTypingUsers;
    
    /**
     Snapshot of the queued events.
     */
    NSMutableArray *eventsToProcessSnapshot;
    
    /**
     Snapshot of the bubbles used during events processing.
     */
    NSMutableArray *bubblesSnapshot;
    
    /**
     The room being peeked, if any.
     */
    MXPeekingRoom *peekingRoom;
    
    /**
     The cache for the last message returned by [self lastMessageWithEventFormatter:]
     */
    MXEvent *lastMessage;
    
    /**
     Observe UIApplicationSignificantTimeChangeNotification to trigger cell change on time formatting change.
     */
    id UIApplicationSignificantTimeChangeNotificationObserver;
    
    /**
     Observe NSCurrentLocaleDidChangeNotification to trigger cell change on time formatting change.
     */
    id NSCurrentLocaleDidChangeNotificationObserver;
    
    /**
     Observe kMXRoomDidFlushDataNotification to trigger cell change when existing room history has been flushed during server sync.
     */
    id roomDidFlushDataNotificationObserver;
    
    /**
     Observe kMXRoomDidUpdateUnreadNotification to refresh unread counters.
     */
    id roomDidUpdateUnreadNotificationObserver;
}

@end

@implementation MXKRoomDataSource

- (instancetype)initWithRoomId:(NSString *)roomId andMatrixSession:(MXSession *)matrixSession
{
    self = [super initWithMatrixSession:matrixSession];
    if (self)
    {
        //NSLog(@"[MXKRoomDataSource] initWithRoomId %p - room id: %@", self, roomId);
        
        _roomId = roomId;
        _isLive = YES;
        bubbles = [NSMutableArray array];
        eventsToProcess = [NSMutableArray array];
        eventIdToBubbleMap = [NSMutableDictionary dictionary];

        // Set default data and view classes
        // Cell data
        [self registerCellDataClass:MXKRoomBubbleCellData.class forCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
        
        // Set default MXEvent -> NSString formatter
        self.eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:self.mxSession];
        
        // display the read receips by default
        self.showBubbleReceipts = YES;
        
        // display keyboard icon in cells.
        _showTypingNotifications = YES;
        
        self.useCustomDateTimeLabel = NO;
        self.useCustomReceipts = NO;
        self.useCustomUnsentButton = NO;
        
        _maxBackgroundCachedBubblesCount = MXKROOMDATASOURCE_CACHED_BUBBLES_COUNT_THRESHOLD;
        _paginationLimitAroundInitialEvent = MXKROOMDATASOURCE_PAGINATION_LIMIT_AROUND_INITIAL_EVENT;
        
        // Check here whether the app user wants to display all the events
        if ([[MXKAppSettings standardAppSettings] showAllEventsInRoomHistory])
        {
            // Use a filter to retrieve all the events (except kMXEventTypeStringPresence which are not related to a specific room)
            self.eventsFilterForMessages = @[
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
        else
        {
            // Display only a subset of events
            self.eventsFilterForMessages = @[
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

        // Observe UIApplicationSignificantTimeChangeNotification to refresh bubbles if date/time are shown.
        // UIApplicationSignificantTimeChangeNotification is posted if DST is updated, carrier time is updated
        UIApplicationSignificantTimeChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationSignificantTimeChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            [self onDateTimeFormatUpdate];
        }];
        
        // Observe NSCurrentLocaleDidChangeNotification to refresh bubbles if date/time are shown.
        // NSCurrentLocaleDidChangeNotification is triggered when the time swicthes to AM/PM to 24h time format
        NSCurrentLocaleDidChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            [self onDateTimeFormatUpdate];
            
        }];

        // Listen to the event sent state changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidChangeSentState:) name:kMXEventDidChangeSentStateNotification object:nil];
        // Listen to events decrypted
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidDecrypt:) name:kMXEventDidDecryptNotification object:nil];
    }
    return self;
}

- (instancetype)initWithRoomId:(NSString*)roomId initialEventId:(NSString*)initialEventId2 andMatrixSession:(MXSession*)mxSession
{
    self = [self initWithRoomId:roomId andMatrixSession:mxSession];
    if (self)
    {
        if (initialEventId2)
        {
            initialEventId = initialEventId2;
            _isLive = NO;
        }
    }

    return self;
}

- (instancetype)initWithPeekingRoom:(MXPeekingRoom*)peekingRoom2 andInitialEventId:(NSString*)theInitialEventId
{
    self = [self initWithRoomId:peekingRoom2.roomId initialEventId:theInitialEventId andMatrixSession:peekingRoom2.mxSession];
    if (self)
    {
        peekingRoom = peekingRoom2;
        _isPeeking = YES;
    }
    return self;
}

- (void)onDateTimeFormatUpdate
{
    // update the date and the time formatters
    [self.eventFormatter initDateTimeFormatters];
    
    // refresh the UI if it is required
    if (self.showBubblesDateTime && self.delegate)
    {
        // Reload all the table
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)refreshUnreadCounters
{
    // Consider as unread the pending invitation message.
    // If the room is joined from another device,
    // this state will be updated so the standard read receipts management will be applied.
    if (MXMembershipInvite == _room.state.membership)
    {
        _hasUnread = YES;
        _notificationCount = 1; // Set 1 here to be able to refresh correctly the Application Icon Badge Number when app is backgrounded.
        _highlightCount = 0;
    }
    else
    {
        _hasUnread = (_room.localUnreadEventCount != 0);
        _notificationCount = _room.notificationCount;
        _highlightCount = _room.highlightCount;
    }
}

- (void)markAllAsRead
{
    if ([_room acknowledgeLatestEvent:YES])
    {
        _hasUnread = NO;
        _notificationCount = 0;
        _highlightCount = 0;
        
        // Notify the unread information has changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
}

- (void)limitMemoryUsage:(NSInteger)maxBubbleNb
{
    NSInteger bubbleCount;
    @synchronized(bubbles)
    {
        bubbleCount = bubbles.count;
    }
    
    if (bubbleCount > maxBubbleNb)
    {
        // Do nothing if some local echoes are in progress.
        NSArray<MXEvent*>* outgoingMessages = _room.outgoingMessages;
        
        for (NSInteger index = 0; index < outgoingMessages.count; index++)
        {
            MXEvent *outgoingMessage = [outgoingMessages objectAtIndex:index];
            
            if (outgoingMessage.sentState == MXEventSentStateSending ||
                outgoingMessage.sentState == MXEventSentStatePreparing ||
                outgoingMessage.sentState == MXEventSentStateEncrypting ||
                outgoingMessage.sentState == MXEventSentStateUploading)
            {
                NSLog(@"[MXKRoomDataSource] cancel limitMemoryUsage because some messages are being sent");
                return;
            }
        }

        // Reset the room data source (return in initial state: minimum memory usage).
        [self reload];
    }
}

- (void)reset
{
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    if (roomDidUpdateUnreadNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidUpdateUnreadNotificationObserver];
        roomDidUpdateUnreadNotificationObserver = nil;
    }
    
    if (paginationRequest)
    {
        // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
        [_timeline removeListener:paginationListener];
        paginationListener = nil;
        
        [paginationRequest cancel];
        paginationRequest = nil;
    }
    
    if (_room && liveEventsListener)
    {
        [_timeline removeListener:liveEventsListener];
        liveEventsListener = nil;
        
        [_timeline removeListener:redactionListener];
        redactionListener = nil;
        
        [_timeline removeListener:receiptsListener];
        receiptsListener = nil;
    }
    
    if (_room && typingNotifListener)
    {
        [_timeline removeListener:typingNotifListener];
        typingNotifListener = nil;
    }
    currentTypingUsers = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomInitialSyncNotification object:nil];
    
    @synchronized(eventsToProcess)
    {
        [eventsToProcess removeAllObjects];
    }
    
    // Suspend the reset operation if some events is under processing
    @synchronized(eventsToProcessSnapshot)
    {
        eventsToProcessSnapshot = nil;
        bubblesSnapshot = nil;
        
        [bubbles removeAllObjects];
        [eventIdToBubbleMap removeAllObjects];
        lastMessage = nil;
        
        _room = nil;
    }
    
    _serverSyncEventCount = 0;
    _hasUnread = NO;
    _notificationCount = 0;
    _highlightCount = 0;

    // Notify the delegate to reload its tableview
    if (self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)reload
{
    //    NSLog(@"[MXKRoomDataSource] Reload %p - room id: %@", self, _roomId);
    
    state = MXKDataSourceStatePreparing;
    if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
    {
        [self.delegate dataSource:self didStateChange:state];
    }
    
    [self reset];
    
    // Reload
    [self didMXSessionStateChange];
    
    // Handle here the case where reload has failed (should not happen except if session has been closed).
    if (state != MXKDataSourceStateReady)
    {
        NSLog(@"[MXKRoomDataSource] Reload Failed (%p - room id: %@)", self, _roomId);
        
        // Notify the last message, hasUnread, notificationCount and/or highlightCount have changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
}

- (void)destroy
{
    NSLog(@"[MXKRoomDataSource] Destroy %p - room id: %@", self, _roomId);

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeSentStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidDecryptNotification object:nil];

    if (NSCurrentLocaleDidChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:NSCurrentLocaleDidChangeNotificationObserver];
        NSCurrentLocaleDidChangeNotificationObserver = nil;
    }
    
    if (UIApplicationSignificantTimeChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:UIApplicationSignificantTimeChangeNotificationObserver];
        UIApplicationSignificantTimeChangeNotificationObserver = nil;
    }

    // If the room data source was used to peek into a room, stop the events stream on this room
    if (peekingRoom)
    {
        [_room.mxSession stopPeeking:peekingRoom];
    }

    [self reset];
    
    self.eventFormatter = nil;
    
    eventsToProcess = nil;
    bubbles = nil;
    lastMessage = nil;
    eventIdToBubbleMap = nil;

    [_timeline destroy];
    
    [super destroy];
}

- (void)didMXSessionStateChange
{
    if (MXSessionStateStoreDataReady <= self.mxSession.state)
    {
        // Check whether the room is not already set
        if (!_room)
        {
            // Are we peeking into a random room or displaying a room the user is part of?
            if (peekingRoom)
            {
                _room = peekingRoom;
            }
            else
            {
                _room = [self.mxSession roomWithRoomId:_roomId];
            }

            if (_room)
            {
                // This is the time to set up the timeline according to the called init method
                if (_isLive)
                {
                    // LIVE
                    _timeline = _room.liveTimeline;

                    // Only one pagination process can be done at a time by an MXRoom object.
                    // This assumption is satisfied by MatrixKit. Only MXRoomDataSource does it.
                    [_timeline resetPagination];
                    
                    // Observe room history flush (sync with limited timeline, or state event redaction)
                    roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                        
                        MXRoom *room = notif.object;
                        if (self.mxSession == room.mxSession && [self.roomId isEqualToString:room.state.roomId])
                        {
                            // The existing room history has been flushed during server sync because a gap has been observed between local and server storage.
                            [self reload];
                        }
                        
                    }];
                    
                    // Observe unread notifications change
                    roomDidUpdateUnreadNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidUpdateUnreadNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
                        
                        MXRoom *room = notif.object;
                        if (self.mxSession == room.mxSession && [self.roomId isEqualToString:room.state.roomId])
                        {
                            [self refreshUnreadCounters];
                        }
                        
                    }];

                    [self refreshUnreadCounters];

                    // Force to set the filter at the MXRoom level
                    self.eventsFilterForMessages = _eventsFilterForMessages;

                    // display typing notifications is optional
                    // the inherited class can manage them by its own.
                    if (_showTypingNotifications)
                    {
                        // Register on typing notif
                        [self listenTypingNotifications];
                    }

                    // Manage unsent messages
                    [self handleUnsentMessages];

                    // Update here data source state if it is not already ready
                    state = MXKDataSourceStateReady;

                    // Check user membership in this room
                    MXMembership membership = self.room.state.membership;
                    if (membership == MXMembershipUnknown || membership == MXMembershipInvite)
                    {
                        // Here the initial sync is not ended or the room is a pending invitation.
                        // Note: In case of invitation, a full sync will be triggered if the user joins this room.

                        // We have to observe here 'kMXRoomInitialSyncNotification' to reload room data when room sync is done.
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXRoomInitialSynced:) name:kMXRoomInitialSyncNotification object:nil];
                    }

                    // Notify the last message may have changed
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
                }
                else
                {
                    // Past timeline
                    // Less things need to configured
                    _timeline = [_room timelineOnEvent:initialEventId];

                    // Force to set the filter at the MXRoom level
                    self.eventsFilterForMessages = _eventsFilterForMessages;

                    // Preload the state and some messages around the initial event
                    [_timeline resetPaginationAroundInitialEventWithLimit:_paginationLimitAroundInitialEvent success:^{

                        // Do a "classic" reset. The room view controller will paginate
                        // from the events stored in the timeline store
                        [_timeline resetPagination];

                        // Update here data source state if it is not already ready
                        state = MXKDataSourceStateReady;

                        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
                        {
                            [self.delegate dataSource:self didStateChange:state];
                        }

                    } failure:^(NSError *error) {

                        NSLog(@"[MXKRoomDataSource] Failed to resetPaginationAroundInitialEventWithLimit");

                        // Notify the error
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceTimelineError
                                                                            object:self
                                                                          userInfo:@{
                                                                                     kMXKRoomDataSourceTimelineErrorErrorKey: error
                                                                                     }];
                    }];
                }
            }
            else
            {
                NSLog(@"[MXKRoomDataSource] Warning: The user does not know the room %@", _roomId);
                
                // Update here data source state if it is not already ready
                state = MXKDataSourceStateFailed;
            }
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
            {
                [self.delegate dataSource:self didStateChange:state];
            }
        }
    }
}

- (MXEvent *)lastMessage
{
    MXEvent *theLastMessage;

    // Look for the most recent message (ignore events without timestamp).
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(bubbles)
    {
        NSInteger index = bubbles.count;
        while (index--)
        {
            bubbleData = bubbles[index];
            if (bubbleData.date)
            {
                break;
            }
        }
    }

    if (bubbleData)
    {
        NSInteger index = bubbleData.events.count;
        while (index--)
        {
            theLastMessage = bubbleData.events[index];
            if (theLastMessage.originServerTs != kMXUndefinedTimestamp)
            {
                break;
            }
            theLastMessage = nil;
        }
    }

    return theLastMessage;
}

- (NSArray *)attachmentsWithThumbnail
{
    NSMutableArray *attachments = [NSMutableArray array];
    
    @synchronized(bubbles)
    {
        for (id<MXKRoomBubbleCellDataStoring> bubbleData in bubbles)
        {
            if (bubbleData.isAttachmentWithThumbnail)
            {
                [attachments addObject:bubbleData.attachment];
            }
        }
    }
    
    return attachments;
}

- (NSString *)partialTextMessage
{
    return _room.partialTextMessage;
}

- (void)setPartialTextMessage:(NSString *)partialTextMessage
{
    _room.partialTextMessage = partialTextMessage;
}

- (void)setEventsFilterForMessages:(NSArray *)eventsFilterForMessages
{
    // Remove the previous live listener
    if (liveEventsListener)
    {
        [_timeline removeListener:liveEventsListener];
        [_timeline removeListener:redactionListener];
        [_timeline removeListener:receiptsListener];
    }

    // Listen to live events only for live timeline
    // Events for past timelines come only from pagination request
    if (_isLive)
    {
        // And register a new one with the requested filter
        _eventsFilterForMessages = [eventsFilterForMessages copy];
        liveEventsListener = [_timeline listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            if (MXTimelineDirectionForwards == direction)
            {
                // Check for local echo suppression
                MXEvent *localEcho;
                if (_room.outgoingMessages.count && [event.sender isEqualToString:self.mxSession.myUser.userId])
                {
                    localEcho = [self.room pendingLocalEchoRelatedToEvent:event];
                    if (localEcho)
                    {
                        // Check whether the local echo has a timestamp (in this case, it is replaced with the actual event).
                        if (localEcho.originServerTs != kMXUndefinedTimestamp)
                        {
                            // Replace the local echo by the true event sent by the homeserver
                            [self replaceLocalEcho:localEcho.eventId withEvent:event];
                        }
                        else
                        {
                            // Remove the local echo, and process independently the true event.
                            [self replaceLocalEcho:localEcho.eventId withEvent:nil];
                            localEcho = nil;
                        }
                    }
                }

                if (nil == localEcho)
                {
                    // Process here incoming events, and outgoing events sent from another device.
                    [self queueEventForProcessing:event withRoomState:roomState direction:MXTimelineDirectionForwards];
                    [self processQueuedEvents:nil];
                }
            }
        }];

        receiptsListener = [_timeline listenToEventsOfTypes:@[kMXEventTypeStringReceipt] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {

            if (MXTimelineDirectionForwards == direction)
            {
                // Handle this read receipt
                [self didReceiveReceiptEvent:event roomState:roomState];
            }
        }];
    }

    // Register a listener to handle redaction which can affect live and past timelines
    redactionListener = [_room.liveTimeline listenToEventsOfTypes:@[kMXEventTypeStringRoomRedaction] onEvent:^(MXEvent *redactionEvent, MXTimelineDirection direction, MXRoomState *roomState) {
        
        // Consider only live redaction events
        if (direction == MXTimelineDirectionForwards)
        {
            // Do the processing on the processing queue
            dispatch_async(MXKRoomDataSource.processingQueue, ^{
                
                // Check whether a message contains the redacted event
                id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:redactionEvent.redacts];
                if (bubbleData)
                {
                    BOOL shouldRemoveBubbleData = NO;
                    BOOL hasChanged = NO;
                    MXEvent *redactedEvent = nil;

                    @synchronized (bubbleData)
                    {
                        // Retrieve the original event to redact it
                        NSArray *events = bubbleData.events;

                        for (MXEvent *event in events)
                        {
                            if ([event.eventId isEqualToString:redactionEvent.redacts])
                            {
                                // Check whether the event was not already redacted (Redaction may be handled by event timeline too).
                                if (!event.isRedactedEvent)
                                {
                                    redactedEvent = [event prune];
                                    redactedEvent.redactedBecause = redactionEvent.JSONDictionary;
                                }
                                
                                break;
                            }
                        }
                        
                        if (redactedEvent)
                        {
                            // Update bubble data
                            NSUInteger remainingEvents = [bubbleData updateEvent:redactionEvent.redacts withEvent:redactedEvent];
                            
                            hasChanged = YES;
                            
                            // Remove the bubble if there is no more events
                            shouldRemoveBubbleData = (remainingEvents == 0);
                        }
                    }
                    
                    // Check whether the bubble should be removed
                    if (shouldRemoveBubbleData)
                    {
                        [self removeCellData:bubbleData];
                    }
                    
                    if (hasChanged)
                    {
                        // Update the delegate on main thread
                        dispatch_async(dispatch_get_main_queue(), ^{

                            // Reset lastMessage if it has been redacted
                            if ([lastMessage.eventId isEqualToString:redactedEvent.eventId])
                            {
                                lastMessage = nil;
                            }

                            if (self.delegate)
                            {
                                [self.delegate dataSource:self didCellChange:nil];
                            }
                            
                            // Notify the last message may have changed
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
                            
                        });
                    }
                }
                
            });
        }
    }];
}

- (void)setFilterMessagesWithURL:(BOOL)filterMessagesWithURL
{
    _filterMessagesWithURL = filterMessagesWithURL;
    
    if (filterMessagesWithURL)
    {
        self.eventsFilterForMessages = @[kMXEventTypeStringRoomMessage];
    }
}

- (void)setEventFormatter:(MXKEventFormatter *)eventFormatter
{
    if (_eventFormatter)
    {
        // Remove observers on previous event formatter settings
        [_eventFormatter.settings removeObserver:self forKeyPath:@"showRedactionsInRoomHistory"];
        [_eventFormatter.settings removeObserver:self forKeyPath:@"showUnsupportedEventsInRoomHistory"];
    }
    
    _eventFormatter = eventFormatter;
    
    if (_eventFormatter)
    {
        // Add observer to flush stored data on settings changes
        [_eventFormatter.settings  addObserver:self forKeyPath:@"showRedactionsInRoomHistory" options:0 context:nil];
        [_eventFormatter.settings  addObserver:self forKeyPath:@"showUnsupportedEventsInRoomHistory" options:0 context:nil];
    }
}

- (void)setShowBubblesDateTime:(BOOL)showBubblesDateTime
{
    _showBubblesDateTime = showBubblesDateTime;
    
    if (self.delegate)
    {
        // Reload all the table
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)setShowTypingNotifications:(BOOL)shouldShowTypingNotifications
{
    _showTypingNotifications = shouldShowTypingNotifications;
    
    if (shouldShowTypingNotifications)
    {
        // Register on typing notif
        [self listenTypingNotifications];
    }
    else
    {
        // Remove the live listener
        if (typingNotifListener)
        {
            [_timeline removeListener:typingNotifListener];
            currentTypingUsers = nil;
            typingNotifListener = nil;
        }
    }
}

- (void)listenTypingNotifications
{
    // Remove the previous live listener
    if (typingNotifListener)
    {
        [_timeline removeListener:typingNotifListener];
        currentTypingUsers = nil;
    }
    
    // Add typing notification listener
    typingNotifListener = [_timeline listenToEventsOfTypes:@[kMXEventTypeStringTypingNotification] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState)
    {
        
        // Handle only live events
        if (direction == MXTimelineDirectionForwards)
        {
            // Retrieve typing users list
            NSMutableArray *typingUsers = [NSMutableArray arrayWithArray:_room.typingUsers];

            // Remove typing info for the current user
            NSUInteger index = [typingUsers indexOfObject:self.mxSession.myUser.userId];
            if (index != NSNotFound)
            {
                [typingUsers removeObjectAtIndex:index];
            }
            // Ignore this notification if both arrays are empty
            if (currentTypingUsers.count || typingUsers.count)
            {
                currentTypingUsers = typingUsers;
                
                if (self.delegate)
                {
                    // refresh all the table
                    [self.delegate dataSource:self didCellChange:nil];
                }
            }
        }
    }];
    
    currentTypingUsers = _room.typingUsers;
}

- (void)cancelAllRequests
{
    if (paginationRequest)
    {
        // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
        [_timeline removeListener:paginationListener];
        paginationListener = nil;
        
        [paginationRequest cancel];
        paginationRequest = nil;
    }
    
    [super cancelAllRequests];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"showRedactionsInRoomHistory" isEqualToString:keyPath] || [@"showUnsupportedEventsInRoomHistory" isEqualToString:keyPath])
    {
        // Flush the current bubble data and rebuild them
        [self reload];
    }
}

#pragma mark - Public methods
- (id<MXKRoomBubbleCellDataStoring>)cellDataAtIndex:(NSInteger)index
{
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(bubbles)
    {
        if (index < bubbles.count)
        {
            bubbleData = bubbles[index];
        }
    }
    return bubbleData;
}

- (id<MXKRoomBubbleCellDataStoring>)cellDataOfEventWithEventId:(NSString *)eventId
{
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(eventIdToBubbleMap)
    {
        bubbleData = eventIdToBubbleMap[eventId];
    }
    return bubbleData;
}

- (NSInteger)indexOfCellDataWithEventId:(NSString *)eventId
{
    NSInteger index;
    
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(eventIdToBubbleMap)
    {
        bubbleData = eventIdToBubbleMap[eventId];
    }
    
    @synchronized(bubbles)
    {
        index = [bubbles indexOfObject:bubbleData];
    }
    
    return index;
}

- (CGFloat)cellHeightAtIndex:(NSInteger)index withMaximumWidth:(CGFloat)maxWidth
{
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataAtIndex:index];
    
    // Sanity check
    if (bubbleData && self.delegate)
    {
        // Compute here height of bubble cell
        Class<MXKCellRendering> cellViewClass = [self.delegate cellViewClassForCellData:bubbleData];
        return [cellViewClass heightForCellData:bubbleData withMaximumWidth:maxWidth];
    }
    
    return 0;
}

#pragma mark - Pagination
- (void)paginate:(NSUInteger)numItems direction:(MXTimelineDirection)direction onlyFromStore:(BOOL)onlyFromStore success:(void (^)(NSUInteger addedCellNumber))success failure:(void (^)(NSError *error))failure
{
    // Check the current data source state, and the actual user membership for this room.
    if (state != MXKDataSourceStateReady || ((self.room.state.membership == MXMembershipUnknown || self.room.state.membership == MXMembershipInvite) && ![self.room.state.historyVisibility isEqualToString:kMXRoomHistoryVisibilityWorldReadable]))
    {
        // Back pagination is not available here.
        if (failure)
        {
            failure(nil);
        }
        return;
    }
    
    if (paginationRequest)
    {
        NSLog(@"[MXKRoomDataSource] paginate: a pagination is already in progress");
        if (failure)
        {
            failure(nil);
        }
        return;
    }
    
    if (NO == [_timeline canPaginate:direction])
    {
        NSLog(@"[MXKRoomDataSource] paginate: No more events to paginate");
        if (success)
        {
            success(0);
        }
    }
    
    // Define a new listener for this pagination
    paginationListener = [_timeline listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXTimelineDirection direction2, MXRoomState *roomState) {
        
        if (direction2 == direction)
        {
            [self queueEventForProcessing:event withRoomState:roomState direction:direction];
        }
        
    }];
    
    // Keep a local reference to this listener.
    id localPaginationListenerRef = paginationListener;
    
    // Launch the pagination
    paginationRequest = [_timeline paginate:numItems direction:direction onlyFromStore:onlyFromStore complete:^{
        
        // Everything went well, remove the listener
        paginationRequest = nil;
        [_timeline removeListener:paginationListener];
        paginationListener = nil;
        
        // Once done, process retrieved events
        [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
            
            if (success)
            {
                NSUInteger addedCellNb = (direction == MXTimelineDirectionBackwards) ? addedHistoryCellNb : addedLiveCellNb;
                success(addedCellNb);
            }
            
        }];
        
    } failure:^(NSError *error) {
        
        NSLog(@"[MXKRoomDataSource] paginateBackMessages fails");
        
        // Something wrong happened or the request was cancelled.
        // Check whether the request is the actual one before removing listener and handling the retrieved events.
        if (localPaginationListenerRef == paginationListener)
        {
            paginationRequest = nil;
            [_timeline removeListener:paginationListener];
            paginationListener = nil;
            
            // Process at least events retrieved from store
            [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
                
                if (failure)
                {
                    failure(error);
                }
                else if (addedHistoryCellNb && success)
                {
                    success(addedHistoryCellNb);
                }
                
            }];
        }
        
    }];
}

- (void)paginateToFillRect:(CGRect)rect direction:(MXTimelineDirection)direction withMinRequestMessagesCount:(NSUInteger)minRequestMessagesCount success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXKRoomDataSource] paginateToFillRect: %@", NSStringFromCGRect(rect));
    
    // During the first call of this method, the delegate is supposed defined.
    // This delegate may be removed whereas this method is called by itself after a pagination request.
    // The delegate is required here to be able to compute cell height (and prevent infinite loop in case of reentrancy).
    if (!self.delegate)
    {
        NSLog(@"[MXKRoomDataSource] paginateToFillRect ignored (delegate is undefined)");
        if (failure)
        {
            failure(nil);
        }
        return;
    }

    // Get the total height of cells already loaded in memory
    CGFloat minMessageHeight = CGFLOAT_MAX;
    CGFloat bubblesTotalHeight = 0;

    // Check whether data has been aldready loaded
    if (bubbles.count)
    {
        for (NSInteger i = bubbles.count - 1; i >= 0; i--)
        {
            CGFloat bubbleHeight = [self cellHeightAtIndex:i withMaximumWidth:rect.size.width];
            // Sanity check
            if (bubbleHeight)
            {
                bubblesTotalHeight += bubbleHeight;
                
                if (bubblesTotalHeight > rect.size.height)
                {
                    // No need to compute more cells heights, there are enough to fill the rect
                    NSLog(@"[MXKRoomDataSource] -> %tu already loaded bubbles are enough to fill the screen", bubbles.count - i);
                    break;
                }
                
                // Compute the minimal height an event takes
                id<MXKRoomBubbleCellDataStoring> bubbleData = bubbles[i];
                minMessageHeight = MIN(minMessageHeight, bubbleHeight / bubbleData.events.count);
            }
        }
    }
    else if (minRequestMessagesCount && [_timeline canPaginate:direction])
    {
        NSLog(@"[MXKRoomDataSource] paginateToFillRect: Prefill with data from the store");
        // Give a chance to load data from the store before doing homeserver requests
        // Reuse minRequestMessagesCount because we need to provide a number.
        [self paginate:minRequestMessagesCount direction:direction onlyFromStore:YES success:^(NSUInteger addedCellNumber) {

            // Then retry
            [self paginateToFillRect:rect direction:direction withMinRequestMessagesCount:minRequestMessagesCount success:success failure:failure];

        } failure:failure];
        return;
    }
    
    // Is there enough cells to cover all the requested height?
    if (bubblesTotalHeight < rect.size.height)
    {
        // No. Paginate to get more messages
        if ([_timeline canPaginate:direction])
        {
            // Bound the minimal height to 44
            minMessageHeight = MIN(minMessageHeight, 44);
            
            // Load messages to cover the remaining height
            // Use an extra of 50% to manage unsupported/unexpected/redated events
            NSUInteger messagesToLoad = ceil((rect.size.height - bubblesTotalHeight) / minMessageHeight * 1.5);

            // It does not worth to make a pagination request for only 1 message.
            // So, use minRequestMessagesCount
            messagesToLoad = MAX(messagesToLoad, minRequestMessagesCount);
            
            NSLog(@"[MXKRoomDataSource] paginateToFillRect: need to paginate %tu events to cover %fpx", messagesToLoad, rect.size.height - bubblesTotalHeight);
            [self paginate:messagesToLoad direction:direction onlyFromStore:NO success:^(NSUInteger addedCellNumber) {
                
                [self paginateToFillRect:rect direction:direction withMinRequestMessagesCount:minRequestMessagesCount success:success failure:failure];
                
            } failure:failure];
        }
        else
        {
            
            NSLog(@"[MXKRoomDataSource] paginateToFillRect: No more events to paginate");
            if (success)
            {
                success();
            }
        }
    }
    else
    {
        // Yes. Nothing to do
        if (success)
        {
            success();
        }
    }
}


#pragma mark - Sending
- (void)sendTextMessage:(NSString *)text success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    // Check whether the message is an emote
    BOOL isEmote = NO;
    if ([text hasPrefix:@"/me "])
    {
        isEmote = YES;
        
        // Remove "/me " string
        text = [text substringFromIndex:4];
    }
    
    // Did user use Markdown text?
    NSString *html = [_eventFormatter htmlStringFromMarkdownString:text];
    if ([html isEqualToString:text])
    {
        // No formatted string
        html = nil;
    }
    
    __block MXEvent *localEchoEvent = nil;
    __block NSString *localEchoEventId = nil;
    
    void(^onSuccess)(NSString *) = ^(NSString *eventId) {
        
        if (localEchoEventId)
        {
            [self replaceLocalEcho:localEchoEventId withEvent:localEchoEvent];
        }
        
        if (success)
        {
            success(eventId);
        }
        
    };
    
    // Make the request to the homeserver
    if (isEmote)
    {
        [_room sendEmote:text formattedText:html localEcho:&localEchoEvent success:onSuccess failure:failure];
    }
    else
    {
        [_room sendTextMessage:text formattedText:html localEcho:&localEchoEvent success:onSuccess failure:failure];
    }
    
    if (localEchoEvent)
    {
        // From here the local echo will be handled thanks to its local event id (temporary id).
        localEchoEventId = localEchoEvent.eventId;
        
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:_room.state direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendImage:(UIImage *)image success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    // Make sure the uploaded image orientation is up
    image = [MXKTools forceImageOrientationUp:image];
    
    // Only jpeg image is supported here
    NSString *mimetype = @"image/jpeg";
    NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
    
    // Shall we need to consider a thumbnail?
    UIImage *thumbnail = nil;
    if (_room.state.isEncrypted)
    {
        // Thumbnail is useful only in case of encrypted room
        thumbnail = [MXKTools reduceImage:image toFitInSize:CGSizeMake(800, 600)];
        if (thumbnail == image)
        {
            thumbnail = nil;
        }
    }
    
    [self sendImageData:imageData withImageSize:image.size mimeType:mimetype andThumbnail:thumbnail success:success failure:failure];
}

- (void)sendImage:(NSURL *)imageLocalURL mimeType:(NSString *)mimetype success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    NSData *imageData = [NSData dataWithContentsOfFile:imageLocalURL.path];
    UIImage *image = [UIImage imageWithData:imageData];
    
    // Shall we need to consider a thumbnail?
    UIImage *thumbnail = nil;
    if (_room.state.isEncrypted)
    {
        // Thumbnail is useful only in case of encrypted room
        thumbnail = [MXKTools reduceImage:image toFitInSize:CGSizeMake(800, 600)];
        if (thumbnail == image)
        {
            thumbnail = nil;
        }
    }
    
    [self sendImageData:imageData withImageSize:image.size mimeType:mimetype andThumbnail:thumbnail success:success failure:failure];
}

- (void)sendImageData:(NSData*)imageData withImageSize:(CGSize)imageSize mimeType:(NSString*)mimetype andThumbnail:(UIImage*)thumbnail success:(void (^)(NSString *eventId))success failure:(void (^)(NSError *error))failure
{
    __block MXEvent *localEchoEvent = nil;
    __block NSString *localEchoEventId = nil;
    
    void(^onSuccess)(NSString *) = ^(NSString *eventId) {
        
        if (localEchoEventId)
        {
            [self replaceLocalEcho:localEchoEventId withEvent:localEchoEvent];
        }
        
        if (success)
        {
            success(eventId);
        }
        
    };
    
    [_room sendImage:imageData withImageSize:imageSize mimeType:mimetype andThumbnail:thumbnail localEcho:&localEchoEvent success:onSuccess failure:failure];
    
    if (localEchoEvent)
    {
        // From here the local echo will be handled thanks to its local event id (temporary id).
        localEchoEventId = localEchoEvent.eventId;
        
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:_room.state direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendVideo:(NSURL *)videoLocalURL withThumbnail:(UIImage *)videoThumbnail success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    __block NSString *localEchoEventId = nil;
    
    void(^onSuccess)(NSString *) = ^(NSString *eventId) {
        
        if (localEchoEventId)
        {
            [self replaceLocalEcho:localEchoEventId withEvent:localEchoEvent];
        }
        
        if (success)
        {
            success(eventId);
        }
        
    };
    
    [_room sendVideo:videoLocalURL withThumbnail:videoThumbnail localEcho:&localEchoEvent success:onSuccess failure:failure];
    
    if (localEchoEvent)
    {
        // From here the local echo will be handled thanks to its local event id (temporary id).
        localEchoEventId = localEchoEvent.eventId;
        
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:_room.state direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendFile:(NSURL *)fileLocalURL mimeType:(NSString*)mimeType success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    __block NSString *localEchoEventId = nil;
    
    void(^onSuccess)(NSString *) = ^(NSString *eventId) {
        
        if (localEchoEventId)
        {
            [self replaceLocalEcho:localEchoEventId withEvent:localEchoEvent];
        }
        
        if (success)
        {
            success(eventId);
        }
        
    };
    
    [_room sendFile:fileLocalURL mimeType:mimeType localEcho:&localEchoEvent success:onSuccess failure:failure];
    
    if (localEchoEvent)
    {
        // From here the local echo will be handled thanks to its local event id (temporary id).
        localEchoEventId = localEchoEvent.eventId;
        
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:_room.state direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendMessageWithContent:(NSDictionary *)msgContent success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    __block NSString *localEchoEventId = nil;
    
    void(^onSuccess)(NSString *) = ^(NSString *eventId) {
        
        if (localEchoEventId)
        {
            [self replaceLocalEcho:localEchoEventId withEvent:localEchoEvent];
        }
        
        if (success)
        {
            success(eventId);
        }
        
    };
    
    // Make the request to the homeserver
    [_room sendMessageWithContent:msgContent localEcho:&localEchoEvent success:onSuccess failure:failure];
    
    if (localEchoEvent)
    {
        // From here the local echo will be handled thanks to its local event id (temporary id)
        localEchoEventId = localEchoEvent.eventId;
        
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:_room.state direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)resendEventWithEventId:(NSString *)eventId success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    MXEvent *event = [self eventWithEventId:eventId];
    
    // Sanity check
    if (!event)
    {
        return;
    }
    
    NSLog(@"[MXKRoomDataSource] resendEventWithEventId. Event: %@", event);
    
    NSString *localEchoEventId = event.eventId;
    
    void(^onSuccess)(NSString *) = ^(NSString *eventId) {
        
        if (localEchoEventId)
        {
            [self replaceLocalEcho:localEchoEventId withEvent:event];
        }
        
        if (success)
        {
            success(eventId);
        }
        
    };
    
    // Check first whether the event is encrypted
    if ([event.wireType isEqualToString:kMXEventTypeStringRoomEncrypted])
    {
        // We try here to resent an encrypted event
        // Note: we keep the existing local echo.
        [_room sendEventOfType:kMXEventTypeStringRoomEncrypted content:event.wireContent localEcho:&event success:onSuccess failure:failure];
    }
    else if ([event.type isEqualToString:kMXEventTypeStringRoomMessage])
    {
        // And retry the send the message according to its type
        NSString *msgType = event.content[@"msgtype"];
        if ([msgType isEqualToString:kMXMessageTypeText] || [msgType isEqualToString:kMXMessageTypeEmote])
        {
            // Resend the Matrix event by reusing the existing echo
            [_room sendMessageWithContent:event.content localEcho:&event success:onSuccess failure:failure];
        }
        else if ([msgType isEqualToString:kMXMessageTypeImage])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                NSString *mimetype = nil;
                if (event.content[@"info"])
                {
                    mimetype = event.content[@"info"][@"mimetype"];
                }
                
                NSString *localImagePath = [MXMediaManager cachePathForMediaWithURL:contentURL andType:mimetype inFolder:_roomId];
                UIImage* image = [MXMediaManager loadPictureFromFilePath:localImagePath];
                if (image)
                {
                    // Restart sending the image from the beginning.
                    
                    // Remove the local echo.
                    [self removeEventWithEventId:eventId];
                    
                    if (mimetype)
                    {
                        [self sendImage:[NSURL fileURLWithPath:localImagePath isDirectory:NO] mimeType:mimetype success:success failure:failure];
                    }
                    else
                    {
                        [self sendImage:image success:success failure:failure];
                    }
                }
                else
                {
                    NSLog(@"[MXKRoomDataSource] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType);
                }
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content localEcho:&event success:onSuccess failure:failure];
            }
        }
        else if ([msgType isEqualToString:kMXMessageTypeVideo])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                // TODO: Support resend on attached video when upload has been failed.
                NSLog(@"[MXKRoomDataSource] resendEventWithEventId: Warning - Unable to resend attached video (upload was not complete)");
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content localEcho:&event success:onSuccess failure:failure];
            }
        }
        else if ([msgType isEqualToString:kMXMessageTypeFile])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                NSString *mimetype = nil;
                if (event.content[@"info"])
                {
                    mimetype = event.content[@"info"][@"mimetype"];
                }
                
                if (mimetype)
                {
                    // Restart sending the image from the beginning.
                    
                    // Remove the local echo
                    [self removeEventWithEventId:eventId];
                    
                    NSString *localFilePath = [MXMediaManager cachePathForMediaWithURL:contentURL andType:mimetype inFolder:_roomId];
                    
                    [self sendFile:[NSURL fileURLWithPath:localFilePath isDirectory:NO] mimeType:mimetype success:success failure:failure];
                }
                else
                {
                    NSLog(@"[MXKRoomDataSource] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType);
                }
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content localEcho:&event success:onSuccess failure:failure];
            }
        }
        else
        {
            NSLog(@"[MXKRoomDataSource] resendEventWithEventId: Warning - Unable to resend room message of type: %@", msgType);
        }
    }
    else
    {
        NSLog(@"[MXKRoomDataSource] MXKRoomDataSource: Warning - Only resend of MXEventTypeRoomMessage is allowed. Event.type: %@", event.type);
    }
}


#pragma mark - Events management
- (MXEvent *)eventWithEventId:(NSString *)eventId
{
    MXEvent *theEvent;
    
    // First, retrieve the cell data hosting the event
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:eventId];
    if (bubbleData)
    {
        
        // Then look into the events in this cell
        for (MXEvent *event in bubbleData.events)
        {
            
            if ([event.eventId isEqualToString:eventId])
            {
                
                theEvent = event;
                break;
            }
        }
    }
    return theEvent;
}

- (void)removeEventWithEventId:(NSString *)eventId
{
    // First, retrieve the cell data hosting the event
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:eventId];
    if (bubbleData)
    {
        NSUInteger remainingEvents;
        @synchronized (bubbleData)
        {
            remainingEvents = [bubbleData removeEvent:eventId];
        }
        
        // If there is no more events in the bubble, remove it
        if (0 == remainingEvents)
        {
            [self removeCellData:bubbleData];
        }

        // Remove the event from the outgoing messages storage
        [_room removeOutgoingMessage:eventId];

        // Reset lastMessage if it has been removed
        if ([lastMessage.eventId isEqualToString:eventId])
        {
            lastMessage = nil;
        }
    
        // Update the delegate
        if (self.delegate)
        {
            [self.delegate dataSource:self didCellChange:nil];
        }
        
        // Notify the last message may have changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
}

- (void)didReceiveReceiptEvent:(MXEvent *)receiptEvent roomState:(MXRoomState *)roomState
{
    // The account may be shared between several devices.
    // so, if some messages have been read on one device, the other devices must update the unread counters
    if ([receiptEvent.readReceiptSenders indexOfObject:self.mxSession.myUser.userId] != NSNotFound)
    {
        [self refreshUnreadCounters];
        
        // the unread counter has been updated so refresh the recents
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
    
    if (self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)handleUnsentMessages
{
    // Clean outgoing messages, and add unsent ones at the end of the conversation
    NSArray<MXEvent*>* outgoingMessages = _room.outgoingMessages;
    BOOL shouldProcessQueuedEvents = NO;
    
    for (NSInteger index = 0; index < outgoingMessages.count; index++)
    {
        MXEvent *outgoingMessage = [outgoingMessages objectAtIndex:index];
        
        // Remove successfully sent messages
        if ([outgoingMessage.eventId hasPrefix:kMXRoomLocalEventIdPrefix] == NO)
        {
            [_room removeOutgoingMessage:outgoingMessage.eventId];
        }
        else
        {
            // Here the message sending has failed
            outgoingMessage.sentState = MXEventSentStateFailed;
            
            // Erase the timestamp
            outgoingMessage.originServerTs = kMXUndefinedTimestamp;
            
            [self queueEventForProcessing:outgoingMessage withRoomState:_room.state direction:MXTimelineDirectionForwards];
            shouldProcessQueuedEvents = YES;
        }
    }
    
    if (shouldProcessQueuedEvents)
    {
        [self processQueuedEvents:nil];
    }
}

- (void)lastMessageWithEventFormatter:(MXKEventFormatter*)eventFormatter onComplete:(void(^)(MXEvent *))onComplete
{
    // The last message can

    // Firstly, check if it has been cached
    if (lastMessage)
    {
        //NSLog(@"lastMessage: case #1 for %@", self.roomId);
        onComplete(lastMessage);
        return;
    }

    MXEvent *lastDisplayableEvent;
    MXEvent *event;
    MXKEventFormatterError error;

    // Secondly, search for a matching event in the outgoing messages
    @autoreleasepool
    {
        id<MXEventsEnumerator> enumerator = [[MXEventsByTypesEnumeratorOnArray alloc] initWithMessages:_room.outgoingMessages
                                                                                            andTypesIn:self.eventsFilterForMessages
                                                                            ignoreMemberProfileChanges:self.mxSession.ignoreProfileChangesDuringLastMessageProcessing];
        while ((event = enumerator.nextEvent))
        {
            // Check that the event formatter can display the event
            NSString *eventTextMessage = [eventFormatter stringFromEvent:event withRoomState:_room.state error:&error];
            if (eventTextMessage.length)
            {
                lastDisplayableEvent = event;
                //NSLog(@"lastMessage: case #2 for %@", self.roomId);
                break;
            }
        }
    }

    if (!lastDisplayableEvent)
    {
        // Thirdly, search for a matching event in the messages already in the store
        // for this room
        @autoreleasepool
        {
            id<MXEventsEnumerator>  enumerator = [self.room enumeratorForStoredMessagesWithTypeIn:self.eventsFilterForMessages
                                               ignoreMemberProfileChanges:self.mxSession.ignoreProfileChangesDuringLastMessageProcessing];

            while ((event = enumerator.nextEvent))
            {
                // Decrypt event if necessary
                // TODO: it should be done by the sdk (https://github.com/matrix-org/matrix-ios-sdk/issues/161)
                if (event.eventType == MXEventTypeRoomEncrypted)
                {
                    if (![self.mxSession decryptEvent:event inTimeline:nil])
                    {
                        NSLog(@"[MXKRoomDataSource] lastMessageWithEventFormatter: Warning: Unable to decrypt event: %@\nError: %@", event.content[@"body"], event.decryptionError);
                    }
                }

                // Check that the event formatter can display the event
                NSString *eventTextMessage = [eventFormatter stringFromEvent:event withRoomState:_room.state error:&error];
                if (eventTextMessage.length)
                {
                    lastDisplayableEvent = event;
                    //NSLog(@"lastMessage: case #3 for %@", self.roomId);
                    break;
                }
            }
        }
    }

    if (lastDisplayableEvent)
    {
        // Cache it for future reuse
        lastMessage = lastDisplayableEvent;
        onComplete(lastDisplayableEvent);
    }
    else
    {
        if ([_timeline canPaginate: MXTimelineDirectionBackwards])
        {
            // Finally, as there is no matching events locally, get more messages from 
            // the homeserver
            //NSLog(@"lastMessage: case #4 for %@", self.roomId);

            // Trigger asynchronously this back pagination to not block the UI thread.
            dispatch_async(dispatch_get_main_queue(), ^{

                // Make the data source load more messages than available in the store to
                // force it to get them from the homeserver
                [self paginate:(self.room.storedMessagesCount + 30) direction:MXTimelineDirectionBackwards onlyFromStore:NO success:^(NSUInteger addedCellNumber) {

                    [self lastMessageWithEventFormatter:eventFormatter onComplete:onComplete];

                } failure:^(NSError *error) {
                    
                    onComplete(nil);
                    
                }];
            });
        }
        else
        {
            // All the room history has been loaded locally but no message matches the
            // criteria
            //NSLog(@"lastMessage: case #5 for %@", self.roomId);
            onComplete(nil);
        }
    }
}

#pragma mark - Private methods

- (void)replaceLocalEcho:(NSString*)localEchoEventId withEvent:(MXEvent*)event
{
    // Remove the event from the pending local echo list if any.
    [self.room removePendingLocalEcho:localEchoEventId];
    
    // Retrieve the cell data hosting the local echo
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:localEchoEventId];
    if (!bubbleData)
    {
        return;
    }
    
    NSUInteger remainingEvents;
    @synchronized (bubbleData)
    {
        // Check whether the local echo is replaced or removed
        if (event)
        {
            remainingEvents = [bubbleData updateEvent:localEchoEventId withEvent:event];
        }
        else
        {
            remainingEvents = [bubbleData removeEvent:localEchoEventId];
        }
    }
    
    // Update bubbles mapping
    @synchronized (eventIdToBubbleMap)
    {
        // Remove the broken link from the map
        [eventIdToBubbleMap removeObjectForKey:localEchoEventId];
        
        if (event && remainingEvents)
        {
            eventIdToBubbleMap[event.eventId] = bubbleData;
        }
    }
    
    // If there is no more events in the bubble, remove it
    if (0 == remainingEvents)
    {
        [self removeCellData:bubbleData];
    }
    
    // Update lastMessage if it has been replaced
    if ([lastMessage.eventId isEqualToString:localEchoEventId])
    {
        // The new event should have the same characteristics as localEcho: it should
        // match [self lastMessageWithEventFormatter:] criteria and can replace it as
        // as the last message
        lastMessage = event;
    }
    
    // Update the delegate
    if (self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
    
    // Notify the last message may have changed
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
}

- (NSArray<NSIndexPath *> *)removeCellData:(id<MXKRoomBubbleCellDataStoring>)cellData
{
    NSMutableArray *deletedRows = [NSMutableArray array];
    
    // Remove potential occurrences in bubble map
    @synchronized (eventIdToBubbleMap)
    {
        for (MXEvent *event in cellData.events)
        {
            [eventIdToBubbleMap removeObjectForKey:event.eventId];
        }
    }
    
    // Check whether the adjacent bubbles can merge together
    @synchronized(bubbles)
    {
        NSUInteger index = [bubbles indexOfObject:cellData];
        if (index != NSNotFound)
        {
            [bubbles removeObjectAtIndex:index];
            [deletedRows addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            
            if (bubbles.count)
            {
                // Update flag in remaining data
                if (index == 0)
                {
                    // We removed here the first bubble.
                    // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the new first bubble.
                    id<MXKRoomBubbleCellDataStoring> firstCellData = bubbles.firstObject;
                    
                    firstCellData.isPaginationFirstBubble = ((self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay) && firstCellData.date);
                    firstCellData.shouldHideSenderInformation = NO;
                }
                else if (index < bubbles.count)
                {
                    // We removed here a bubble which is not the before last.
                    id<MXKRoomBubbleCellDataStoring> cellData1 = bubbles[index-1];
                    id<MXKRoomBubbleCellDataStoring> cellData2 = bubbles[index];
                    
                    // Check first whether the neighbor bubbles can merge
                    Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
                    if ([class instancesRespondToSelector:@selector(mergeWithBubbleCellData:)])
                    {
                        if ([cellData1 mergeWithBubbleCellData:cellData2])
                        {
                            [bubbles removeObjectAtIndex:index];
                            [deletedRows addObject:[NSIndexPath indexPathForRow:(index + 1) inSection:0]];
                            
                            cellData2 = nil;
                        }
                    }
                    
                    if (cellData2)
                    {
                        // Update its 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags
                        
                        // Pagination handling
                        if (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay && !cellData2.isPaginationFirstBubble)
                        {
                            // Check whether a new pagination starts on the second cellData
                            NSString *cellData1DateString = [self.eventFormatter dateStringFromDate:cellData1.date withTime:NO];
                            NSString *cellData2DateString = [self.eventFormatter dateStringFromDate:cellData2.date withTime:NO];
                            
                            if (!cellData1DateString)
                            {
                                cellData2.isPaginationFirstBubble = (cellData2DateString && cellData.isPaginationFirstBubble);
                            }
                            else
                            {
                                cellData2.isPaginationFirstBubble = (cellData2DateString && ![cellData2DateString isEqualToString:cellData1DateString]);
                            }
                        }
                        
                        // Check whether the sender information is relevant for this bubble.
                        cellData2.shouldHideSenderInformation = NO;
                        if (cellData2.isPaginationFirstBubble == NO)
                        {
                            // Check whether the neighbor bubbles have been sent by the same user.
                            cellData2.shouldHideSenderInformation = [cellData2 hasSameSenderAsBubbleCellData:cellData1];
                        }
                    }

                }
            }
        }
    }
    
    return deletedRows;
}

- (void)didMXRoomInitialSynced:(NSNotification *)notif
{
    // Refresh the room data source when the room has been initialSync'ed
    MXRoom *room = notif.object;
    if (self.mxSession == room.mxSession && [self.roomId isEqualToString:room.state.roomId])
    { 
        NSLog(@"[MXKRoomDataSource] didMXRoomInitialSynced for room: %@", _roomId);
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomInitialSyncNotification object:nil];
        
        [self reload];
    }
}

- (void)eventDidChangeSentState:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    if ([event.roomId isEqualToString:_roomId])
    {
        // Retrieve the cell data hosting the local echo
        id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:event.eventId];
        if (!bubbleData)
        {
            return;
        }
        
        @synchronized (bubbleData)
        {
            [bubbleData updateEvent:event.eventId withEvent:event];
        }
        
        // Inform the delegate
        if (self.delegate)
        {
            [self.delegate dataSource:self didCellChange:nil];
        }
        
        // Notify the last message may have changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
}

- (void)eventDidDecrypt:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    if ([event.roomId isEqualToString:_roomId])
    {
        // Retrieve the cell data hosting the event
        id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:event.eventId];
        if (!bubbleData)
        {
            return;
        }

        // We need to update the data of the cell that displays the event.
        // The trickiest update is when the cell contains several events and the event
        // to update turns out to be an attachment.
        // In this case, we need to split the cell into several cells so that the attachment
        // has its own cell.
        if (bubbleData.events.count == 1 || ![_eventFormatter isSupportedAttachment:event])
        {
            // If the event is still a text, a simple update is enough
            // If the event is an attachment, it has already its own cell. Let the bubble
            // data handle the type change.
            @synchronized (bubbleData)
            {
                [bubbleData updateEvent:event.eventId withEvent:event];
            }
        }
        else
        {
            @synchronized (bubbleData)
            {
                BOOL eventIsFirstInBubble = NO;
                NSInteger bubbleDataIndex =  [bubbles indexOfObject:bubbleData];

                // We need to create a dedicated cell for the event attachment.
                // From the current bubble, remove the updated event and all events after.
                NSMutableArray<MXEvent*> *removedEvents;
                NSUInteger remainingEvents = [bubbleData removeEventsFromEvent:event.eventId removedEvents:&removedEvents];

                // If there is no more events in this bubble, remove it
                if (0 == remainingEvents)
                {
                    eventIsFirstInBubble = YES;
                    @synchronized (eventsToProcessSnapshot)
                    {
                        [bubbles removeObjectAtIndex:bubbleDataIndex];
                        bubbleDataIndex--;
                    }
                }

                // Create a dedicated bubble for the attachment
                if (removedEvents.count)
                {
                    Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];

                    id<MXKRoomBubbleCellDataStoring> newBubbleData = [[class alloc] initWithEvent:removedEvents[0] andRoomState:self.room.state andRoomDataSource:self];

                    if (eventIsFirstInBubble)
                    {
                        // Apply same config as before
                        newBubbleData.isPaginationFirstBubble = bubbleData.isPaginationFirstBubble;
                        newBubbleData.shouldHideSenderInformation = bubbleData.shouldHideSenderInformation;
                    }
                    else
                    {
                        // This new bubble is not the first. Show nothing
                        newBubbleData.isPaginationFirstBubble = NO;
                        newBubbleData.shouldHideSenderInformation = YES;
                    }

                    // Update bubbles mapping
                    @synchronized (eventIdToBubbleMap)
                    {
                        eventIdToBubbleMap[event.eventId] = newBubbleData;
                    }

                    @synchronized (eventsToProcessSnapshot)
                    {
                        [bubbles insertObject:newBubbleData atIndex:bubbleDataIndex + 1];
                    }
                }

                // And put other cutted events in another bubble
                if (removedEvents.count > 1)
                {
                    Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];

                    id<MXKRoomBubbleCellDataStoring> newBubbleData;
                    for (NSUInteger i = 1; i < removedEvents.count; i++)
                    {
                        MXEvent *removedEvent = removedEvents[i];
                        if (i == 1)
                        {
                            newBubbleData = [[class alloc] initWithEvent:removedEvent andRoomState:self.room.state andRoomDataSource:self];
                        }
                        else
                        {
                            [newBubbleData addEvent:removedEvent andRoomState:self.room.state];
                        }

                        // Update bubbles mapping
                        @synchronized (eventIdToBubbleMap)
                        {
                            eventIdToBubbleMap[removedEvent.eventId] = newBubbleData;
                        }
                    }

                    // Do not show the
                    newBubbleData.isPaginationFirstBubble = NO;
                    newBubbleData.shouldHideSenderInformation = YES;

                    @synchronized (eventsToProcessSnapshot)
                    {
                        [bubbles insertObject:newBubbleData atIndex:bubbleDataIndex + 2];
                    }
                }
            }
        }

        // Update lastMessage if it has been replaced
        if ([lastMessage.eventId isEqualToString:event.eventId])
        {
            // The new event should have the same characteristics as localEcho: it should
            // match [self lastMessageWithEventFormatter:] criteria and can replace it as
            // as the last message
            lastMessage = event;
        }

        // Update the delegate
        if (self.delegate)
        {
            [self.delegate dataSource:self didCellChange:nil];
        }

        // Notify the last message may have changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
}


#pragma mark - Asynchronous events processing
/**
 The dispatch queue to process room messages.
 This processing can consume time. Handling it on a separated thread avoids to block the main thread.
 All MXKRoomDataSource instances share the same dispatch queue.
 */
 + (dispatch_queue_t)processingQueue
{
    static dispatch_queue_t processingQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processingQueue = dispatch_queue_create("MXKRoomDataSource", DISPATCH_QUEUE_SERIAL);
    });

    return processingQueue;
}

/**
 Queue an event in order to process its display later.
 
 @param event the event to process.
 @param roomState the state of the room when the event fired.
 @param direction the order of the events in the arrays
 */
- (void)queueEventForProcessing:(MXEvent*)event withRoomState:(MXRoomState*)roomState direction:(MXTimelineDirection)direction
{
    if (self.filterMessagesWithURL)
    {
        // Check whether the event has a value for the 'url' key in its content.
        if (!event.content[@"url"])
        {
            // Ignore the event
            return;
        }
    }
    
    MXKQueuedEvent *queuedEvent = [[MXKQueuedEvent alloc] initWithEvent:event andRoomState:roomState direction:direction];
    
    // Count queued events when the server sync is in progress
    if (self.mxSession.state == MXSessionStateSyncInProgress)
    {
        queuedEvent.serverSyncEvent = YES;
        _serverSyncEventCount++;
        
        if (_serverSyncEventCount == 1)
        {
            // Notify that sync process starts
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceSyncStatusChanged object:self userInfo:nil];
        }
    }
    
    @synchronized(eventsToProcess)
    {
        [eventsToProcess addObject:queuedEvent];
    }
}

- (BOOL)checkBing:(MXEvent*)event
{
    BOOL isHighlighted = NO;
    
    // read receipts have no rule
    if (![event.type isEqualToString:kMXEventTypeStringReceipt]) {
        // Check if we should bing this event
        MXPushRule *rule = [self.mxSession.notificationCenter ruleMatchingEvent:event];
        if (rule)
        {
            // Check whether is there an highlight tweak on it
            for (MXPushRuleAction *ruleAction in rule.actions)
            {
                if (ruleAction.actionType == MXPushRuleActionTypeSetTweak)
                {
                    if ([ruleAction.parameters[@"set_tweak"] isEqualToString:@"highlight"])
                    {
                        // Check the highlight tweak "value"
                        // If not present, highlight. Else check its value before highlighting
                        if (nil == ruleAction.parameters[@"value"] || YES == [ruleAction.parameters[@"value"] boolValue])
                        {
                            isHighlighted = YES;
                            break;
                        }
                    }
                }
            }
        }
    }
    
    event.mxkIsHighlighted = isHighlighted;
    return isHighlighted;
}

/**
 Start processing pending events.
 
 @param onComplete a block called (on the main thread) when the processing has been done. Can be nil.
 Note this block returns the number of added cells in first and last positions.
 */
- (void)processQueuedEvents:(void (^)(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb))onComplete
{
    // Do the processing on the processing queue
    dispatch_async(MXKRoomDataSource.processingQueue, ^{
        
        // Note: As this block is always called from the same processing queue,
        // only one batch process is done at a time. Thus, an event cannot be
        // processed twice
        
        // Snapshot queued events to avoid too long lock.
        @synchronized(eventsToProcess)
        {
            if (eventsToProcess.count)
            {
                eventsToProcessSnapshot = eventsToProcess;
                eventsToProcess = [NSMutableArray array];
            }
        }

        NSUInteger serverSyncEventCount = 0;
        NSUInteger addedHistoryCellCount = 0;
        NSUInteger addedLiveCellCount = 0;
        BOOL lastMessageHasChanged = NO;
        
        // Lock on `eventsToProcessSnapshot` to suspend reload or destroy during the process.
        @synchronized(eventsToProcessSnapshot)
        {
            // Is there events to process?
            // The list can be empty because several calls of processQueuedEvents may be processed
            // in one pass in the processingQueue
            if (eventsToProcessSnapshot.count)
            {
                // Make a quick copy of changing data to avoid to lock it too long time
                @synchronized(bubbles)
                {
                    bubblesSnapshot = [bubbles mutableCopy];
                }
                
                for (MXKQueuedEvent *queuedEvent in eventsToProcessSnapshot)
                {
                    @autoreleasepool
                    {
                        // Count events received while the server sync was in progress
                        if (queuedEvent.serverSyncEvent)
                        {
                            serverSyncEventCount ++;
                        }

                        // Check whether the event must be highlighted
                        [self checkBing:queuedEvent.event];

                        // Retrieve the MXKCellData class to manage the data
                        Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
                        NSAssert([class conformsToProtocol:@protocol(MXKRoomBubbleCellDataStoring)], @"MXKRoomDataSource only manages MXKCellData that conforms to MXKRoomBubbleCellDataStoring protocol");

                        BOOL eventManaged = NO;
                        id<MXKRoomBubbleCellDataStoring> bubbleData;
                        if ([class instancesRespondToSelector:@selector(addEvent:andRoomState:)] && 0 < bubblesSnapshot.count)
                        {
                            // Try to concatenate the event to the last or the oldest bubble?
                            if (queuedEvent.direction == MXTimelineDirectionBackwards)
                            {
                                bubbleData = bubblesSnapshot.firstObject;
                            }
                            else
                            {
                                bubbleData = bubblesSnapshot.lastObject;
                            }

                            @synchronized (bubbleData)
                            {
                                eventManaged = [bubbleData addEvent:queuedEvent.event andRoomState:queuedEvent.state];
                            }
                        }

                        if (NO == eventManaged)
                        {
                            // The event has not been concatenated to an existing cell, create a new bubble for this event
                            bubbleData = [[class alloc] initWithEvent:queuedEvent.event andRoomState:queuedEvent.state andRoomDataSource:self];
                            if (!bubbleData)
                            {
                                // The event is ignored
                                continue;
                            }

                            if (queuedEvent.direction == MXTimelineDirectionBackwards)
                            {
                                // The new bubble data will be inserted at first position.
                                // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the current first bubble.

                                // Pagination handling
                                if ((self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay) && bubbleData.date)
                                {
                                    // A new pagination starts with this new bubble data
                                    bubbleData.isPaginationFirstBubble = YES;

                                    // Check whether the current first displayed pagination title is still relevant.
                                    if (bubblesSnapshot.count)
                                    {
                                        NSInteger index = 0;
                                        id<MXKRoomBubbleCellDataStoring> previousFirstBubbleDataWithDate;
                                        NSString *firstBubbleDateString;
                                        while (index < bubblesSnapshot.count)
                                        {
                                            previousFirstBubbleDataWithDate = bubblesSnapshot[index++];
                                            firstBubbleDateString = [self.eventFormatter dateStringFromDate:previousFirstBubbleDataWithDate.date withTime:NO];
                                            
                                            if (firstBubbleDateString)
                                            {
                                                break;
                                            }
                                        }
                                        
                                        if (firstBubbleDateString)
                                        {
                                            NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                            previousFirstBubbleDataWithDate.isPaginationFirstBubble = (bubbleDateString && ![firstBubbleDateString isEqualToString:bubbleDateString]);
                                        }
                                    }
                                }
                                else
                                {
                                    bubbleData.isPaginationFirstBubble = NO;
                                }

                                // Sender information are required for this new first bubble data
                                bubbleData.shouldHideSenderInformation = NO;

                                // Check whether this information is relevant for the current first bubble.
                                if (bubblesSnapshot.count)
                                {
                                    id<MXKRoomBubbleCellDataStoring> previousFirstBubbleData = bubblesSnapshot.firstObject;

                                    if (previousFirstBubbleData.isPaginationFirstBubble == NO)
                                    {
                                        // Check whether the current first bubble has been sent by the same user.
                                        previousFirstBubbleData.shouldHideSenderInformation = [previousFirstBubbleData hasSameSenderAsBubbleCellData:bubbleData];
                                    }
                                }

                                // Insert the new bubble data in first position
                                [bubblesSnapshot insertObject:bubbleData atIndex:0];
                                
                                addedHistoryCellCount++;
                            }
                            else
                            {
                                // The new bubble data will be added at the last position
                                // We have to update its 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags according to the previous last bubble.

                                // Pagination handling
                                if (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay)
                                {
                                    // Check whether a new pagination starts at this bubble
                                    NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                    
                                    // Look for the current last bubble with date
                                    NSInteger index = bubblesSnapshot.count;
                                    NSString *lastBubbleDateString;
                                    while (index--)
                                    {
                                        id<MXKRoomBubbleCellDataStoring> previousLastBubbleData = bubblesSnapshot[index];
                                        lastBubbleDateString = [self.eventFormatter dateStringFromDate:previousLastBubbleData.date withTime:NO];
                                        
                                        if (lastBubbleDateString)
                                        {
                                            break;
                                        }
                                    }
                                    
                                    if (lastBubbleDateString)
                                    {
                                        bubbleData.isPaginationFirstBubble = (bubbleDateString && ![bubbleDateString isEqualToString:lastBubbleDateString]);
                                    }
                                    else
                                    {
                                        bubbleData.isPaginationFirstBubble = (bubbleDateString != nil);
                                    }
                                }
                                else
                                {
                                    bubbleData.isPaginationFirstBubble = NO;
                                }

                                // Check whether the sender information is relevant for this new bubble.
                                bubbleData.shouldHideSenderInformation = NO;
                                if (bubblesSnapshot.count && (bubbleData.isPaginationFirstBubble == NO))
                                {
                                    // Check whether the previous bubble has been sent by the same user.
                                    id<MXKRoomBubbleCellDataStoring> previousLastBubbleData = bubblesSnapshot.lastObject;
                                    bubbleData.shouldHideSenderInformation = [bubbleData hasSameSenderAsBubbleCellData:previousLastBubbleData];
                                }

                                // Insert the new bubble in last position
                                [bubblesSnapshot addObject:bubbleData];
                                
                                addedLiveCellCount++;
                            }
                        }
                        
                        // Store event-bubble link to the map
                        @synchronized (eventIdToBubbleMap)
                        {
                            eventIdToBubbleMap[queuedEvent.event.eventId] = bubbleData;
                        }
                    }

                    if (queuedEvent.direction == MXTimelineDirectionForwards)
                    {
                        // There is a new last message
                        lastMessageHasChanged = YES;
                    }
                }
            }
            eventsToProcessSnapshot = nil;
        }
        
        // Check whether some events have been processed
        if (bubblesSnapshot)
        {
            // Updated data can be displayed now
            // Block MXKRoomDataSource.processingQueue while the processing is finalised on the main thread
            dispatch_sync(dispatch_get_main_queue(), ^{

                // Reset the last message cache if new live events have been received
                if (lastMessageHasChanged)
                {
                    lastMessage = nil;
                }

                // Check whether self has not been reloaded or destroyed
                if (self.state == MXKDataSourceStateReady && bubblesSnapshot)
                {
                    if (_serverSyncEventCount)
                    {
                        _serverSyncEventCount -= serverSyncEventCount;
                        if (!_serverSyncEventCount)
                        {
                            // Notify that sync process ends
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceSyncStatusChanged object:self userInfo:nil];
                        }
                    }
                    
                    bubbles = bubblesSnapshot;
                    bubblesSnapshot = nil;
                    
                    if (self.delegate)
                    {
                        [self.delegate dataSource:self didCellChange:nil];
                    }
                    else
                    {
                        // Check the memory usage of the data source. Reload it if the cache is too huge.
                        [self limitMemoryUsage:_maxBackgroundCachedBubblesCount];
                    }
                    
                    // Notify the last message, hasUnread, notificationCount and/or highlightCount have changed
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
                }
                
                // Inform about the end if requested
                if (onComplete)
                {
                    onComplete(addedHistoryCellCount, addedLiveCellCount);
                }
            });
        }
        else
        {
            // No new event has been added, we just inform about the end if requested.
            if (onComplete)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    onComplete(0, 0);
                });
            }
        }
    });
}


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // PATCH: Presently no bubble must be displayed until the user joins the room.
    // FIXME: Handle room data source in case of room preview
    if (self.room.state.membership == MXMembershipInvite)
    {
        return 0;
    }
    
    NSInteger count;
    @synchronized(bubbles)
    {
        count = bubbles.count;
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell<MXKCellRendering> *cell;
    
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataAtIndex:indexPath.row];
    
    if (bubbleData && self.delegate)
    {
        // Retrieve the cell identifier according to cell data.
        NSString *identifier = [self.delegate cellReuseIdentifierForCellData:bubbleData];
        if (identifier)
        {
            cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
            
            // Make sure we listen to user actions on the cell
            cell.delegate = self;
            
            // Update typing flag before rendering
            bubbleData.isTyping = _showTypingNotifications && currentTypingUsers && ([currentTypingUsers indexOfObject:bubbleData.senderId] != NSNotFound);
            // Report the current timestamp display option
            bubbleData.showBubbleDateTime = self.showBubblesDateTime;
            // display the read receipts
            bubbleData.showBubbleReceipts = self.showBubbleReceipts;
            // let the caller application manages the time label?
            bubbleData.useCustomDateTimeLabel = self.useCustomDateTimeLabel;
            // let the caller application manages the receipt?
            bubbleData.useCustomReceipts = self.useCustomReceipts;
            // let the caller application manages the unsent button?
            bubbleData.useCustomUnsentButton = self.useCustomUnsentButton;
            
            // Make the bubble display the data
            [cell render:bubbleData];
        }
    }
    
    // Sanity check: this method may be called during a layout refresh while room data have been modified.
    if (!cell)
    {
        // Return an empty cell
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fakeCell"];
    }
    
    return cell;
}

@end
