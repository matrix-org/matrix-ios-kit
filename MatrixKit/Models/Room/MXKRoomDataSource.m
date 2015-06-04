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

#import "MXKRoomBubbleMergingMessagesCellData.h"
#import "MXKRoomIncomingBubbleTableViewCell.h"
#import "MXKRoomOutgoingBubbleTableViewCell.h"

#import "MXKTools.h"

#import "MXKAppSettings.h"

#pragma mark - Constant definitions
const NSString *MatrixKitVersion = @"0.1.0";
NSString *const kMXKRoomBubbleCellDataIdentifier = @"kMXKRoomBubbleCellDataIdentifier";

NSString *const kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier = @"kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier";
NSString *const kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier = @"kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier";
NSString *const kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier = @"kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier";
NSString *const kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier = @"kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier";

NSString *const kMXKRoomDataSourceMetaDataChanged = @"kMXKRoomDataSourceMetaDataChanged";


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
     Mapping between events ids and bubbles.
     */
    NSMutableDictionary *eventIdToBubbleMap;
    
    /**
     Local echo events which requests are pending.
     */
    NSMutableArray *pendingLocalEchoes;
    
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
        processingQueue = dispatch_queue_create("MXKRoomDataSource", DISPATCH_QUEUE_SERIAL);
        bubbles = [NSMutableArray array];
        eventsToProcess = [NSMutableArray array];
        eventIdToBubbleMap = [NSMutableDictionary dictionary];
        pendingLocalEchoes = [NSMutableArray array];
        
        // Set default data and view classes
        // Cell data
        [self registerCellDataClass:MXKRoomBubbleMergingMessagesCellData.class forCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
        // For incoming messages
        [self registerCellViewClass:MXKRoomIncomingBubbleTableViewCell.class forCellIdentifier:kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier];
        [self registerCellViewClass:MXKRoomIncomingBubbleTableViewCell.class forCellIdentifier:kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier];
        // And outgoing messages
        [self registerCellViewClass:MXKRoomOutgoingBubbleTableViewCell.class forCellIdentifier:kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier];
        [self registerCellViewClass:MXKRoomOutgoingBubbleTableViewCell.class forCellIdentifier:kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier];
        
        // Set default MXEvent -> NSString formatter
        self.eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:self.mxSession];
        
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
                                             kMXEventTypeStringCallInvite
                                             ];
        }
        
        [self didMXSessionStateChange];
    }
    return self;
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
        [_room removeListener:liveEventsListener];
        liveEventsListener = nil;
        
        [_room removeListener:redactionListener];
        redactionListener = nil;
    }
    
    if (_room && typingNotifListener)
    {
        [_room removeListener:typingNotifListener];
        typingNotifListener = nil;
    }
    currentTypingUsers = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionInitialSyncedRoomNotification object:nil];
    
    @synchronized(eventsToProcess)
    {
        [eventsToProcess removeAllObjects];
    }
    
    // Suspend the reset operation if some events is under processing
    @synchronized(eventsToProcessSnapshot)
    {
        eventsToProcessSnapshot = nil;
        
        [bubbles removeAllObjects];
        [eventIdToBubbleMap removeAllObjects];
        [pendingLocalEchoes removeAllObjects];
        
        _room = nil;
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
    
    // Flush the current bubble data
    [self reset];
    
    // Reload
    [self didMXSessionStateChange];
    
    // Notify the last message may have changed
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
}

- (void)destroy
{
    
    NSLog(@"[MXKRoomDataSource] Destroy %p - room id: %@", self, _roomId);
    
    [self reset];
    
    self.eventFormatter = nil;
    processingQueue = nil;
    
    eventsToProcess = nil;
    bubbles = nil;
    eventIdToBubbleMap = nil;
    pendingLocalEchoes = nil;
    
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
                [_room resetBackState];
                
                // Force to set the filter at the MXRoom level
                self.eventsFilterForMessages = _eventsFilterForMessages;
                
                // Register on typing notif
                [self listenTypingNotifications];
                
                // Update here data source state if it is not already ready
                state = MXKDataSourceStateReady;
                
                if (NO == _room.isSync)
                {
                    // Listen to MXSession rooms count changes
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXRoomInitialSynced:) name:kMXSessionInitialSyncedRoomNotification object:nil];
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
    }
    return lastMessage;
}

