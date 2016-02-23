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

#import "NSData+MatrixKit.h"

#pragma mark - Constant definitions

NSString *const kMXKRoomBubbleCellDataIdentifier = @"kMXKRoomBubbleCellDataIdentifier";

NSString *const kMXKRoomDataSourceMetaDataChanged = @"kMXKRoomDataSourceMetaDataChanged";
NSString *const kMXKRoomDataSourceSyncStatusChanged = @"kMXKRoomDataSourceSyncStatusChanged";

@interface MXKRoomDataSource ()
{
    /**
     Current back pagination request (if any)
     */
    MXHTTPOperation *backPaginationRequest;
    
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
     Observe UIApplicationSignificantTimeChangeNotification to trigger cell change on time formatting change.
     */
    id UIApplicationSignificantTimeChangeNotificationObserver;
    
    /**
     Observe NSCurrentLocaleDidChangeNotification to trigger cell change on time formatting change.
     */
    id NSCurrentLocaleDidChangeNotificationObserver;
    
    /**
     Observe kMXRoomSyncWithLimitedTimelineNotification to trigger cell change when existing room history has been flushed during server sync v2.
     */
    id roomSyncWithLimitedTimelineNotification;
}

@end

@implementation MXKRoomDataSource

- (instancetype)initWithRoomId:(NSString *)roomId andMatrixSession:(MXSession *)matrixSession
{
    self = [super initWithMatrixSession:matrixSession];
    if (self)
    {
        NSLog(@"[MXKRoomDataSource] initWithRoomId %p - room id: %@", self, roomId);
        
        _roomId = roomId;
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
        
        // Check here whether the app user wants to display all the events
        if ([[MXKAppSettings standardAppSettings] showAllEventsInRoomHistory])
        {
            // Use a filter to retrieve all the events (except kMXEventTypeStringPresence which are not related to a specific room)
            self.eventsFilterForMessages = @[
                                             kMXEventTypeStringRoomName,
                                             kMXEventTypeStringRoomTopic,
                                             kMXEventTypeStringRoomMember,
                                             kMXEventTypeStringRoomCreate,
                                             kMXEventTypeStringRoomJoinRules,
                                             kMXEventTypeStringRoomPowerLevels,
                                             kMXEventTypeStringRoomAliases,
                                             kMXEventTypeStringRoomMessage,
                                             kMXEventTypeStringRoomMessageFeedback,
                                             kMXEventTypeStringRoomRedaction,
                                             kMXEventTypeStringRoomThirdPartyInvite,
                                             kMXEventTypeStringCallInvite
                                             ];
        }
        else
        {
            // Display only a subset of events
            self.eventsFilterForMessages = @[
                                             kMXEventTypeStringRoomName,
                                             kMXEventTypeStringRoomTopic,
                                             kMXEventTypeStringRoomMember,
                                             kMXEventTypeStringRoomMessage,
                                             kMXEventTypeStringRoomThirdPartyInvite,
                                             kMXEventTypeStringCallInvite
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
        
        roomSyncWithLimitedTimelineNotification = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomSyncWithLimitedTimelineNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            MXRoom *room = notif.object;
            if (self.mxSession == room.mxSession && [self.roomId isEqualToString:room.state.roomId])
            {
                // The existing room history has been flushed during server sync v2 because a gap has been observed between local and server storage. 
                [self reload];
            }
        }];
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

- (void)refreshUnreadCounters:(BOOL)refreshBingCounter
{
    // always highlight invitation message.
    // if the room is joined from another device
    // this state will be updated so the standard read receipts management will be applied.
    if (MXMembershipInvite == _room.state.membership)
    {
        _unreadCount = 1;
        _unreadBingCount = 0;
    }
    else
    {
        NSArray* list = [_room unreadEvents];
        if (_unreadCount != list.count)
        {
            _unreadCount = list.count;
            
            // Note: check bing takes time, so we allow bing counter refresh only when the unread count has changed
            // and the caller has enabled the refresh ('refreshBingCounter' boolean).
            if (refreshBingCounter)
            {
                _unreadBingCount = 0;
                
                for (MXEvent* event in list)
                {
                    if ([self checkBing:event])
                    {
                        _unreadBingCount++;
                    }
                }
            }
        }
    }
}

- (void)markAllAsRead
{
    if ([_room acknowledgeLatestEvent:YES])
    {
        _unreadCount = 0;
        _unreadBingCount = 0;
        
        // Notify the unreadCount has changed
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
        // Unfortunately, the outgoing events in the store do not keep their mxkState.
        // So, we need to check the mxkState of the events currently displayed (the events in 'bubbles')
        if (_room.outgoingMessages.count)
        {
            @synchronized(bubbles)
            {
                // Do the search from the end to improve it
                for (NSInteger i = bubbles.count - 1; i >= 0; i--)
                {
                    id<MXKRoomBubbleCellDataStoring> bubbleData = bubbles[i];
                    for (NSInteger j = bubbleData.events.count - 1; j >= 0; j--)
                    {
                        MXEvent *event = bubbleData.events[j];
                        if (event.mxkState == MXKEventStateSending)
                        {
                            NSLog(@"[MXKRoomDataSource] cancel limitMemoryUsage because some messages are being sent");
                            return;
                        }
                    }
                }
            }
        }

        // Reset the room data source (return in initial state: minimum memory usage).
        [self reload];
    }
}

- (void)reset
{
    if (backPaginationRequest)
    {
        [backPaginationRequest cancel];
        backPaginationRequest = nil;
    }
    
    if (_room && liveEventsListener)
    {
        [_room.liveTimeline removeListener:liveEventsListener];
        liveEventsListener = nil;
        
        [_room.liveTimeline removeListener:redactionListener];
        redactionListener = nil;
        
        [_room.liveTimeline removeListener:receiptsListener];
        receiptsListener = nil;
    }
    
    if (_room && typingNotifListener)
    {
        [_room.liveTimeline removeListener:typingNotifListener];
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
        
        _room = nil;
    }
    
    _serverSyncEventCount = 0;
    _unreadCount = 0;
    _unreadBingCount = 0;

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
    
    // Flush the current bubble data by keeping the current unread counts (to reduce computation time, indeed check bing takes time).
    NSUInteger unreadCount = _unreadCount;
    NSUInteger unreadBingCount = _unreadBingCount;
    
    [self reset];
    
    _unreadCount = unreadCount;
    _unreadBingCount = unreadBingCount;
    
    // Reload
    [self didMXSessionStateChange];
    
    // Handle here the case where reload has failed (should not happen except if session has been closed).
    if (state != MXKDataSourceStateReady)
    {
        NSLog(@"[MXKRoomDataSource] Reload Failed (%p - room id: %@)", self, _roomId);
        
        _unreadCount = 0;
        _unreadBingCount = 0;
        
        // Notify the last message, unreadCount and/or unreadBingCount have changed
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    }
}

- (void)destroy
{
    NSLog(@"[MXKRoomDataSource] Destroy %p - room id: %@", self, _roomId);
    
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
    
    if (roomSyncWithLimitedTimelineNotification)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomSyncWithLimitedTimelineNotification];
        roomSyncWithLimitedTimelineNotification = nil;
    }
    
    [self reset];
    
    self.eventFormatter = nil;
    
    eventsToProcess = nil;
    bubbles = nil;
    eventIdToBubbleMap = nil;
    
    [super destroy];
}

