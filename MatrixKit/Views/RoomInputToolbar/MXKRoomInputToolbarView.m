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

#import "NSBundle+MatrixKit.h"
#import "NSData+MatrixKit.h"

#define MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE    1024
#define MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE   768
#define MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE    512

NSString *const kPasteboardItemPrefix = @"pasteboard-";

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
     Array of validation views (MXKImageView instances)
     */
    NSMutableArray *validationViews;
    
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
    
    // Localize string
    [_rightInputToolbarButton setTitle:[NSBundle mxk_localizedStringForKey:@"send"] forState:UIControlStateNormal];
    [_rightInputToolbarButton setTitle:[NSBundle mxk_localizedStringForKey:@"send"] forState:UIControlStateHighlighted];
    
    validationViews = [NSMutableArray array];
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
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:presentViewController:)])
        {
            currentAlert = [[MXKAlert alloc] initWithTitle:nil message:nil style:MXKAlertStyleActionSheet];
            
            [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"attach_media"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Open media gallery
                strongSelf->mediaPicker = [[UIImagePickerController alloc] init];
                strongSelf->mediaPicker.delegate = strongSelf;
                strongSelf->mediaPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                strongSelf->mediaPicker.allowsEditing = NO;
                strongSelf->mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                [strongSelf.delegate roomInputToolbarView:strongSelf presentViewController:strongSelf->mediaPicker];
            }];
            
            [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"capture_media"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Open Camera
                strongSelf->mediaPicker = [[UIImagePickerController alloc] init];
                strongSelf->mediaPicker.delegate = strongSelf;
                strongSelf->mediaPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                strongSelf->mediaPicker.allowsEditing = NO;
                strongSelf->mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                [strongSelf.delegate roomInputToolbarView:strongSelf presentViewController:strongSelf->mediaPicker];
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
            
            [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"invite_user"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
            {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                
                // Ask for userId to invite
                strongSelf->currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"user_id_title"] message:nil style:MXKAlertStyleAlert];
                strongSelf->currentAlert.cancelButtonIndex = [strongSelf->currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
                {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                }];
                
                [strongSelf->currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField)
                {
                    textField.secureTextEntry = NO;
                    textField.placeholder = [NSBundle mxk_localizedStringForKey:@"user_id_placeholder"];
                }];
                [strongSelf->currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"invite"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
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
            currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
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
    [self dismissValidationViews];
    validationViews = nil;
    
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    [self dismissMediaPicker];
    
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
                // Media picker does not offer a preview
                // so add a preview to let the user validates his selection
                if (picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary)
                {
                    __weak typeof(self) weakSelf = self;
                    
                    MXKImageView *imageValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                    imageValidationView.stretchable = YES;
                    
                    // the user validates the image
                    [imageValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                    {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        
                        // Dismiss the image view
                        [strongSelf dismissValidationViews];
                       
                        // prompt user about image compression
                        [strongSelf promptCompressionForSelectedImage:info];
                    }];
                    
                    // the user wants to use an other image
                    [imageValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                    {
                        __strong __typeof(weakSelf)strongSelf = weakSelf;
                        
                        // dismiss the image view
                        [strongSelf dismissValidationViews];
                        
                        // Open again media gallery
                        strongSelf->mediaPicker = [[UIImagePickerController alloc] init];
                        strongSelf->mediaPicker.delegate = strongSelf;
                        strongSelf->mediaPicker.sourceType = picker.sourceType;
                        strongSelf->mediaPicker.allowsEditing = NO;
                        strongSelf->mediaPicker.mediaTypes = picker.mediaTypes;
                        [strongSelf.delegate roomInputToolbarView:strongSelf presentViewController:strongSelf->mediaPicker];
                    }];
                    
                    imageValidationView.image = selectedImage;
                    
                    [validationViews addObject:imageValidationView];
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
            if (picker.sourceType != UIImagePickerControllerSourceTypePhotoLibrary)
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

- (void)dismissValidationViews
{
    for (MXKImageView *validationView in validationViews)
    {
        [validationView dismissSelection];
        [validationView removeFromSuperview];
    }
    
    [validationViews removeAllObjects];
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
            currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"attachment_size_prompt"] message:nil style:MXKAlertStyleActionSheet];
            __weak typeof(self) weakSelf = self;
            
            if (smallFilesize)
            {
                NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_small"], [MXKTools fileSizeToString: (int)smallFilesize]];
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
                NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_medium"], [MXKTools fileSizeToString: (int)mediumFilesize]];
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
                NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_large"], [MXKTools fileSizeToString: (int)largeFilesize]];
                [currentAlert addActionWithTitle:title style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Send the large image
                    UIImage *largeImage = [MXKTools resize:selectedImage toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE)];
                    [strongSelf.delegate roomInputToolbarView:weakSelf sendImage:largeImage];
                }];
            }
            
            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_original"], [MXKTools fileSizeToString: (int)originalFileSize]];
            [currentAlert addActionWithTitle:title style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf->currentAlert = nil;
                
                // Send the original image
                [strongSelf.delegate roomInputToolbarView:weakSelf sendImage:selectedImage];
            }];
            
            currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
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
        
        NSData *selectedImageFileData;
        
        // asset may be nil if the image is not saved in photos library
        if (asset)
        {
            ALAssetRepresentation* assetRepresentation = [asset defaultRepresentation];
            
            // Check whether the user select an image with a cropping
            if ([[assetRepresentation metadata] objectForKey:@"AdjustmentXMP"])
            {
                // In case of crop we have to consider the original image
                selectedImageFileData = UIImageJPEGRepresentation([selectedImageInfo objectForKey:UIImagePickerControllerOriginalImage], 0.9);
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
        }
        else
        {
            selectedImageFileData = UIImageJPEGRepresentation([selectedImageInfo objectForKey:UIImagePickerControllerOriginalImage], 0.9);
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
    if (mediaPicker)
    {
        mediaPicker.delegate = nil;
        
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:dismissViewControllerAnimated:completion:)])
        {
            [self.delegate roomInputToolbarView:self dismissViewControllerAnimated:NO completion:^{
                mediaPicker = nil;
            }];
        }
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
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerThumbnailImageRequestDidFinishNotification object:nil];
    
    [self dismissMediaPicker];
}

