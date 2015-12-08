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

#import <UIKit/UIKit.h>

#import "MXKDataSource.h"
#import "MXKRoomBubbleCellDataStoring.h"
#import "MXKEventFormatter.h"


/**
 define the threshold which triggers a bubbles count flush.
 */

#define MXKROOMDATASOURCE_CACHED_BUBBLES_COUNT_THRESHOLD 30

/**
 List the supported pagination of the rendered room bubble cells
 */
typedef enum : NSUInteger
{
    /**
     No pagination
     */
    MXKRoomDataSourceBubblesPaginationNone,
    /**
     The rendered room bubble cells are paginated per day
     */
    MXKRoomDataSourceBubblesPaginationPerDay
    
} MXKRoomDataSourceBubblesPagination;


#pragma mark - Cells identifiers

/**
 String identifying the object used to store and prepare room bubble data.
 */
extern NSString *const kMXKRoomBubbleCellDataIdentifier;


#pragma mark - Notifications
/**
 Posted when an information about the room has changed.
 Tracked informations are: lastMessage, unreadCount, unreadBingCount.
 The notification object is the `MXKRoomDataSource` instance.
 */
extern NSString *const kMXKRoomDataSourceMetaDataChanged;

/**
 Posted when a server sync starts or ends (depend on 'serverSyncEventCount').
 The notification object is the `MXKRoomDataSource` instance.
 */
extern NSString *const kMXKRoomDataSourceSyncStatusChanged;

#pragma mark - MXKRoomDataSource
@protocol MXKRoomBubbleCellDataStoring;

/**
 The data source for `MXKRoomViewController`.
 */
@interface MXKRoomDataSource : MXKDataSource <UITableViewDataSource>
{
@protected

    /**
     The data for the cells served by `MXKRoomDataSource`.
     */
    NSMutableArray *bubbles;

    /**
     The queue of events that need to be processed in order to compute their display.
     */
    NSMutableArray *eventsToProcess;
}

/**
 The id of the room managed by the data source.
 */
@property (nonatomic, readonly) NSString *roomId;

/**
 The room the data comes from.
 The object is defined when the MXSession has data for the room
 */
@property (nonatomic, readonly) MXRoom *room;

/**
 The last event in the room that matches the `eventsFilterForMessages` property.
 */
@property (nonatomic, readonly) MXEvent *lastMessage;

/**
 The list of the attachments with thumbnail in the current available bubbles (MXKAttachment instances).
 */
@property (nonatomic, readonly) NSArray *attachmentsWithThumbnail;

/**
 The number of unread messages.
 It is automatically reset to 0 when the view controller calls numberOfRowsInSection.
 */
@property (nonatomic, readonly) NSUInteger unreadCount;

/**
 The number of unread messages that match the push notification rules.
 It is automatically reset to 0 when the view controller calls numberOfRowsInSection.
 */
@property (nonatomic, readonly) NSUInteger unreadBingCount;

/**
 The events are processed asynchronously. This property counts the number of queued events
 during server sync for which the process is pending.
 */
@property (nonatomic, readonly) NSInteger serverSyncEventCount;

/**
 The current text message partially typed in text input (use nil to reset it).
 */
@property (nonatomic) NSString *partialTextMessage;


#pragma mark - Configuration
/**
 The type of events to display as messages.
 */
@property (nonatomic) NSArray *eventsFilterForMessages;

/**
 The events to display texts formatter.
 `MXKRoomBubbleCellDataStoring` instances can use it to format text.
 */
@property (nonatomic) MXKEventFormatter *eventFormatter;

/**
 Show the date time label in rendered room bubble cells (NO by default)
 */
@property (nonatomic) BOOL showBubblesDateTime;

/**
  The date time label is not managed by MatrixKit. (NO by default).
 */
@property (nonatomic) BOOL useCustomDateTimeLabel;

/**
 Show the receipts in rendered bubble cell (YES by default)
 */
@property (nonatomic) BOOL showBubbleReceipts;

/**
 Show the typing notifications of other room members in the chat history (YES by default).
 */
@property (nonatomic) BOOL showTypingNotifications;

/**
 The pagination applied on the rendered room bubble cells (MXKRoomDataSourceBubblesPaginationNone by default)
 */
@property (nonatomic) MXKRoomDataSourceBubblesPagination bubblesPagination;

/**
 Max nbr of cached bubbles when there is no delegate.
 The default value is 30.
 */
@property (nonatomic) unsigned long maxBackgroundCachedBubblesCount;

#pragma mark - Life cycle
/**
 Initialise the data source to serve data corresponding to the passed room.
 
 @param roomId the id of the room to get data from.
 @param mxSession the Matrix session to get data from.
 @return the newly created instance.
 */
- (instancetype)initWithRoomId:(NSString*)roomId andMatrixSession:(MXSession*)mxSession;

/**
 Mark all messages as read
 */
- (void)markAllAsRead;