- (void)setEventsFilterForMessages:(NSArray *)eventsFilterForMessages
{
    
    // Remove the previous live listener
    if (liveEventsListener)
    {
        [_room removeListener:liveEventsListener];
        [_room removeListener:redactionListener];
    }
    
    // And register a new one with the requested filter
    _eventsFilterForMessages = [eventsFilterForMessages copy];
    liveEventsListener = [_room listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
    {
        
        if (MXEventDirectionForwards == direction)
        {
            
            // Check for local echo suppression
            MXEvent *localEcho;
            if (pendingLocalEchoes.count && [event.userId isEqualToString:self.mxSession.myUser.userId])
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
    
    // Register a listener to handle redaction in live stream
    redactionListener = [_room listenToEventsOfTypes:@[kMXEventTypeStringRoomRedaction] onEvent:^(MXEvent *redactionEvent, MXEventDirection direction, MXRoomState *roomState)
    {
        
        // Consider only live redaction events
        if (direction == MXEventDirectionForwards)
        {
            
            // Do the processing on the processing queue
            dispatch_async(processingQueue, ^{
                
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
                                redactedEvent.redactedBecause = redactionEvent.originalDictionary;
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
                        
                        // TODO GFO: check whether the adjacent bubbles can merge together
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

- (void)listenTypingNotifications
{
    
    // Remove the previous live listener
    if (typingNotifListener)
    {
        [_room removeListener:typingNotifListener];
        currentTypingUsers = nil;
    }
    
    // Add typing notification listener
    typingNotifListener = [_room listenToEventsOfTypes:@[kMXEventTypeStringTypingNotification] onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
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
                    [self.delegate dataSource:self didCellChange:nil];
                }
            }
        }
    }];
    currentTypingUsers = _room.typingUsers;
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
        bubbleData = bubbles[index];
    }
    return bubbleData;
}

-(id<MXKRoomBubbleCellDataStoring>)cellDataOfEventWithEventId:(NSString *)eventId
{
    
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(eventIdToBubbleMap)
    {
        bubbleData = eventIdToBubbleMap[eventId];
    }
    return bubbleData;
}

- (CGFloat)cellHeightAtIndex:(NSInteger)index withMaximumWidth:(CGFloat)maxWidth
{
    // Compute here height of bubble cell
    CGFloat rowHeight;
    
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataAtIndex:index];
    
    // Sanity check
    if (!bubbleData)
    {
        return 0;
    }
    
    Class cellViewClass;
    if (bubbleData.isIncoming)
    {
        if (bubbleData.isAttachment)
        {
            cellViewClass = [self cellViewClassForCellIdentifier:kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier];
        }
        else
        {
            cellViewClass = [self cellViewClassForCellIdentifier:kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier];
        }
    }
    else if (bubbleData.isAttachment)
    {
        cellViewClass = [self cellViewClassForCellIdentifier:kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier];
    }
    else
    {
        cellViewClass = [self cellViewClassForCellIdentifier:kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier];
    }
    
    rowHeight = [cellViewClass heightForCellData:bubbleData withMaximumWidth:maxWidth];
    return rowHeight;
}

#pragma mark - Pagination
- (void)paginateBackMessages:(NSUInteger)numItems success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    
    // Check current state
    if (state != MXKDataSourceStateReady)
    {
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
    
    if (NO == _room.canPaginate)
    {
        
        NSLog(@"[MXKRoomDataSource] paginateBackMessages: No more events to paginate");
        if (success)
        {
            success();
        }
    }
    
    // Keep events from the past to later processing
    id backPaginateListener = [_room listenToEventsOfTypes:_eventsFilterForMessages onEvent:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState)
    {
        if (MXEventDirectionBackwards == direction)
        {
            [self queueEventForProcessing:event withRoomState:roomState direction:MXEventDirectionBackwards];
        }
    }];
    
    // Launch the pagination
    backPaginationRequest = [_room paginateBackMessages:numItems complete:^{
        
        backPaginationRequest = nil;
        // Once done, process retrieved events
        [_room removeListener:backPaginateListener];
        [self processQueuedEvents:success];
        
    } failure:^(NSError *error)
    {
        
        NSLog(@"[MXKRoomDataSource] paginateBackMessages fails. Error: %@", error);
        backPaginationRequest = nil;
        if (failure)
        {
            failure(error);
        }
    }];
};

- (void)paginateBackMessagesToFillRect:(CGRect)rect success:(void (^)())success failure:(void (^)(NSError *error))failure
{
    
    // Get the total height of cells already loaded in memory
    CGFloat minMessageHeight = CGFLOAT_MAX;
    CGFloat bubblesTotalHeight = 0;
    for (NSInteger i = bubbles.count - 1; i >= 0; i--)
    {
        
        CGFloat bubbleHeight = [self cellHeightAtIndex:i withMaximumWidth:rect.size.width];
        
        bubblesTotalHeight += bubbleHeight;
        if (bubblesTotalHeight > rect.size.height)
        {
            // No need to compute more cells heights, there are enough to fill the rect
            break;
        }
        
        // Compute the minimal height an event takes
        id<MXKRoomBubbleCellDataStoring> bubbleData = bubbles[i];
        minMessageHeight = MIN(minMessageHeight,  bubbleHeight / bubbleData.events.count);
    }
    
    // Is there enough cells to cover all the requested height?
    if (bubblesTotalHeight < rect.size.height)
    {
        
        // No. Paginate to get more messages
        if (_room.canPaginate)
        {
            
            // Bound the minimal height to 44
            minMessageHeight = MIN(minMessageHeight, 44);
            
            // Load messages to cover the remaining height
            // Use an extra of 50% to manage unsupported/unexpected/redated events
            NSUInteger messagesToLoad = ceil((rect.size.height - bubblesTotalHeight) / minMessageHeight * 1.5);
            
            NSLog(@"[MXKRoomDataSource] paginateBackMessagesToFillRect: need to paginate %tu events to cover %fpx", messagesToLoad, rect.size.height - bubblesTotalHeight);
            [self paginateBackMessages:messagesToLoad success:^{
                
                [self paginateBackMessagesToFillRect:rect success:success failure:failure];
                
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
    
    // @TODO: Do not limit images to jpeg
    NSString *mimetype = @"image/jpeg";
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    
    // Use the uploader id as fake URL for this image data
    // The URL does not need to be valid as the MediaManager will get the data
    // directly from its cache
    // Pass this id in the URL is a nasty trick to retrieve it later
    MXKMediaLoader *uploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0 andRange:1];
    NSString *fakeMediaManagerURL = uploader.uploadId;
    
    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakeMediaManagerURL inFolder:self.roomId];
    [MXKMediaManager writeMediaData:imageData toFilePath:cacheFilePath];
    
    // Prepare the message content for building an echo message
    NSDictionary *msgContent = @{
                                 @"msgtype": kMXMessageTypeImage,
                                 @"body": @"Image",
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
    [uploader uploadData:imageData mimeType:mimetype success:^(NSString *url)
    {
        
        // Update the local echo state: move from content uploading to event sending
        localEcho.mxkState = MXKEventStateSending;
        [self updateLocalEcho:localEcho];
        
        // Update the message content with the mxc:// of the media on the homeserver
        NSMutableDictionary *msgContent2 = [NSMutableDictionary dictionaryWithDictionary:msgContent];
        msgContent2[@"url"] = url;
        
        // Update the local echo event too. It will be used to suppress this echo in [self pendingLocalEchoRelatedToEvent];
        localEcho.content = msgContent2;
        
        // Make the final request that posts the image event
        [_room sendMessageOfType:kMXMessageTypeImage content:msgContent2 success:^(NSString *eventId)
        {
            
            // Nothing to do here
            // The local echo will be removed when the corresponding event will come through the events stream
            
            if (success)
            {
                success(eventId);
            }
            
        } failure:^(NSError *error)
        {
            
            // Update the local echo with the error state
            localEcho.mxkState = MXKEventStateSendingFailed;
            [self removePendingLocalEcho:localEcho];
            [self updateLocalEcho:localEcho];
            
            if (failure)
            {
                failure(error);
            }
        }];
        
    } failure:^(NSError *error)
    {
        
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self removePendingLocalEcho:localEcho];
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
    
    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakeMediaManagerThumbnailURL inFolder:self.roomId];
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
    [MXKTools convertVideoToMP4:videoLocalURL success:^(NSURL *videoLocalURL, NSString *mimetype, CGSize size, double durationInMs)
    {
        
        // Upload thumbnail
        [uploader uploadData:videoThumbnailData mimeType:@"image/jpeg" success:^(NSString *thumbnailUrl)
        {
            
            // Upload video
            NSData* videoData = [NSData dataWithContentsOfFile:videoLocalURL.path];
            if (videoData)
            {
                
                MXKMediaLoader *videoUploader = [MXKMediaManager prepareUploaderWithMatrixSession:self.mxSession initialRange:0.1 andRange:0.9];
                
                // Apply the nasty trick again so that the cell can monitor the upload progress
                msgContent[@"url"] = videoUploader.uploadId;
                localEcho.content = msgContent;
                [self updateLocalEcho:localEcho];
                
                [videoUploader uploadData:videoData mimeType:mimetype success:^(NSString *videoUrl)
                {
                    
                    // Finalise msgContent
                    msgContent[@"url"] = videoUrl;
                    msgContent[@"info"][@"mimetype"] = mimetype;
                    msgContent[@"info"][@"w"] = @(size.width);
                    msgContent[@"info"][@"h"] = @(size.height);
                    msgContent[@"info"][@"duration"] = @(durationInMs);
                    msgContent[@"info"][@"thumbnail_url"] = thumbnailUrl;
                    
                    localEcho.content = msgContent;
                    [self updateLocalEcho:localEcho];
                    
                    // And send the Matrix room message video event to the homeserver
                    [_room sendMessageOfType:kMXMessageTypeVideo content:msgContent success:^(NSString *eventId)
                    {
                        
                        // Nothing to do here
                        // The local echo will be removed when the corresponding event will come through the events stream
                        
                        if (success)
                        {
                            success(eventId);
                        }
                    } failure:^(NSError *error)
                    {
                        
                        // Update the local echo with the error state
                        localEcho.mxkState = MXKEventStateSendingFailed;
                        [self removePendingLocalEcho:localEcho];
                        [self updateLocalEcho:localEcho];
                        
                        if (failure)
                        {
                            failure(error);
                        }
                    }];
                    
                } failure:^(NSError *error)
                {
                    
                    // Update the local echo with the error state
                    localEcho.mxkState = MXKEventStateSendingFailed;
                    [self removePendingLocalEcho:localEcho];
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
                [self removePendingLocalEcho:localEcho];
                [self updateLocalEcho:localEcho];
                
                if (failure)
                {
                    failure(nil);
                }
            }
        } failure:^(NSError *error)
        {
            
            // Update the local echo with the error state
            localEcho.mxkState = MXKEventStateSendingFailed;
            [self removePendingLocalEcho:localEcho];
            [self updateLocalEcho:localEcho];
            
            if (failure)
            {
                failure(error);
            }
        }];
        
    } failure:^(NSError *error)
    {
        
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self removePendingLocalEcho:localEcho];
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
    [_room sendMessageOfType:msgType content:msgContent success:^(NSString *eventId)
    {
        
        // Nothing to do here
        // The local echo will be removed when the corresponding event will come through the events stream
        
        if (success)
        {
            success(eventId);
        }
        
    } failure:^(NSError *error)
    {
        
        // Update the local echo with the error state
        localEcho.mxkState = MXKEventStateSendingFailed;
        [self removePendingLocalEcho:localEcho];
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
            
            UIImage* image;
            NSString *localImagePath = [MXKMediaManager cachePathForMediaWithURL:event.content[@"url"] inFolder:_roomId];
            if (localImagePath)
            {
                
                image = [MXKMediaManager loadPictureFromFilePath:localImagePath];
            }
            
            // Did the sending fail while uploading the image or while sending the corresponding Matrix event?
            // If the image is still available in the MXKMediaManager cache, the upload was not complete
            if (image)
            {
                
                // Restart sending the image from the beginning
                [self sendImage:image success:success failure:failure];
            }
            else
            {
                
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
        
        // If there is no more events in the bubble, kill it
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
    
    // Remove the event from its cell data
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
    
    // If there is no more events in the bubble, kill it
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

- (void)removeCellData:(id<MXKRoomBubbleCellDataStoring>)cellData
{
    
    // Remove potential occurrences in bubble map
    @synchronized (eventIdToBubbleMap)
    {
        NSArray *keys = eventIdToBubbleMap.allKeys;
        for (NSString *key in keys)
        {
            if (eventIdToBubbleMap[key] == cellData)
            {
                [eventIdToBubbleMap removeObjectForKey:key];
            }
        }
    }
    
    @synchronized(bubbles)
    {
        [bubbles removeObject:cellData];
    }
}

- (void)didMXRoomInitialSynced:(NSNotification *)notif
{
    
    // Refresh the room data source when the room has been initialSync'ed
    MXSession *mxSession = notif.object;
    if (mxSession == self.mxSession && [_roomId isEqualToString:notif.userInfo[kMXSessionNotificationRoomIdKey]])
    {
        
        NSLog(@"[MXKRoomDataSource] didMXRoomInitialSynced for room: %@", _roomId);
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionInitialSyncedRoomNotification object:nil];
        
        [self reload];
    }
}


#pragma mark - Asynchronous events processing
/**
 Queue an event in order to process its display later.
 
 @param event the event to process.
 @param roomState the state of the room when the event fired.
 @param direction the order of the events in the arrays
 */
- (void)queueEventForProcessing:(MXEvent*)event withRoomState:(MXRoomState*)roomState direction:(MXEventDirection)direction
{
    
    MXKQueuedEvent *queuedEvent = [[MXKQueuedEvent alloc] initWithEvent:event andRoomState:roomState direction:direction];
    
    @synchronized(eventsToProcess)
    {
        [eventsToProcess addObject:queuedEvent];
    }
}

/**
 Start processing pending events.
 
 @param onComplete a block called (on the main thread) when the processing has been done. Can be nil.
 */
- (void)processQueuedEvents:(void (^)())onComplete
{
    
    // Do the processing on the processing queue
    dispatch_async(processingQueue, ^{
        
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
        
        NSMutableArray *bubblesSnapshot = nil;
        NSUInteger unreadCount = 0;
        NSUInteger unreadBingCount = 0;
        
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
                    
                    // Check if we should bing this event
                    MXPushRule *rule = [self.mxSession.notificationCenter ruleMatchingEvent:queuedEvent.event];
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
                                        queuedEvent.event.mxkState = MXKEventStateBing;
                                        
                                        // Count unread bing message only for live events
                                        if (MXEventDirectionForwards == queuedEvent.direction)
                                        {
                                            unreadBingCount++;
                                        }
                                    }
                                }
                            }
                        }
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
                            [bubblesSnapshot insertObject:bubbleData atIndex:0];
                        }
                        else
                        {
                            [bubblesSnapshot addObject:bubbleData];
                        }
                    }
                    
                    // Store event-bubble link to the map
                    @synchronized (eventIdToBubbleMap)
                    {
                        eventIdToBubbleMap[queuedEvent.event.eventId] = bubbleData;
                    }
                    
                    // Count message sent by other users
                    if (bubbleData.isIncoming)
                    {
                        unreadCount++;
                    }
                }
            }
            
            eventsToProcessSnapshot = nil;
        }
        
        // Check whether some events have been processed
        if (bubblesSnapshot)
        {
            
            // Updated data can be displayed now
            // Synchronously wait for the end of the block execution to
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                // Check whether self has not been reloaded or destroyed
                if (self.state == MXKDataSourceStateReady)
                {
                    bubbles = bubblesSnapshot;
                    
                    // Update the total unread count
                    _unreadCount += unreadCount;
                    _unreadBingCount += unreadBingCount;
                    
                    if (self.delegate)
                    {
                        [self.delegate dataSource:self didCellChange:nil];
                    }
                    
                    // Notify the last message, unreadCount and/or unreadBingCount have changed
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
                }
                
                // Inform about the end if requested
                if (onComplete)
                {
                    onComplete();
                }
            });
        }
        else
        {
            // No new event has been added, we just inform about the end if requested.
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (onComplete)
                {
                    onComplete();
                }
            });
        }
    });
}


