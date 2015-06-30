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

#import "MXKRoomInputToolbarView.h"

#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetRepresentation.h>

#import "MXKImageView.h"

#import "MXKMediaManager.h"
#import "MXKTools.h"

#define MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE    1024
#define MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE   768
#define MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE    512

NSString* const kMXKRoomInputToolbarView_originalFormatLabel = @"Actual Size: %@";
NSString* const kMXKRoomInputToolbarView_smallFormatLabel = @"Small: %@";
NSString* const kMXKRoomInputToolbarView_mediumFormatLabel = @"Medium: %@";
NSString* const kMXKRoomInputToolbarView_largeFormatLabel = @"Large: %@";

@interface MXKRoomInputToolbarView()
{
    /**
     Alert used to list options.
     */
    MXKAlert *currentAlert;
    
    /**
     Current media picker
     */
    UIImagePickerController *mediaPicker;
    
    /**
     Image selection preview (image picker does not offer a preview).
     */
    MXKImageView* imageValidationView;
    
    /**
     Temporary movie player used to retrieve video thumbnail
     */
    MPMoviePlayerController *tmpVideoPlayer;
}

@property (nonatomic) IBOutlet UIView *messageComposerContainer;

@end

@implementation MXKRoomInputToolbarView
@synthesize messageComposerContainer, inputAccessoryView;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomInputToolbarView class])
                          bundle:[NSBundle bundleForClass:[MXKRoomInputToolbarView class]]];
}

+ (instancetype)roomInputToolbarView
{
    if ([[self class] nib])
    {
        return [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
    }
    else
    {
        return [[self alloc] init];
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Finalize setup
    [self setTranslatesAutoresizingMaskIntoConstraints: NO];
    
    // Reset default container background color
    messageComposerContainer.backgroundColor = [UIColor clearColor];
    
    // Set default toolbar background color
    self.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    
    // Disable send button
    self.rightInputToolbarButton.enabled = NO;
}

- (void)dealloc
{
    inputAccessoryView = nil;
    
    [self destroy];
}

- (IBAction)onTouchUpInside:(UIButton*)button
{
    if (button == self.leftInputToolbarButton)
    {
        if (currentAlert)
        {
            [currentAlert dismiss:NO];
            currentAlert = nil;
        }
        
        // Option button has been pressed
        // List available options
        __weak typeof(self) weakSelf = self;
        
        // Check whether media attachment is supported
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:presentMediaPicker:)])
        {
            currentAlert = [[MXKAlert alloc] initWithTitle:@"Select an action:" message:nil style:MXKAlertStyleActionSheet];
            
            [currentAlert addActionWithTitle:@"Attach Media from Library" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Open media gallery
                strongSelf->mediaPicker = [[UIImagePickerController alloc] init];
                strongSelf->mediaPicker.delegate = strongSelf;
                strongSelf->mediaPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                strongSelf->mediaPicker.allowsEditing = NO;
                strongSelf->mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                [strongSelf.delegate roomInputToolbarView:strongSelf presentMediaPicker:strongSelf->mediaPicker];
            }];
            
            [currentAlert addActionWithTitle:@"Take Photo/Video" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Open Camera
                strongSelf->mediaPicker = [[UIImagePickerController alloc] init];
                strongSelf->mediaPicker.delegate = strongSelf;
                strongSelf->mediaPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                strongSelf->mediaPicker.allowsEditing = NO;
                strongSelf->mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                [strongSelf.delegate roomInputToolbarView:strongSelf presentMediaPicker:strongSelf->mediaPicker];
            }];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] Attach media is not supported");
        }
        
        // Check whether user invitation is supported
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:inviteMatrixUser:)])
        {
            
            if (!currentAlert)
            {
                currentAlert = [[MXKAlert alloc] initWithTitle:nil message:nil style:MXKAlertStyleActionSheet];
            }
            
            [currentAlert addActionWithTitle:@"Invite matrix User" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                
                // Ask for userId to invite
                strongSelf->currentAlert = [[MXKAlert alloc] initWithTitle:@"User ID:" message:nil style:MXKAlertStyleAlert];
                strongSelf->currentAlert.cancelButtonIndex = [strongSelf->currentAlert addActionWithTitle:@"Cancel" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                }];
                
                [strongSelf->currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField)
                {
                    textField.secureTextEntry = NO;
                    textField.placeholder = @"ex: @bob:homeserver";
                }];
                [strongSelf->currentAlert addActionWithTitle:@"Invite" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                {
                    UITextField *textField = [alert textFieldAtIndex:0];
                    NSString *userId = textField.text;
                    
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    if (userId.length)
                    {
                        [strongSelf.delegate roomInputToolbarView:strongSelf inviteMatrixUser:userId];
                    }
                }];
                
                [strongSelf.delegate roomInputToolbarView:strongSelf presentMXKAlert:strongSelf->currentAlert];
            }];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] Invitation is not supported");
        }
        
        if (currentAlert)
        {
            currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:@"Cancel" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
            }];
            
            currentAlert.sourceView = button;
            
            [self.delegate roomInputToolbarView:self presentMXKAlert:currentAlert];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] No option is supported");
        }
    }
    else if (button == self.rightInputToolbarButton)
    {
        
        NSString *message = self.textMessage;
        
        // Reset message
        self.textMessage = nil;
        
        // Send button has been pressed
        if (message.length && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendTextMessage:)])
        {
            [self.delegate roomInputToolbarView:self sendTextMessage:message];
        }
    }
}