- (void)didMXSessionStateChange
{
    if (MXSessionStateStoreDataReady <= self.mxSession.state)
    {
        // Check whether the room is not already set
        if (!_room)
        {
            _room = [self.mxSession roomWithRoomId:_roomId];
            if (_room)
            {
                // Only one pagination process can be done at a time by an MXRoom object.
                // This assumption is satisfied by MatrixKit. Only MXRoomDataSource does it.
                [_room.liveTimeline resetBackState];
                
                [self refreshUnreadCounters:YES];
                
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
    MXEvent *lastMessage;
    
    id<MXKRoomBubbleCellDataStoring> lastBubbleData = bubbles.lastObject;
    if (lastBubbleData)
    {
        lastMessage = lastBubbleData.events.lastObject;
    }
    else
    {
        // If no bubble was loaded yet, use MXRoom data
        lastMessage = [_room lastMessageWithTypeIn:_eventsFilterForMessages];
        // Check if this event is a bing event
        [self checkBing:lastMessage];
    }
    return lastMessage;
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
        [_room.liveTimeline removeListener:liveEventsListener];
        [_room.liveTimeline removeListener:redactionListener];
        [_room.liveTimeline removeListener:receiptsListener];
    }
    
    // And register a new one with the requested filter
    _eventsFilterForMessages = [eventsFilterForMessages copy];
    liveEventsListener = [_room.liveTimeline listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
    {
        if (MXEventDirectionForwards == direction)
        {
            // Check for local echo suppression
            MXEvent *localEcho;
            if (_room.outgoingMessages.count && [event.sender isEqualToString:self.mxSession.myUser.userId])
            {
                localEcho = [self pendingLocalEchoRelatedToEvent:event];
                if (localEcho)
                {
                    // Replace the local echo by the true event sent by the homeserver
                    [self replaceLocalEcho:localEcho withEvent:event];
                }
            }
            
            if (nil == localEcho)
            {
                // Post incoming events for later processing
                [self queueEventForProcessing:event withRoomState:roomState direction:MXEventDirectionForwards];
                [self processQueuedEvents:nil];
            }
        }
    }];
    
    
    receiptsListener = [_room.liveTimeline listenToEventsOfTypes:@[kMXEventTypeStringReceipt] onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState) {
        
        if (MXEventDirectionForwards == direction)
        {
            // Handle this read receipt
            [self didReceiveReceiptEvent:event roomState:roomState];
        }
    }];
    
    // Register a listener to handle redaction in live stream
    redactionListener = [_room.liveTimeline listenToEventsOfTypes:@[kMXEventTypeStringRoomRedaction] onEvent:^(MXEvent *redactionEvent, MXEventDirection direction, MXRoomState *roomState) {
        
        // Consider only live redaction events
        if (direction == MXEventDirectionForwards)
        {
            // Do the processing on the processing queue
            dispatch_async(MXKRoomDataSource.processingQueue, ^{
                
                // Check whether a message contains the redacted event
                id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:redactionEvent.redacts];
                if (bubbleData)
                {
                    NSUInteger remainingEvents = 0;
                    
                    @synchronized (bubbleData)
                    {
                        // Retrieve the original event to redact it
                        NSArray *events = bubbleData.events;
                        MXEvent *redactedEvent = nil;
                        for (MXEvent *event in events)
                        {
                            if ([event.eventId isEqualToString:redactionEvent.redacts])
                            {
                                redactedEvent = [event prune];
                                redactedEvent.redactedBecause = redactionEvent.JSONDictionary;
                                break;
                            }
                        }
                        
                        if (redactedEvent.isState)
                        {
                            // FIXME: The room state must be refreshed here since this redacted event.
                            NSLog(@"[MXKRoomVC] Warning: A state event has been redacted, room state may not be up to date");
                        }
                        
                        if (redactedEvent)
                        {
                            remainingEvents = [bubbleData updateEvent:redactionEvent.redacts withEvent:redactedEvent];
                        }
                    }
                    
                    // If there is no more events, remove the bubble
                    if (0 == remainingEvents)
                    {
                        [self removeCellData:bubbleData];
                    }
                    
                    // Update the delegate on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        if (self.delegate)
                        {
                            [self.delegate dataSource:self didCellChange:nil];
                        }
                        
                        // Notify the last message may have changed
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
                        
                    });
                }
            });
        }
    }];
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
            [_room.liveTimeline removeListener:typingNotifListener];
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
        [_room.liveTimeline removeListener:typingNotifListener];
        currentTypingUsers = nil;
    }
    
    // Add typing notification listener
    typingNotifListener = [_room.liveTimeline listenToEventsOfTypes:@[kMXEventTypeStringTypingNotification] onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
    {
        
        // Handle only live events
        if (direction == MXEventDirectionForwards)
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
    if (backPaginationRequest)
    {
        [backPaginationRequest cancel];
        backPaginationRequest = nil;
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
- (void)paginateBackMessages:(NSUInteger)numItems onlyFromStore:(BOOL)onlyFromStore success:(void (^)(NSUInteger addedCellNumber))success failure:(void (^)(NSError *error))failure
{
    // Check the current data source state, and the actual user membership for this room.
    if (state != MXKDataSourceStateReady || self.room.state.membership == MXMembershipUnknown || self.room.state.membership == MXMembershipInvite)
    {
        // Back pagination is not available here.
        if (failure)
        {
            failure(nil);
        }
        return;
    }
    
    if (backPaginationRequest)
    {
        NSLog(@"[MXKRoomDataSource] paginateBackMessages: a pagination is already in progress");
        return;
    }
    
    if (NO == [_room.liveTimeline canPaginate: MXEventDirectionBackwards])
    {
        NSLog(@"[MXKRoomDataSource] paginateBackMessages: No more events to paginate");
        if (success)
        {
            success(0);
        }
    }
    
    // Keep events from the past to later processing
    id backPaginateListener = [_room.liveTimeline listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
    {
        if (MXEventDirectionBackwards == direction)
        {
            [self queueEventForProcessing:event withRoomState:roomState direction:MXEventDirectionBackwards];
        }
    }];
    
    // Launch the pagination
    backPaginationRequest = [_room.liveTimeline paginate:numItems direction:MXEventDirectionBackwards onlyFromStore:onlyFromStore complete:^{
        
        backPaginationRequest = nil;
        // Once done, process retrieved events
        [_room.liveTimeline removeListener:backPaginateListener];
        [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
            
            if (success)
            {
                success(addedHistoryCellNb);
            }
            
        }];
        
    } failure:^(NSError *error) {
        
        NSLog(@"[MXKRoomDataSource] paginateBackMessages fails. Error: %@", error);
        
        backPaginationRequest = nil;
        [_room.liveTimeline removeListener:backPaginateListener];
        
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
        
    }];
};

- (void)paginateBackMessagesToFillRect:(CGRect)rect withMinRequestMessagesCount:(NSUInteger)minRequestMessagesCount success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    NSLog(@"[MXKRoomDataSource] paginateBackMessagesToFillRect: %@", NSStringFromCGRect(rect));

    // Get the total height of cells already loaded in memory
    CGFloat minMessageHeight = CGFLOAT_MAX;
    CGFloat bubblesTotalHeight = 0;

    // Check whether data has been aldready loaded
    if (bubbles.count)
    {
        for (NSInteger i = bubbles.count - 1; i >= 0; i--)
        {
            CGFloat bubbleHeight = [self cellHeightAtIndex:i withMaximumWidth:rect.size.width];

            bubblesTotalHeight += bubbleHeight;

            if (bubblesTotalHeight > rect.size.height)
            {
                // No need to compute more cells heights, there are enough to fill the rect
                NSLog(@"[MXKRoomDataSource] -> %tu already loaded bubbles are enough to fill the screen", bubbles.count - i);
                break;
            }

            // Compute the minimal height an event takes
            id<MXKRoomBubbleCellDataStoring> bubbleData = bubbles[i];
            minMessageHeight = MIN(minMessageHeight,  bubbleHeight / bubbleData.events.count);
        }
    }
    else
    {
        NSLog(@"[MXKRoomDataSource] paginateBackMessagesToFillRect: Prefill with data from the store");
        // Give a chance to load data from the store before doing homeserver requests
        // Reuse minRequestMessagesCount because we need to provide a number.
        [self paginateBackMessages:minRequestMessagesCount onlyFromStore:YES success:^(NSUInteger addedCellNumber) {

            // Then retry
            [self paginateBackMessagesToFillRect:rect withMinRequestMessagesCount:minRequestMessagesCount success:success failure:failure];

        } failure:failure];
        return;
    }
    
    // Is there enough cells to cover all the requested height?
    if (bubblesTotalHeight < rect.size.height)
    {
        // No. Paginate to get more messages
        if ([_room.liveTimeline canPaginate:MXEventDirectionBackwards])
        {
            // Bound the minimal height to 44
            minMessageHeight = MIN(minMessageHeight, 44);
            
            // Load messages to cover the remaining height
            // Use an extra of 50% to manage unsupported/unexpected/redated events
            NSUInteger messagesToLoad = ceil((rect.size.height - bubblesTotalHeight) / minMessageHeight * 1.5);

            // It does not worth to make a pagination request for only 1 message.
            // So, use minRequestMessagesCount
            messagesToLoad = MAX(messagesToLoad, minRequestMessagesCount);
            
            NSLog(@"[MXKRoomDataSource] paginateBackMessagesToFillRect: need to paginate %tu events to cover %fpx", messagesToLoad, rect.size.height - bubblesTotalHeight);
            [self paginateBackMessages:messagesToLoad onlyFromStore:NO success:^(NSUInteger addedCellNumber) {
                
                [self paginateBackMessagesToFillRect:rect withMinRequestMessagesCount:minRequestMessagesCount success:success failure:failure];
                
            } failure:failure];
        }
        else
        {
            
            NSLog(@"[MXKRoomDataSource] paginateBackMessagesToFillRect: No more events to paginate");
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
    MXMessageType msgType = kMXMessageTypeText;
    
    // Check whether the message is an emote
    if ([text hasPrefix:@"/me "])
    {
        msgType = kMXMessageTypeEmote;
        
        // Remove "/me " string
        text = [text substringFromIndex:4];
    }
    
    // Prepare the message content
    NSDictionary *msgContent = @{
                                 @"msgtype": msgType,
                                 @"body": text
                                 };
    
    [self sendMessageOfType:msgType content:msgContent success:success failure:failure];
}

- (void)sendImage:(UIImage *)image success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    // Make sure the uploaded image orientation is up
    image = [MXKTools forceImageOrientationUp:image];
    
    // Only jpeg image is supported here
    NSString *mimetype = @"image/jpeg";
    NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
    
    // Use the uploader id as fake URL for this image data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXKMediaLoader *uploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:1];
    NSString *fakeMediaManagerURL = uploader.uploadId;
    
    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakeMediaManagerURL andType:mimetype inFolder:self.roomId];
    [MXKMediaManager writeMediaData:imageData toFilePath:cacheFilePath];
    
    // Create a fake image name based on imageData to keep the same name for the same image.
    NSString *dataHash = [imageData MD5];
    if (dataHash.length > 7)
    {
        // Crop
        dataHash = [dataHash substringToIndex:7];
    }
    NSString *filename = [NSString stringWithFormat:@"ima_%@.jpeg", dataHash];

    // Prepare the message content for building an echo message
    NSDictionary *msgContent = @{
                                 @"msgtype": kMXMessageTypeImage,
                                 @"body": filename,
                                 @"url": fakeMediaManagerURL,
                                 @"info": @{
                                         @"mimetype": mimetype,
                                         @"w": @(image.size.width),
                                         @"h": @(image.size.height),
                                         @"size": @(imageData.length)
                                         }
                                 };
    MXEvent *localEcho = [self addLocalEchoForMessageContent:msgContent withState:MXKEventStateUploading];
    
    // Launch the upload to the Matrix Content repository
    [uploader uploadData:imageData filename:filename mimeType:mimetype success:^(NSString *url) {
        // Update the local echo state: move from content uploading to event sending
        localEcho.mxkState = MXKEventStateSending;
        [self updateLocalEcho:localEcho];
        
        // Copy the cached image to the actual cacheFile path
        NSString *absoluteURL = [self.mxSession.matrixRestClient urlOfContent:url];
        NSString *actualCacheFilePath = [MXKMediaManager cachePathForMediaWithURL:absoluteURL andType:mimetype inFolder:self.roomId];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:cacheFilePath toPath:actualCacheFilePath error:&error];
        
        // Update the message content with the mxc:// of the media on the homeserver
        NSMutableDictionary *msgContent2 = [NSMutableDictionary dictionaryWithDictionary:msgContent];
        msgContent2[@"url"] = url;
        
        // Update the local echo event too. It will be used to suppress this echo in [self pendingLocalEchoRelatedToEvent];
        localEcho.content = msgContent2;
        [_room updateOutgoingMessage:localEcho.eventId withOutgoingMessage:localEcho];
        
        // Make the final request that posts the image event
        [_room sendMessageOfType:kMXMessageTypeImage content:msgContent2 success:^(NSString *eventId) {
            
            // Nothing to do here
            // The local echo will be removed when the corresponding event will come through the events stream
            
            if (success)
            {
                success(eventId);
            }
            
        } failure:^(NSError *error) {
            
            // Update the local echo with the error state
            localEcho.mxkState = MXKEventStateSendingFailed;
            [self updateLocalEcho:localEcho];
            
            if (failure)
            {
                failure(error);
            }
        }];
        
    } failure:^(NSError *error) {
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self updateLocalEcho:localEcho];
        
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)sendImage:(NSURL *)imageLocalURL mimeType:(NSString*)mimetype success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    NSData *imageData = [NSData dataWithContentsOfFile:imageLocalURL.path];
    UIImage *image = [UIImage imageWithData:imageData];
    
    // Use the uploader id as fake URL for this image data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXKMediaLoader *uploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:1];
    NSString *fakeMediaManagerURL = uploader.uploadId;
    
    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakeMediaManagerURL andType:mimetype inFolder:self.roomId];
    [MXKMediaManager writeMediaData:imageData toFilePath:cacheFilePath];
    
    // Create a fake name based on fileData to keep the same name for the same file.
    NSString *dataHash = [imageData MD5];
    if (dataHash.length > 7)
    {
        // Crop
        dataHash = [dataHash substringToIndex:7];
    }
    NSString *extension = [MXKTools fileExtensionFromContentType:mimetype];
    NSString *filename = [NSString stringWithFormat:@"ima_%@%@", dataHash, extension];
    
    // Prepare the message content for building an echo message
    NSDictionary *msgContent = @{
                                 @"msgtype": kMXMessageTypeImage,
                                 @"body": filename,
                                 @"url": fakeMediaManagerURL,
                                 @"info": @{
                                         @"mimetype": mimetype,
                                         @"w": @(image.size.width),
                                         @"h": @(image.size.height),
                                         @"size": @(imageData.length)
                                         }
                                 };
    MXEvent *localEcho = [self addLocalEchoForMessageContent:msgContent withState:MXKEventStateUploading];
    
    // Launch the upload to the Matrix Content repository
    [uploader uploadData:imageData filename:filename mimeType:mimetype success:^(NSString *url) {
        // Update the local echo state: move from content uploading to event sending
        localEcho.mxkState = MXKEventStateSending;
        [self updateLocalEcho:localEcho];
        
        // Copy the cached file to the actual cacheFile path
        NSString *absoluteURL = [self.mxSession.matrixRestClient urlOfContent:url];
        NSString *actualCacheFilePath = [MXKMediaManager cachePathForMediaWithURL:absoluteURL andType:mimetype inFolder:self.roomId];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:cacheFilePath toPath:actualCacheFilePath error:&error];
        
        // Update the message content with the mxc:// of the media on the homeserver
        NSMutableDictionary *msgContent2 = [NSMutableDictionary dictionaryWithDictionary:msgContent];
        msgContent2[@"url"] = url;
        
        // Update the local echo event too. It will be used to suppress this echo in [self pendingLocalEchoRelatedToEvent];
        localEcho.content = msgContent2;
        [_room updateOutgoingMessage:localEcho.eventId withOutgoingMessage:localEcho];

        // Make the final request that posts the image event
        [_room sendMessageOfType:kMXMessageTypeImage content:msgContent2 success:^(NSString *eventId) {
            
            // Nothing to do here
            // The local echo will be removed when the corresponding event will come through the events stream
            
            if (success)
            {
                success(eventId);
            }
            
        } failure:^(NSError *error) {
            
            // Update the local echo with the error state
            localEcho.mxkState = MXKEventStateSendingFailed;
            [self updateLocalEcho:localEcho];
            
            if (failure)
            {
                failure(error);
            }
        }];
        
    } failure:^(NSError *error) {
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self updateLocalEcho:localEcho];
        
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)sendVideo:(NSURL *)videoLocalURL withThumbnail:(UIImage *)videoThumbnail success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    NSData *videoThumbnailData = UIImageJPEGRepresentation(videoThumbnail, 0.8);
    
    // Use the uploader id as fake URL for this image data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXKMediaLoader *uploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:0.1];
    NSString *fakeMediaManagerThumbnailURL = uploader.uploadId;
    
    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakeMediaManagerThumbnailURL andType:@"image/jpeg" inFolder:self.roomId];
    [MXKMediaManager writeMediaData:videoThumbnailData toFilePath:cacheFilePath];
    
    // Prepare the message content for building an echo message
    NSMutableDictionary *msgContent = [@{
                                         @"msgtype": kMXMessageTypeVideo,
                                         @"body": @"Video",
                                         @"url": fakeMediaManagerThumbnailURL,
                                         @"info": [@{
                                                     @"thumbnail_url": fakeMediaManagerThumbnailURL,
                                                     @"thumbnail_info": @{
                                                             @"mimetype": @"image/jpeg",
                                                             @"w": @(videoThumbnail.size.width),
                                                             @"h": @(videoThumbnail.size.height),
                                                             @"size": @(videoThumbnailData.length)
                                                             }
                                                     } mutableCopy]
                                         } mutableCopy];
    MXEvent *localEcho = [self addLocalEchoForMessageContent:msgContent withState:MXKEventStateUploading];
    
    // Before sending data to the server, convert the video to MP4
    [MXKTools convertVideoToMP4:videoLocalURL success:^(NSURL *videoLocalURL, NSString *mimetype, CGSize size, double durationInMs) {
        // Upload thumbnail
        [uploader uploadData:videoThumbnailData filename:nil mimeType:@"image/jpeg" success:^(NSString *thumbnailUrl) {
            
            // Upload video
            NSData* videoData = [NSData dataWithContentsOfFile:videoLocalURL.path];
            if (videoData)
            {  
                MXKMediaLoader *videoUploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0.1 andRange:0.9];
                
                // Create a fake image name based on imageData to keep the same name for the same image.
                NSString *dataHash = [videoData MD5];
                if (dataHash.length > 7)
                {
                    // Crop
                    dataHash = [dataHash substringToIndex:7];
                }
                NSString *extension = [MXKTools fileExtensionFromContentType:mimetype];
                NSString *filename = [NSString stringWithFormat:@"video_%@%@", dataHash, extension];
                msgContent[@"body"] = filename;
                
                // Apply the nasty trick again so that the cell can monitor the upload progress
                msgContent[@"url"] = videoUploader.uploadId;
                localEcho.content = msgContent;
                [_room updateOutgoingMessage:localEcho.eventId withOutgoingMessage:localEcho];
                [self updateLocalEcho:localEcho];
                
                [videoUploader uploadData:videoData filename:filename mimeType:mimetype success:^(NSString *videoUrl) {
                    
                    // Write the video to the actual cacheFile path
                    NSString *absoluteURL = [self.mxSession.matrixRestClient urlOfContent:videoUrl];
                    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:absoluteURL andType:mimetype inFolder:self.roomId];
                    [MXKMediaManager writeMediaData:videoData toFilePath:cacheFilePath];
                    
                    // Finalise msgContent
                    msgContent[@"url"] = videoUrl;
                    msgContent[@"info"][@"mimetype"] = mimetype;
                    msgContent[@"info"][@"w"] = @(size.width);
                    msgContent[@"info"][@"h"] = @(size.height);
                    msgContent[@"info"][@"duration"] = @(durationInMs);
                    msgContent[@"info"][@"thumbnail_url"] = thumbnailUrl;
                    
                    localEcho.content = msgContent;
                    [_room updateOutgoingMessage:localEcho.eventId withOutgoingMessage:localEcho];
                    [self updateLocalEcho:localEcho];
                    
                    // And send the Matrix room message video event to the homeserver
                    [_room sendMessageOfType:kMXMessageTypeVideo content:msgContent success:^(NSString *eventId) {
                        
                        // Nothing to do here
                        // The local echo will be removed when the corresponding event will come through the events stream
                        
                        if (success)
                        {
                            success(eventId);
                        }
                    } failure:^(NSError *error) {
                        
                        // Update the local echo with the error state
                        localEcho.mxkState = MXKEventStateSendingFailed;
                        [self updateLocalEcho:localEcho];
                        
                        if (failure)
                        {
                            failure(error);
                        }
                    }];
                    
                } failure:^(NSError *error) {
                    
                    // Update the local echo with the error state
                    localEcho.mxkState = MXKEventStateSendingFailed;
                    [self updateLocalEcho:localEcho];
                    
                    if (failure)
                    {
                        failure(error);
                    }
                }];
            }
            else
            {
                // Update the local echo with the error state
                localEcho.mxkState = MXKEventStateSendingFailed;
                [self updateLocalEcho:localEcho];
                
                if (failure)
                {
                    failure(nil);
                }
            }
        } failure:^(NSError *error) {
            
            // Update the local echo with the error state
            localEcho.mxkState = MXKEventStateSendingFailed;
            [self updateLocalEcho:localEcho];
            
            if (failure)
            {
                failure(error);
            }
        }];
        
    } failure:^(NSError *error) {
        
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self updateLocalEcho:localEcho];
        
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)sendFile:(NSURL *)fileLocalURL mimeType:(NSString*)mimetype success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    NSData *fileData = [NSData dataWithContentsOfFile:fileLocalURL.path];
    
    // Use the uploader id as fake URL for this file data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXKMediaLoader *uploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:1];
    NSString *fakeMediaManagerURL = uploader.uploadId;
    
    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakeMediaManagerURL andType:mimetype inFolder:self.roomId];
    [MXKMediaManager writeMediaData:fileData toFilePath:cacheFilePath];
    
    // Create a fake name based on fileData to keep the same name for the same file.
    NSString *dataHash = [fileData MD5];
    if (dataHash.length > 7)
    {
        // Crop
        dataHash = [dataHash substringToIndex:7];
    }
    NSString *extension = [MXKTools fileExtensionFromContentType:mimetype];
    NSString *filename = [NSString stringWithFormat:@"file_%@%@", dataHash, extension];
    
    // Prepare the message content for building an echo message
    NSDictionary *msgContent = @{
                                 @"msgtype": kMXMessageTypeFile,
                                 @"body": filename,
                                 @"url": fakeMediaManagerURL,
                                 @"info": @{
                                         @"mimetype": mimetype,
                                         @"size": @(fileData.length)
                                         }
                                 };
    MXEvent *localEcho = [self addLocalEchoForMessageContent:msgContent withState:MXKEventStateUploading];
    
    // Launch the upload to the Matrix Content repository
    [uploader uploadData:fileData filename:filename mimeType:mimetype success:^(NSString *url) {
        // Update the local echo state: move from content uploading to event sending
        localEcho.mxkState = MXKEventStateSending;
        [self updateLocalEcho:localEcho];
        
        // Copy the cached file to the actual cacheFile path
        NSString *absoluteURL = [self.mxSession.matrixRestClient urlOfContent:url];
        NSString *actualCacheFilePath = [MXKMediaManager cachePathForMediaWithURL:absoluteURL andType:mimetype inFolder:self.roomId];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:cacheFilePath toPath:actualCacheFilePath error:&error];
        
        // Update the message content with the mxc:// of the media on the homeserver
        NSMutableDictionary *msgContent2 = [NSMutableDictionary dictionaryWithDictionary:msgContent];
        msgContent2[@"url"] = url;
        
        // Update the local echo event too. It will be used to suppress this echo in [self pendingLocalEchoRelatedToEvent];
        localEcho.content = msgContent2;
        [_room updateOutgoingMessage:localEcho.eventId withOutgoingMessage:localEcho];

        // Make the final request that posts the event
        [_room sendMessageOfType:kMXMessageTypeFile content:msgContent2 success:^(NSString *eventId) {
            
            // Nothing to do here
            // The local echo will be removed when the corresponding event will come through the events stream
            
            if (success)
            {
                success(eventId);
            }
            
        } failure:^(NSError *error) {
            
            // Update the local echo with the error state
            localEcho.mxkState = MXKEventStateSendingFailed;
            [self updateLocalEcho:localEcho];
            
            if (failure)
            {
                failure(error);
            }
        }];
        
    } failure:^(NSError *error) {
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self updateLocalEcho:localEcho];
        
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)sendMessageOfType:(MXMessageType)msgType content:(NSDictionary *)msgContent success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    // Build the local echo
    MXEvent *localEcho = [self addLocalEchoForMessageContent:msgContent];
    
    // Make the request to the homeserver
    [_room sendMessageOfType:msgType content:msgContent success:^(NSString *eventId) {
        
        // Nothing to do here
        // The local echo will be removed when the corresponding event will come through the events stream
        
        if (success)
        {
            success(eventId);
        }
        
    } failure:^(NSError *error) {
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self updateLocalEcho:localEcho];
        
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)resendEventWithEventId:(NSString *)eventId success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    MXEvent *event = [self eventWithEventId:eventId];
    
    NSLog(@"[MXKRoomDataSource] resendEventWithEventId. Event: %@", event);
    
    if (event && event.eventType == MXEventTypeRoomMessage)
    {
        // And retry the send the message accoding to its type
        NSString *msgType = event.content[@"msgtype"];
        if ([msgType isEqualToString:kMXMessageTypeText] || [msgType isEqualToString:kMXMessageTypeEmote])
        {
            // Remove the local echo
            [self removeEventWithEventId:eventId];

            // And resend
            [self sendMessageOfType:msgType content:event.content success:success failure:failure];
        }
        else if ([msgType isEqualToString:kMXMessageTypeImage])
        {
            // Remove the local echo
            [self removeEventWithEventId:eventId];
            
            NSString *mimetype = nil;
            if (event.content[@"info"])
            {
                mimetype = event.content[@"info"][@"mimetype"];
            }
            
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if ([contentURL hasPrefix:kMXKMediaUploadIdPrefix])
            {
                NSString *localImagePath = [MXKMediaManager cachePathForMediaWithURL:contentURL andType:mimetype inFolder:_roomId];
                UIImage* image = [MXKMediaManager loadPictureFromFilePath:localImagePath];
                if (image)
                {
                    // Restart sending the image from the beginning
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
                // The sending failed while sending the corresponding Matrix event.
                // Resend the Matrix event
                [self sendMessageOfType:msgType content:event.content success:success failure:failure];
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
        [self refreshUnreadCounters:NO];
        
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
    // Add unsent events at the end of the conversation
    for (MXEvent *outgoingMessage in _room.outgoingMessages)
    {
        outgoingMessage.mxkState = MXKEventStateSendingFailed;

        // Need to update the timestamp because bubbles can reorder their events
        // according to theirs timestamps
        outgoingMessage.originServerTs = (uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000);

        [self queueEventForProcessing:outgoingMessage withRoomState:_room.state direction:MXEventDirectionForwards];
    }
}

#pragma mark - Private methods
- (MXEvent*)addLocalEchoForMessageContent:(NSDictionary*)msgContent
{
    return [self addLocalEchoForMessageContent:msgContent withState:MXKEventStateSending];
}

- (MXEvent*)addLocalEchoForMessageContent:(NSDictionary*)msgContent withState:(MXKEventState)eventState
{
    // Make the data source digest this fake local echo message
    MXEvent *localEcho = [_eventFormatter fakeRoomMessageEventForRoomId:_roomId withEventId:nil andContent:msgContent];
    localEcho.mxkState = eventState;
    
    [self queueEventForProcessing:localEcho withRoomState:_room.state direction:MXEventDirectionForwards];
    [self processQueuedEvents:nil];
    
    // Register the echo as pending for its future deletion
    [self addPendingLocalEcho:localEcho];
    
    return localEcho;
}

- (void)updateLocalEcho:(MXEvent*)localEcho
{
    // Retrieve the cell data hosting the local echo
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:localEcho.eventId];
    @synchronized (bubbleData)
    {
        [bubbleData updateEvent:localEcho.eventId withEvent:localEcho];
    }
    
    // Inform the delegate
    if (self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
    
    // Notify the last message may have changed
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
}

- (void)replaceLocalEcho:(MXEvent*)localEcho withEvent:(MXEvent*)event
{
    // Remove the event from the pending local echo list
    [self removePendingLocalEcho:localEcho];
    
    // Update the event in its cell data
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:localEcho.eventId];
    
    NSUInteger remainingEvents;
    @synchronized (bubbleData)
    {
        remainingEvents = [bubbleData updateEvent:localEcho.eventId withEvent:event];
    }
    
    // Update bubbles mapping
    @synchronized (eventIdToBubbleMap)
    {
        // Remove the broken link from the map
        [eventIdToBubbleMap removeObjectForKey:localEcho.eventId];
        
        if (remainingEvents)
        {
            eventIdToBubbleMap[event.eventId] = bubbleData;
        }
    }
    
    // If there is no more events in the bubble, remove it
    if (0 == remainingEvents)
    {
        [self removeCellData:bubbleData];
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
                    
                    firstCellData.isPaginationFirstBubble = (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay);
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
                            cellData2.isPaginationFirstBubble = ![cellData2DateString isEqualToString:cellData1DateString];
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
- (void)queueEventForProcessing:(MXEvent*)event withRoomState:(MXRoomState*)roomState direction:(MXEventDirection)direction
{
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
                            event.mxkState = MXKEventStateBing;
                            return YES;
                        }
                    }
                }
            }
        }
    }
    
    return NO;
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

                        if ([self checkBing:queuedEvent.event])
                        {
                            _unreadBingCount++;
                        }

                        // Retrieve the MXKCellData class to manage the data
                        Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
                        NSAssert([class conformsToProtocol:@protocol(MXKRoomBubbleCellDataStoring)], @"MXKRoomDataSource only manages MXKCellData that conforms to MXKRoomBubbleCellDataStoring protocol");

                        BOOL eventManaged = NO;
                        id<MXKRoomBubbleCellDataStoring> bubbleData;
                        if ([class instancesRespondToSelector:@selector(addEvent:andRoomState:)] && 0 < bubblesSnapshot.count)
                        {
                            // Try to concatenate the event to the last or the oldest bubble?
                            if (queuedEvent.direction == MXEventDirectionBackwards)
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

                            if (queuedEvent.direction == MXEventDirectionBackwards)
                            {
                                // The new bubble data will be inserted at first position.
                                // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the current first bubble.

                                // Pagination handling
                                if (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay)
                                {
                                    // A new pagination starts with this new bubble data
                                    bubbleData.isPaginationFirstBubble = YES;

                                    // Check whether the current first bubble belongs to the same pagination
                                    if (bubblesSnapshot.count)
                                    {
                                        id<MXKRoomBubbleCellDataStoring> previousFirstBubbleData = bubblesSnapshot.firstObject;
                                        NSString *firstBubbleDateString = [self.eventFormatter dateStringFromDate:previousFirstBubbleData.date withTime:NO];
                                        NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                        previousFirstBubbleData.isPaginationFirstBubble = ![firstBubbleDateString isEqualToString:bubbleDateString];
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
                                        // Check whether the curent first bubble has been sent by the same user.
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
                                    bubbleData.isPaginationFirstBubble = YES;
                                    if (bubblesSnapshot.count)
                                    {
                                        id<MXKRoomBubbleCellDataStoring> previousLastBubbleData = bubblesSnapshot.lastObject;
                                        NSString *lastBubbleDateString = [self.eventFormatter dateStringFromDate:previousLastBubbleData.date withTime:NO];
                                        NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                        bubbleData.isPaginationFirstBubble = ![bubbleDateString isEqualToString:lastBubbleDateString];
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
                    
                    [self refreshUnreadCounters:NO];
                    
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
                    
                    // Notify the last message, unreadCount and/or unreadBingCount have changed
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
    // The view controller is going to display all messages
    // Automatically reset the counters
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
    {
        [self markAllAsRead];
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
            if (!cell.delegate)
            {
                cell.delegate = self;
            }
            
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


#pragma mark - Local echo suppression
// @TODO: All these dirty methods will be removed once CS v2 is available.

/**
 Add a local echo event waiting for the true event coming down from the event stream.
 
 @param localEcho the local echo.
 */
- (void)addPendingLocalEcho:(MXEvent*)localEcho
{
    [_room storeOutgoingMessage:localEcho];
}

/**
 Remove the local echo from the pending queue.
 
 @discussion
 It can be removed from the list because we received the true event from the event stream
 or the corresponding request has failed.
 */
- (void)removePendingLocalEcho:(MXEvent*)localEcho
{
    [_room removeOutgoingMessage:localEcho.eventId];
}

/**
 Try to determine if an event coming down from the events stream has a local echo.
 
 @param event the event from the events stream
 @return a local echo event corresponding to the event. Nil if there is no match.
 */
- (MXEvent*)pendingLocalEchoRelatedToEvent:(MXEvent*)event
{
    // Note: event is supposed here to be an outgoing event received from event stream.
    // This method returns a pending event (if any) whose content matches with received event content.
    NSString *msgtype = event.content[@"msgtype"];
    
    MXEvent *localEcho = nil;
    NSArray<MXEvent*>* pendingLocalEchoes = _room.outgoingMessages;
    for (NSInteger index = 0; index < pendingLocalEchoes.count; index++)
    {
        localEcho = [pendingLocalEchoes objectAtIndex:index];
        NSString *pendingEventType = localEcho.content[@"msgtype"];
        
        if ([msgtype isEqualToString:pendingEventType])
        {
            if ([msgtype isEqualToString:kMXMessageTypeText] || [msgtype isEqualToString:kMXMessageTypeEmote])
            {
                // Compare content body
                if ([event.content[@"body"] isEqualToString:localEcho.content[@"body"]])
                {
                    break;
                }
            }
            else if ([msgtype isEqualToString:kMXMessageTypeLocation])
            {
                // Compare geo uri
                if ([event.content[@"geo_uri"] isEqualToString:localEcho.content[@"geo_uri"]])
                {
                    break;
                }
            }
            else
            {
                // Here the type is kMXMessageTypeImage, kMXMessageTypeAudio, kMXMessageTypeVideo or kMXMessageTypeFile
                if ([event.content[@"url"] isEqualToString:localEcho.content[@"url"]])
                {
                    break;
                }
            }
        }
        localEcho = nil;
    }
    
    return localEcho;
}

@end