#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    // The view controller is going to display all messages
    // Automatically reset the counters
    _unreadCount = 0;
    _unreadBingCount = 0;
    
    // Notify the unreadCount has changed
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceMetaDataChanged object:self userInfo:nil];
    
    NSInteger count;
    @synchronized(bubbles)
    {
        count = bubbles.count;
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataAtIndex:indexPath.row];
    
    // The cell to use depends if this is a message from the user or not
    // Then use the cell class defined by the table view
    MXKRoomBubbleTableViewCell *cell;
    
    if (bubbleData.isIncoming)
    {
        if (bubbleData.isAttachment)
        {
            cell = [tableView dequeueReusableCellWithIdentifier:kMXKRoomIncomingAttachmentBubbleTableViewCellIdentifier forIndexPath:indexPath];
        }
        else
        {
            cell = [tableView dequeueReusableCellWithIdentifier:kMXKRoomIncomingTextMsgBubbleTableViewCellIdentifier forIndexPath:indexPath];
        }
    }
    else if (bubbleData.isAttachment)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:kMXKRoomOutgoingAttachmentBubbleTableViewCellIdentifier forIndexPath:indexPath];
    }
    else
    {
        cell = [tableView dequeueReusableCellWithIdentifier:kMXKRoomOutgoingTextMsgBubbleTableViewCellIdentifier forIndexPath:indexPath];
    }
    
    // Make sure we listen to user actions on the cell
    if (!cell.delegate)
    {
        cell.delegate = self;
    }
    
    // Check whether the previous bubble has been sent by the same user.
    // The user's picture and name are displayed only for the first message.
    bubbleData.isSameSenderAsPreviousBubble = NO;
    if (indexPath.row)
    {
        id<MXKRoomBubbleCellDataStoring> previousBubbleData = [self cellDataAtIndex:indexPath.row - 1];
        bubbleData.isSameSenderAsPreviousBubble = [bubbleData hasSameSenderAsBubbleCellData:previousBubbleData];
    }
    
    // Update typing flag before rendering
    bubbleData.isTyping = ([currentTypingUsers indexOfObject:bubbleData.senderId] != NSNotFound);
    // Report the current timestamp display option
    bubbleData.showBubbleDateTime = self.showBubblesDateTime;
    
    // Make the bubble display the data
    [cell render:bubbleData];
    
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
    
    [pendingLocalEchoes addObject:localEcho];
}

/**
 Remove the local echo from the pending queue.
 
 @discussion
 It can be removed from the list because we received the true event from the event stream
 or the corresponding request has failed.
 */
- (void)removePendingLocalEcho:(MXEvent*)localEcho
{
    
    [pendingLocalEchoes removeObject:localEcho];
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
                // Here the type is kMXMessageTypeImage, kMXMessageTypeAudio or kMXMessageTypeVideo
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