#pragma mark - Clipboard - Handle image/data paste from general pasteboard

- (void)paste:(id)sender
{
    UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
    if (generalPasteboard.numberOfItems)
    {
        [self dismissValidationViews];
        [self dismissKeyboard];
        
        __weak typeof(self) weakSelf = self;
        
        for (NSDictionary* dict in generalPasteboard.items)
        {
            NSArray* allKeys = dict.allKeys;
            for (NSString* key in allKeys)
            {
                NSString* MIMEType = (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)key, kUTTagClassMIMEType);
                if ([MIMEType hasPrefix:@"image/"])
                {
                    UIImage *pasteboardImage = [dict valueForKey:key];
                    if (pasteboardImage)
                    {
                        MXKImageView *imageValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                        imageValidationView.stretchable = YES;
                        
                        // the user validates the image
                        [imageValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             __strong __typeof(weakSelf)strongSelf = weakSelf;
                             
                             // dismiss the image validation view
                             [imageView dismissSelection];
                             [imageView removeFromSuperview];
                             [validationViews removeObject:imageView];
                             
                             [strongSelf.delegate roomInputToolbarView:strongSelf sendImage:pasteboardImage];
                         }];
                        
                        // the user wants to use an other image
                        [imageValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             // dismiss the image validation view
                             [imageView dismissSelection];
                             [imageView removeFromSuperview];
                             [validationViews removeObject:imageView];
                             
                         }];
                        
                        imageValidationView.image = pasteboardImage;
                        
                        [validationViews addObject:imageValidationView];
                        [imageValidationView showFullScreen];
                    }
                    
                    break;
                }
                else if ([MIMEType hasPrefix:@"video/"])
                {
                    NSData *pasteboardVideoData = [dict valueForKey:key];
                    NSString *fakePasteboardURL = [NSString stringWithFormat:@"%@%@", kPasteboardItemPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
                    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakePasteboardURL andType:MIMEType inFolder:nil];
                    
                    if ([MXKMediaManager writeMediaData:pasteboardVideoData toFilePath:cacheFilePath])
                    {
                        NSURL *videoLocalURL = [NSURL fileURLWithPath:cacheFilePath isDirectory:NO];
                        
                        // Retrieve the video frame at 1 sec to define the video thumbnail
                        AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:videoLocalURL options:nil];
                        AVAssetImageGenerator *assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
                        assetImageGenerator.appliesPreferredTrackTransform = YES;
                        CMTime time = CMTimeMake(1, 1);
                        CGImageRef imageRef = [assetImageGenerator copyCGImageAtTime:time actualTime:NULL error:nil];
                        UIImage* videoThumbnail = [[UIImage alloc] initWithCGImage:imageRef];
                        
                        MXKImageView *videoValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                        videoValidationView.stretchable = YES;
                        
                        // the user validates the image
                        [videoValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             __strong __typeof(weakSelf)strongSelf = weakSelf;
                             
                             // dismiss the video validation view
                             [imageView dismissSelection];
                             [imageView removeFromSuperview];
                             [validationViews removeObject:imageView];
                             
                             [strongSelf.delegate roomInputToolbarView:strongSelf sendVideo:videoLocalURL withThumbnail:videoThumbnail];
                         }];
                        
                        // the user wants to use an other image
                        [videoValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             // dismiss the video validation view
                             [imageView dismissSelection];
                             [imageView removeFromSuperview];
                             [validationViews removeObject:imageView];
                             
                         }];
                        
                        videoValidationView.image = videoThumbnail;
                        
                        [validationViews addObject:videoValidationView];
                        [videoValidationView showFullScreen];
                        
                        // Add video icon
                        UIImageView *videoIconView = [[UIImageView alloc] initWithImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_video"]];
                        videoIconView.center = videoValidationView.center;
                        videoIconView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
                        [videoValidationView addSubview:videoIconView];
                    }
                    break;
                }
                else if ([MIMEType hasPrefix:@"application/"])
                {
                    NSData *pasteboardDocumentData = [dict valueForKey:key];
                    NSString *fakePasteboardURL = [NSString stringWithFormat:@"%@%@", kPasteboardItemPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
                    NSString *cacheFilePath = [MXKMediaManager cachePathForMediaWithURL:fakePasteboardURL andType:MIMEType inFolder:nil];
                    
                    if ([MXKMediaManager writeMediaData:pasteboardDocumentData toFilePath:cacheFilePath])
                    {
                        NSURL *localURL = [NSURL fileURLWithPath:cacheFilePath isDirectory:NO];
                        
                        MXKImageView *docValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                        docValidationView.stretchable = YES;
                        
                        // the user validates the image
                        [docValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             __strong __typeof(weakSelf)strongSelf = weakSelf;
                             
                             // dismiss the video validation view
                             [imageView dismissSelection];
                             [imageView removeFromSuperview];
                             [validationViews removeObject:imageView];
                             
                             [strongSelf.delegate roomInputToolbarView:strongSelf sendFile:localURL withMimeType:MIMEType];
                         }];
                        
                        // the user wants to use an other image
                        [docValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             // dismiss the video validation view
                             [imageView dismissSelection];
                             [imageView removeFromSuperview];
                             [validationViews removeObject:imageView];
                             
                         }];
                        
                        docValidationView.image = nil;
                        
                        [validationViews addObject:docValidationView];
                        [docValidationView showFullScreen];
                        
                        // Create a fake name based on fileData to keep the same name for the same file.
                        NSString *dataHash = [pasteboardDocumentData MD5];
                        if (dataHash.length > 7)
                        {
                            // Crop
                            dataHash = [dataHash substringToIndex:7];
                        }
                        NSString *extension = [MXKTools fileExtensionFromContentType:MIMEType];
                        NSString *filename = [NSString stringWithFormat:@"file_%@%@", dataHash, extension];
                        
                        // Display this file name
                        UITextView *fileNameTextView = [[UITextView alloc] initWithFrame:CGRectZero];
                        fileNameTextView.text = filename;
                        fileNameTextView.font = [UIFont systemFontOfSize:17];
                        [fileNameTextView sizeToFit];
                        fileNameTextView.center = docValidationView.center;
                        fileNameTextView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
                        
                        docValidationView.backgroundColor = [UIColor whiteColor];
                        [docValidationView addSubview:fileNameTextView];
                    }
                    break;
                }
            }
        }
    }
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(paste:))
    {
        // Check whether some data listed in general pasteboard can be paste
        UIPasteboard *generalPasteboard = [UIPasteboard generalPasteboard];
        if (generalPasteboard.numberOfItems)
        {
            for (NSDictionary* dict in generalPasteboard.items)
            {
                NSArray* allKeys = dict.allKeys;
                for (NSString* key in allKeys)
                {
                    NSString* MIMEType = (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)key, kUTTagClassMIMEType);
                    if ([MIMEType hasPrefix:@"image/"] || [MIMEType hasPrefix:@"video/"] || [MIMEType hasPrefix:@"application/"])
                    {
                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}

@end