- (void)setPlaceholder:(NSString *)inPlaceholder
{
    _placeholder = inPlaceholder;
}

- (void)dismissKeyboard
{
}

- (void)destroy
{
    [self dismissImageValidationView];
    
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    if (mediaPicker)
    {
        [self dismissMediaPicker];
        mediaPicker = nil;
    }
    
    self.delegate = nil;
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage])
    {
        
        /*
         NSData *dataOfGif = [NSData dataWithContentsOfFile: [info objectForKey:UIImagePickerControllerReferenceURL]];
         
         NSLog(@"%d", dataOfGif.length);
         
         ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
         [library assetForURL:[info objectForKey:UIImagePickerControllerReferenceURL] resultBlock:^(ALAsset *asset)
         {
         
         NSLog(@"%@", asset.defaultRepresentation.metadata);
         
         
         NSLog(@"%@", asset.defaultRepresentation.url);
         
         NSData *dataOfGif = [NSData dataWithContentsOfURL: asset.defaultRepresentation.url];
         
         NSLog(@"%d", dataOfGif.length);
         ;
         
         } failureBlock:^(NSError *error)
         {
         
         }];
         
         */
        
        if (![self.delegate respondsToSelector:@selector(roomInputToolbarView:sendImage:)])
        {
            NSLog(@"[MXKRoomInputToolbarView] Attach image is not supported");
        }
        else
        {
            UIImage *selectedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
            if (selectedImage)
            {
                // media picker does not offer a preview
                // so add a preview to let the user validates his selection
                if (picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary)
                {
                    __weak typeof(self) weakSelf = self;
                    
                    imageValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                    imageValidationView.stretchable = YES;
                    
                    // the user validates the image
                    [imageValidationView setRightButtonTitle:@"OK" handler:^(MXKImageView* imageView, NSString* buttonTitle)
                    {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        
                        // Dismiss the image view
                        [strongSelf dismissImageValidationView];
                       
                        // prompt user about image compression
                        [strongSelf promptCompressionForSelectedImage:info];
                    }];
                    
                    // the user wants to use an other image
                    [imageValidationView setLeftButtonTitle:@"Cancel" handler:^(MXKImageView* imageView, NSString* buttonTitle)
                    {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        
                        // dismiss the image view
                        [strongSelf dismissImageValidationView];
                        
                        // Open again media gallery
                        strongSelf->mediaPicker = [[UIImagePickerController alloc] init];
                        strongSelf->mediaPicker.delegate = strongSelf;
                        strongSelf->mediaPicker.sourceType = picker.sourceType;
                        strongSelf->mediaPicker.allowsEditing = NO;
                        strongSelf->mediaPicker.mediaTypes = picker.mediaTypes;
                        [strongSelf.delegate roomInputToolbarView:strongSelf presentMediaPicker:strongSelf->mediaPicker];
                    }];
                    
                    imageValidationView.image = selectedImage;
                    [imageValidationView showFullScreen];
                }
                else
                {
                    // Save the original image in user's photos library and suggest compression before sending image
                    [MXKMediaManager saveImageToPhotosLibrary:selectedImage success:nil failure:nil];
                    [self promptCompressionForSelectedImage:info];
                }
            }
        }
    }
    else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie])
    {
        NSURL* selectedVideo = [info objectForKey:UIImagePickerControllerMediaURL];
        
        // Check the selected video, and ignore multiple calls (observed when user pressed several time Choose button)
        if (selectedVideo && !tmpVideoPlayer)
        {
            if (picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary)
            {
                [MXKMediaManager saveMediaToPhotosLibrary:selectedVideo isImage:NO success:nil failure:nil];
            }
            
            // Create video thumbnail
            tmpVideoPlayer = [[MPMoviePlayerController alloc] initWithContentURL:selectedVideo];
            if (tmpVideoPlayer)
            {
                [tmpVideoPlayer setShouldAutoplay:NO];
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(moviePlayerThumbnailImageRequestDidFinishNotification:)
                                                             name:MPMoviePlayerThumbnailImageRequestDidFinishNotification
                                                           object:nil];
                [tmpVideoPlayer requestThumbnailImagesAtTimes:@[@1.0f] timeOption:MPMovieTimeOptionNearestKeyFrame];
                // We will finalize video attachment when thumbnail will be available (see movie player callback)
                return;
            }
        }
    }
    
    [self dismissMediaPicker];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissMediaPicker];
}

