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

#import <MatrixSDK/MatrixSDK.h>

#import "MXKViewController.h"
#import "MXKAttachment.h"

@protocol MXKRoomAttachmentsViewControllerDelegate;

/**
 This view controller displays attachments of a room. Only one matrix session is handled by this view controller.
 Only one attachment is displayed at once, the user is able to swipe one by one the room attachments.
 */
@interface MXKRoomAttachmentsViewController : MXKViewController <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIDocumentInteractionControllerDelegate>

@property (nonatomic) IBOutlet UICollectionView *attachmentsCollection;

/**
 The attachments array.
 */
@property (nonatomic, readonly) NSArray *attachments;

/**
 Tell whether all attachments have been retrieved from the room history (In that case no attachment can be added at the end of attachments array).
 */
@property (nonatomic) BOOL *complete;

/**
 The delegate notified when inputs are ready.
 */
@property (nonatomic) id<MXKRoomAttachmentsViewControllerDelegate> delegate;

#pragma mark - Class methods

/**
 Returns the `UINib` object initialized for a `MXKRoomAttachmentsViewController`.

 @return The initialized `UINib` object or `nil` if there were errors during initialization
 or the nib file could not be located.
 
 @discussion You may override this method to provide a customized nib. If you do,
 you should also override `roomViewController` to return your
 view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKRoomAttachmentsViewController` object.

 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `MXKRoomAttachmentsViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)roomAttachmentsViewController;

/**
 Display attachments of a room by focusing on the attachment related to the provided event id.

 @param attachmentArray the array of attachments (MXKAttachment instances).
 @param eventId the identifier of the current selected attachment.
 */
- (void)displayAttachments:(NSArray*)attachmentArray focusOn:(NSString*)eventId;

@end

@protocol MXKRoomAttachmentsViewControllerDelegate <NSObject>

/**
 Tells the delegate that the end of attachments array has been reached. 
 This method is called only if 'complete' is NO.
 
 The delegate provides the older attachments by using [MXKRoomAttachmentsViewController insertAttachment: atIndex:].
 When no new attachment is available, the delegate must update the property 'complete'.
 
 @param roomAttachmentsViewController the attachments view controller.
 @param eventId the event identifier of the last attachment.
 @return a boolean which tells whether some new attachments may be added or not.
 */
- (BOOL)roomAttachmentsViewController:(MXKRoomAttachmentsViewController*)roomAttachmentsViewController paginateAttachmentAfter:(NSString*)eventId;
@end