/**
 Reduce memory usage by releasing room data if the number of bubbles is over the provided limit 'maxBubbleNb'.
 
 This operation is ignored if some local echoes are pending or if unread messages counter is not nil.
 
 @param maxBubbleNb The room bubble data are released only if the number of bubbles is over this limit.
 */
- (void)limitMemoryUsage:(NSInteger)maxBubbleNb;

/**
 Force data reload.
 */
- (void)reload;

#pragma mark - Public methods
/**
 Get the data for the cell at the given index.

 @param index the index of the cell in the array
 @return the cell data
 */
- (id<MXKRoomBubbleCellDataStoring>)cellDataAtIndex:(NSInteger)index;

/**
 Get the data for the cell which contains the event with the provided event id.

 @param eventId the event identifier
 @return the cell data
 */
- (id<MXKRoomBubbleCellDataStoring>)cellDataOfEventWithEventId:(NSString*)eventId;

/**
 Get the index of the cell which contains the event with the provided event id.

 @param eventId the event identifier
 @return the index of the concerned cell (NSNotFound if none).
 */
- (NSInteger)indexOfCellDataWithEventId:(NSString *)eventId;

/**
 Get height of the cell at the given index.

 @param index the index of the cell in the array.
 @param maxWidth the maximum available width.
 @return the cell height.
 */
- (CGFloat)cellHeightAtIndex:(NSInteger)index withMaximumWidth:(CGFloat)maxWidth;

#pragma mark - Pagination
/**
 Load more messages from the history.
 This method fails (with nil error) if the data source is not ready (see `MXKDataSourceStateReady`).
 
 @param numItems the number of items to get.
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)paginateBackMessages:(NSUInteger)numItems success:(void (^)())success failure:(void (^)(NSError *error))failure;

/**
 Load enough messages to fill the rect.
 This method fails (with nil error) if the data source is not ready (see `MXKDataSourceStateReady`).
 
 @param the rect to fill.
 @param success a block called when the operation succeeds.
 @param failure a block called when the operation fails.
 */
- (void)paginateBackMessagesToFillRect:(CGRect)rect success:(void (^)())success failure:(void (^)(NSError *error))failure;


#pragma mark - Sending
/**
 Send a text message to the room.
 
 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.

 @param text the text to send.
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendTextMessage:(NSString*)text
                success:(void (^)(NSString *eventId))success
                failure:(void (^)(NSError *error))failure;

/**
 Send an image to the room.

 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.

 @param image the UIImage containing the image to send.
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendImage:(UIImage*)image
          success:(void (^)(NSString *eventId))success
          failure:(void (^)(NSError *error))failure;

/**
 Send an image to the room.
 
 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.
 
 @param imageLocalURL the local filesystem path of the image to send.
 @param mimeType the mime type of the image
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendImage:(NSURL *)imageLocalURL mimeType:(NSString*)mimetype success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure;

/**
 Send an video to the room.

 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.

 @param videoLocalURL the local filesystem path of the video to send.
 @param videoThumbnail the UIImage hosting a video thumbnail.
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendVideo:(NSURL*)videoLocalURL
    withThumbnail:(UIImage*)videoThumbnail
          success:(void (^)(NSString *eventId))success
          failure:(void (^)(NSError *error))failure;

/**
 Send a file to the room.
 
 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.
 
 @param fileLocalURL the local filesystem path of the file to send.
 @param mimeType the mime type of the file.
 @param success A block object called when the operation succeeds. It returns
 the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendFile:(NSURL*)fileLocalURL
        mimeType:(NSString*)mimeType
          success:(void (^)(NSString *eventId))success
          failure:(void (^)(NSError *error))failure;

/**
 Send a room message to a room.
 
 While sending, a fake event will be echoed in the messages list.
 Once complete, this local echo will be replaced by the event saved by the homeserver.

 @param msgType the type of the message. @see MXMessageType.
 @param content the message content that will be sent to the server as a JSON object.
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)sendMessageOfType:(MXMessageType)msgType
                  content:(NSDictionary*)content
                  success:(void (^)(NSString *eventId))success
                  failure:(void (^)(NSError *error))failure;

/**
 Resend a room message event.
 
 The echo message corresponding to the event will be removed and a new echo message
 will be added at the end of the room history.

 @param the id of the event to resend.
 @param success A block object called when the operation succeeds. It returns
                the event id of the event generated on the home server
 @param failure A block object called when the operation fails.
 */
- (void)resendEventWithEventId:(NSString*)eventId
                  success:(void (^)(NSString *eventId))success
                  failure:(void (^)(NSError *error))failure;


#pragma mark - Events management
/**
 Get an event loaded in this room datasource.

 @param the id of the event to retrieve.
 @return the MXEvent object or nil if not found.
 */
- (MXEvent *)eventWithEventId:(NSString *)eventId;

/**
 Remove an event from the events loaded by room datasource.

 @param the id of the event to remove.
 */
- (void)removeEventWithEventId:(NSString *)eventId;

@end