- (void)dismissImageValidationView
{
    if (imageValidationView)
    {
        [imageValidationView dismissSelection];
        [imageValidationView removeFromSuperview];
        imageValidationView = nil;
    }
}

- (void)promptCompressionForSelectedImage:(NSDictionary*)selectedImageInfo
{
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    UIImage *selectedImage = [selectedImageInfo objectForKey:UIImagePickerControllerOriginalImage];
    CGSize originalSize = selectedImage.size;
    NSLog(@"Selected image size : %f %f", originalSize.width, originalSize.height);
    
    [self getSelectedImageFileData:selectedImageInfo success:^(NSData *selectedImageFileData) {
        
        long long smallFilesize  = 0;
        long long mediumFilesize = 0;
        long long largeFilesize  = 0;
        
        // succeed to get the file size (provided by the photo library)
        long long originalFileSize = selectedImageFileData.length;
        NSLog(@"- use the photo library file size: %tu", originalFileSize);
        
        CGFloat maxSize = MAX(originalSize.width, originalSize.height);
        if (maxSize >= MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE)
        {
            CGFloat factor = MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE / maxSize;
            smallFilesize = factor * factor * originalFileSize;
        }
        else
        {
            NSLog(@"- too small to fit in %d", MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE);
        }
        
        if (maxSize >= MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE)
        {
            CGFloat factor = MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE / maxSize;
            mediumFilesize = factor * factor * originalFileSize;
        }
        else
        {
            NSLog(@"- too small to fit in %d", MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE);
        }
        
        if (maxSize >= MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE)
        {
            CGFloat factor = MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE / maxSize;
            largeFilesize = factor * factor * originalFileSize;
        }
        else
        {
            NSLog(@"- too small to fit in %d", MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE);
        }
        
        if (smallFilesize || mediumFilesize || largeFilesize)
        {
            currentAlert = [[MXKAlert alloc] initWithTitle:@"Do you want to send as:" message:nil style:MXKAlertStyleActionSheet];
            __weak typeof(self) weakSelf = self;
            
            if (smallFilesize)
            {
                NSString *title = [NSString stringWithFormat:kMXKRoomInputToolbarView_smallFormatLabel, [MXKTools fileSizeToString: (int)smallFilesize]];
                [currentAlert addActionWithTitle:title style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Send the small image
                    UIImage *smallImage = [MXKTools resize:selectedImage toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE)];
                    [strongSelf.delegate roomInputToolbarView:weakSelf sendImage:smallImage];
                }];
            }
            
            if (mediumFilesize)
            {
                NSString *title = [NSString stringWithFormat:kMXKRoomInputToolbarView_mediumFormatLabel, [MXKTools fileSizeToString: (int)mediumFilesize]];
                [currentAlert addActionWithTitle:title style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Send the medium image
                    UIImage *mediumImage = [MXKTools resize:selectedImage toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE)];
                    [strongSelf.delegate roomInputToolbarView:weakSelf sendImage:mediumImage];
                }];
            }
            
            if (largeFilesize)
            {
                NSString *title = [NSString stringWithFormat:kMXKRoomInputToolbarView_largeFormatLabel, [MXKTools fileSizeToString: (int)largeFilesize]];
                [currentAlert addActionWithTitle:title style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Send the large image
                    UIImage *largeImage = [MXKTools resize:selectedImage toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE)];
                    [strongSelf.delegate roomInputToolbarView:weakSelf sendImage:largeImage];
                }];
            }
            
            NSString *title = [NSString stringWithFormat:kMXKRoomInputToolbarView_originalFormatLabel, [MXKTools fileSizeToString: (int)originalFileSize]];
            [currentAlert addActionWithTitle:title style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Send the original image
                [strongSelf.delegate roomInputToolbarView:weakSelf sendImage:selectedImage];
            }];
            
            currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:@"Cancel" style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
            }];
            
            currentAlert.sourceView = self;
            
            [self.delegate roomInputToolbarView:self presentMXKAlert:currentAlert];
        }
        else
        {
            // Send the original image
            [self.delegate roomInputToolbarView:self sendImage:selectedImage];
        }
    } failure:^(NSError *error) {
        
        // Send the original image
        [self.delegate roomInputToolbarView:self sendImage:selectedImage];
    }];
}

