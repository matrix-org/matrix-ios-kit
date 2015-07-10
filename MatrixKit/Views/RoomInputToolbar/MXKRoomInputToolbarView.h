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

#import "MXKAlert.h"

@class MXKRoomInputToolbarView;
@protocol MXKRoomInputToolbarViewDelegate <NSObject>

/**
 Tells the delegate that a MXKAlert must be presented.
 
 @param toolbarView the room input toolbar view.
 @param alert the alert to present.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView presentMXKAlert:(MXKAlert*)alert;

@optional

/**
 Tells the delegate that the user is typing or has finished typing.
 
 @param toolbarView the room input toolbar view
 @param typing YES if the user is typing inside the message composer.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView isTyping:(BOOL)typing;

/**
 Tells the delegate that toolbar height has been updated.
 
 @param toolbarView the room input toolbar view.
 @param height the updated height of toolbar view.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView heightDidChanged:(CGFloat)height;

/**
 Tells the delegate that the user wants to send a text message.
 
 @param toolbarView the room input toolbar view.
 @param textMessage the string to send.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView sendTextMessage:(NSString*)textMessage;

/**
 Tells the delegate that the user wants to send an image.
 
 @param toolbarView the room input toolbar view.
 @param image the UIImage hosting the image data to send.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView sendImage:(UIImage*)image;

/**
 Tells the delegate that the user wants to send a video.
 
 @param toolbarView the room input toolbar view.
 @param videoLocalURL the local filesystem path of the video to send.
 @param videoThumbnail the UIImage hosting a video thumbnail.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView sendVideo:(NSURL*)videoLocalURL withThumbnail:(UIImage*)videoThumbnail;

/**
 Tells the delegate that the user wants invite a matrix user.
 
 Note: `Invite matrix user` option is displayed in actions list only if the delegate implements this method.
 
 @param toolbarView the room input toolbar view.
 @param mxUserId the Matrix user id.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView inviteMatrixUser:(NSString*)mxUserId;

/**
 Tells the delegate that a media picker must be presented.
 
 Note: Media attachment is available only if the delegate implements this method.
 
 @param toolbarView the room input toolbar view.
 @param mediaPicker the media picker to present.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView presentMediaPicker:(UIImagePickerController*)mediaPicker;

/**
 Tells the delegate that a media picker must be dismissed.
 
 @param toolbarView the room input toolbar view.
 @param mediaPicker the media picker to dismiss.
 */
- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView dismissMediaPicker:(UIImagePickerController*)mediaPicker;

@end

/**
 `MXKRoomInputToolbarView` instance is a view used to handle all kinds of available inputs
 for a room (message composer, attachments selection...).
 
 By default the right button of the toolbar offers the following options: attach media, invite new members.
 By default the left button is used to send the content of the message composer.
 By default 'messageComposerContainer' is empty.
 */
@interface MXKRoomInputToolbarView : UIView <UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    /**
     The message composer container view. Your own message composer may be added inside this container.
     */
    UIView *messageComposerContainer;
    
@protected
    UIView *inputAccessoryView;
}

/**
 *  Returns the `UINib` object initialized for the tool bar view.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKRoomInputToolbarView-inherited` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 @return An initialized `MXKRoomInputToolbarView-inherited` object if successful, `nil` otherwise.
 */
+ (instancetype)roomInputToolbarView;

/**
 The delegate notified when inputs are ready.
 */
@property (nonatomic) id<MXKRoomInputToolbarViewDelegate> delegate;

/**
  A custom button displayed on the left of the toolbar view.
 */
@property (weak, nonatomic) IBOutlet UIButton *leftInputToolbarButton;

/**
 A custom button displayed on the right of the toolbar view.
 */
@property (weak, nonatomic) IBOutlet UIButton *rightInputToolbarButton;

/**
 Layout constraint between the top of the message composer container and the top of its superview.
 The first view is the container, the second is the superview.
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageComposerContainerTopConstraint;

/**
 Layout constraint between the bottom of the message composer container and the bottom of its superview.
 The first view is the superview, the second is the container.
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageComposerContainerBottomConstraint;

/**
 `onTouchUpInside` action is registered on `Touch Up Inside` event for both buttons (left and right input toolbar buttons).
 Override this method to customize user interaction handling
 
 @param button the event sender
 */
- (IBAction)onTouchUpInside:(UIButton*)button;

/**
 Prompt user to select a compression level on selected image before transferring it to the delegate
 
 @param imageInfo a dictionary containing the original image and the edited image, if an image was picked; or a filesystem URL for the movie, if a movie was picked.
 */
- (void)promptCompressionForSelectedImage:(NSDictionary*)selectedImageInfo;

/**
 The maximum height of the toolbar.
 A value <= 0 means no limit.
 */
@property CGFloat maxHeight;

/**
 The current text message in message composer.
 */
@property NSString *textMessage;

/**
 The string that should be displayed when there is no other text in message composer.
 This property may be ignored when message composer does not support placeholder display.
 */
@property (nonatomic) NSString *placeholder;

/**
 The custom accessory view associated with the message composer. This view is
 actually used to retrieve the keyboard view. Indeed the keyboard view is the superview of
 the accessory view when the message composer become the first responder.
 */
@property (readonly) UIView *inputAccessoryView;

/**
 Force dismiss keyboard.
 */
- (void)dismissKeyboard;

/**
 Dispose any resources and listener.
 */
- (void)destroy;

@end