- (void)getSelectedImageFileData:(NSDictionary*)selectedImageInfo success:(void (^)(NSData *selectedImageFileData))success failure:(void (^)(NSError *error))failure
{
    ALAssetsLibrary *assetLibrary=[[ALAssetsLibrary alloc] init];
    [assetLibrary assetForURL:[selectedImageInfo valueForKey:UIImagePickerControllerReferenceURL] resultBlock:^(ALAsset *asset) {
        
        ALAssetRepresentation* assetRepresentation = [asset defaultRepresentation];
        NSData *selectedImageFileData;
        
        // Check whether the user select an image with a cropping
        if ([[assetRepresentation metadata] objectForKey:@"AdjustmentXMP"])
        {
            // In case of crop we have to consider the original image
            selectedImageFileData = UIImageJPEGRepresentation([selectedImageInfo objectForKey:UIImagePickerControllerOriginalImage], 1.0);
        }
        else
        {
            // cannot use assetRepresentation size to get the image size
            // it gives wrong result with panorama picture
            unsigned long imageDataSize = (unsigned long)[assetRepresentation size];
            uint8_t* imageDataBytes = malloc(imageDataSize);
            [assetRepresentation getBytes:imageDataBytes fromOffset:0 length:imageDataSize error:nil];
            
            selectedImageFileData = [NSData dataWithBytesNoCopy:imageDataBytes length:imageDataSize freeWhenDone:YES];
        }
        
        if (success)
        {
            success (selectedImageFileData);
        }
    } failureBlock:^(NSError *err) {
        
        if (failure)
        {
            failure (err);
        }
    }];
}

#pragma mark - Media Picker handling

- (void)dismissMediaPicker
{
    mediaPicker.delegate = nil;
    
    if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:dismissMediaPicker:)])
    {
        [self.delegate roomInputToolbarView:self dismissMediaPicker:mediaPicker];
    }
}

- (void)moviePlayerThumbnailImageRequestDidFinishNotification:(NSNotification *)notification
{
    // Finalize video attachment
    UIImage* videoThumbnail = [[notification userInfo] objectForKey:MPMoviePlayerThumbnailImageKey];
    NSURL* selectedVideo = [tmpVideoPlayer contentURL];
    [tmpVideoPlayer stop];
    tmpVideoPlayer = nil;
    
    if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:sendVideo:withThumbnail:)])
    {
        [self.delegate roomInputToolbarView:self sendVideo:selectedVideo withThumbnail:videoThumbnail];
    }
    else
    {
        NSLog(@"[MXKRoomInputToolbarView] Attach video is not supported");
    }
    
    [self dismissMediaPicker];
}

@end
