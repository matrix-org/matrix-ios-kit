/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
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

#import <Photos/Photos.h>
#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetRepresentation.h>

#import "MXKImageView.h"

#import "MXMediaManager.h"
#import "MXKTools.h"

#import "NSBundle+MatrixKit.h"

#define MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE    1024
#define MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE   768
#define MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE    512

NSString *const kPasteboardItemPrefix = @"pasteboard-";

@interface MXKRoomInputToolbarView()
{
    /**
     Alert used to list options.
     */
    UIAlertController *optionsListView;
    
    /**
     Current media picker
     */
    UIImagePickerController *mediaPicker;
    
    /**
     Array of validation views (MXKImageView instances)
     */
    NSMutableArray *validationViews;
    
    /**
     Handle images attachment
     */
    UIAlertController *compressionPrompt;
    NSMutableArray *pendingImages;
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

#pragma mark - Override MXKView

-(void)customizeViewRendering
{
    [super customizeViewRendering];
    
    // Reset default container background color
    messageComposerContainer.backgroundColor = [UIColor clearColor];
    
    // Set default toolbar background color
    self.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
}

#pragma mark -

- (IBAction)onTouchUpInside:(UIButton*)button
{
    if (button == self.leftInputToolbarButton)
    {
        if (optionsListView)
        {
            [optionsListView dismissViewControllerAnimated:NO completion:nil];
            optionsListView = nil;
        }
        
        // Option button has been pressed
        // List available options
        __weak typeof(self) weakSelf = self;
        
        // Check whether media attachment is supported
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:presentViewController:)])
        {
            optionsListView = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            
            [optionsListView addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"attach_media"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  
                                                                  if (weakSelf)
                                                                  {
                                                                      typeof(self) self = weakSelf;
                                                                      self->optionsListView = nil;
                                                                      
                                                                      // Open media gallery
                                                                      self->mediaPicker = [[UIImagePickerController alloc] init];
                                                                      self->mediaPicker.delegate = self;
                                                                      self->mediaPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                                                                      self->mediaPicker.allowsEditing = NO;
                                                                      self->mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                                                                      [self.delegate roomInputToolbarView:self presentViewController:self->mediaPicker];
                                                                  }
                                                                  
                                                              }]];
            
            [optionsListView addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"capture_media"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  
                                                                  if (weakSelf)
                                                                  {
                                                                      typeof(self) self = weakSelf;
                                                                      self->optionsListView = nil;
                                                                      
                                                                      // Open Camera
                                                                      self->mediaPicker = [[UIImagePickerController alloc] init];
                                                                      self->mediaPicker.delegate = self;
                                                                      self->mediaPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                                                                      self->mediaPicker.allowsEditing = NO;
                                                                      self->mediaPicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie, nil];
                                                                      [self.delegate roomInputToolbarView:self presentViewController:self->mediaPicker];
                                                                  }
                                                                  
                                                              }]];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] Attach media is not supported");
        }
        
        // Check whether user invitation is supported
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:inviteMatrixUser:)])
        {
            if (!optionsListView)
            {
                optionsListView = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            }
            
            [optionsListView addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"invite_user"]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  
                                                                  if (weakSelf)
                                                                  {
                                                                      typeof(self) self = weakSelf;
                                                                      
                                                                      // Ask for userId to invite
                                                                      self->optionsListView = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"user_id_title"] message:nil preferredStyle:UIAlertControllerStyleAlert];
                                                                      
                                                                      
                                                                      [self->optionsListView addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                          
                                                                          if (weakSelf)
                                                                          {
                                                                              typeof(self) self = weakSelf;
                                                                              self->optionsListView = nil;
                                                                          }
                                                                          
                                                                      }]];
                                                                      
                                                                      [self->optionsListView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                                                                          
                                                                           textField.secureTextEntry = NO;
                                                                           textField.placeholder = [NSBundle mxk_localizedStringForKey:@"user_id_placeholder"];
                                                                          
                                                                       }];
                                                                      
                                                                      [self->optionsListView addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"invite"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                          
                                                                          if (weakSelf)
                                                                          {
                                                                              typeof(self) self = weakSelf;
                                                                              
                                                                              UITextField *textField = [self->optionsListView textFields].firstObject;
                                                                              NSString *userId = textField.text;
                                                                              
                                                                              self->optionsListView = nil;
                                                                              
                                                                              if (userId.length)
                                                                              {
                                                                                  [self.delegate roomInputToolbarView:self inviteMatrixUser:userId];
                                                                              }
                                                                          }
                                                                          
                                                                      }]];
                                                                      
                                                                      [self.delegate roomInputToolbarView:self presentAlertController:self->optionsListView];
                                                                  }
                                                                  
                                                              }]];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] Invitation is not supported");
        }
        
        if (optionsListView)
        {
            
            [self->optionsListView addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    self->optionsListView = nil;
                }
                
            }]];
            
            [optionsListView popoverPresentationController].sourceView = button;
            [optionsListView popoverPresentationController].sourceRect = button.bounds;
            [self.delegate roomInputToolbarView:self presentAlertController:optionsListView];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] No option is supported");
        }
    }
    else if (button == self.rightInputToolbarButton)
    {
        // This forces an autocorrect event to happen when "Send" is pressed, which is necessary to accept a pending correction on send
        self.textMessage = [NSString stringWithFormat:@"%@ ", self.textMessage];
        self.textMessage = [self.textMessage substringToIndex:[self.textMessage length]-1];

        NSString *message = self.textMessage;
        
        // Reset message, disable view animation during the update to prevent placeholder distorsion.
        [UIView setAnimationsEnabled:NO];
        self.textMessage = nil;
        [UIView setAnimationsEnabled:YES];
        
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

- (BOOL)becomeFirstResponder
{
    return NO;
}

- (void)dismissKeyboard
{
    
}

- (void)dismissCompressionPrompt
{
    if (compressionPrompt)
    {
        [compressionPrompt dismissViewControllerAnimated:NO completion:nil];
        compressionPrompt = nil;
    }
    
    if (pendingImages.count)
    {
        UIImage *firstImage = pendingImages.firstObject;
        [pendingImages removeObjectAtIndex:0];
        [self sendImage:firstImage withCompressionMode:MXKRoomInputToolbarCompressionModePrompt];
    }
}

- (void)destroy
{
    [self dismissValidationViews];
    validationViews = nil;
    
    if (optionsListView)
    {
        [optionsListView dismissViewControllerAnimated:NO completion:nil];
        optionsListView = nil;
    }
    
    [self dismissMediaPicker];
    
    self.delegate = nil;
    
    pendingImages = nil;
    [self dismissCompressionPrompt];
}

- (void)pasteText:(NSString *)text
{
    // We cannot do more than appending text to self.textMessage
    // Let 'MXKRoomInputToolbarView' children classes do the job
    self.textMessage = [NSString stringWithFormat:@"%@%@", self.textMessage, text];
}

#pragma mark - MXKImageCompressionSize

/**
 Structure representing an the size of an image and its file size.
 */
typedef struct
{
    CGSize imageSize;
    NSUInteger fileSize;

} MXKImageCompressionSize;

/**
 Structure representing the sizes of image (image size and file size) according to
 different level of compression.
 */
typedef struct
{
    MXKImageCompressionSize small;
    MXKImageCompressionSize medium;
    MXKImageCompressionSize large;
    MXKImageCompressionSize original;

    CGFloat actualLargeSize;

} MXKImageCompressionSizes;

- (MXKImageCompressionSizes)availableCompressionSizesForImage:(UIImage*)image
{
    MXKImageCompressionSizes compressionSizes;
    memset(&compressionSizes, 0, sizeof(MXKImageCompressionSizes));

    // Store the original
    compressionSizes.original.imageSize = image.size;
    compressionSizes.original.fileSize = UIImageJPEGRepresentation(image, 0.9).length;

   NSLog(@"[MXKRoomInputToolbarView] availableCompressionSizesForImage: %f %f - File size: %tu", compressionSizes.original.imageSize.width, compressionSizes.original.imageSize.height, compressionSizes.original.fileSize);

    compressionSizes.actualLargeSize = MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE;

    // Compute the file size for each compression level
    CGFloat maxSize = MAX(compressionSizes.original.imageSize.width, compressionSizes.original.imageSize.height);
    if (maxSize >= MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE)
    {
        compressionSizes.small.imageSize = [MXKTools resizeImageSize:compressionSizes.original.imageSize toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE) canExpand:NO];

        compressionSizes.small.fileSize = (NSUInteger)[MXTools roundFileSize:(long long)(compressionSizes.small.imageSize.width * compressionSizes.small.imageSize.height * 0.20)];

        if (maxSize >= MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE)
        {
            compressionSizes.medium.imageSize = [MXKTools resizeImageSize:compressionSizes.original.imageSize toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE) canExpand:NO];

            compressionSizes.medium.fileSize = (NSUInteger)[MXTools roundFileSize:(long long)(compressionSizes.medium.imageSize.width * compressionSizes.medium.imageSize.height * 0.20)];

            if (maxSize >= MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE)
            {
                // In case of panorama the large resolution (1024 x ...) is not relevant. We prefer consider the third of the panarama width.
                compressionSizes.actualLargeSize = maxSize / 3;
                if (compressionSizes.actualLargeSize < MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE)
                {
                    compressionSizes.actualLargeSize = MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE;
                }
                else
                {
                    // Keep a multiple of predefined large size
                    compressionSizes.actualLargeSize = floor(compressionSizes.actualLargeSize / MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE) * MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE;
                }

                compressionSizes.large.imageSize = [MXKTools resizeImageSize:compressionSizes.original.imageSize toFitInSize:CGSizeMake(compressionSizes.actualLargeSize, compressionSizes.actualLargeSize) canExpand:NO];

                compressionSizes.large.fileSize = (NSUInteger)[MXTools roundFileSize:(long long)(compressionSizes.large.imageSize.width * compressionSizes.large.imageSize.height * 0.20)];
            }
            else
            {
                NSLog(@"    - too small to fit in %d", MXKROOM_INPUT_TOOLBAR_VIEW_LARGE_IMAGE_SIZE);
            }
        }
        else
        {
            NSLog(@"    - too small to fit in %d", MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE);
        }
    }
    else
    {
        NSLog(@"    - too small to fit in %d", MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE);
    }

    return compressionSizes;
}

#pragma mark - MXKFileSizes

/**
 Structure representing the file sizes of a media according to different level of
 compression.
 */
typedef struct
{
    NSUInteger small;
    NSUInteger medium;
    NSUInteger large;
    NSUInteger original;

} MXKFileSizes;

void MXKFileSizes_init(MXKFileSizes *sizes)
{
    memset(sizes, 0, sizeof(MXKFileSizes));
}

MXKFileSizes MXKFileSizes_add(MXKFileSizes sizes1, MXKFileSizes sizes2)
{
    MXKFileSizes sizes;
    sizes.small = sizes1.small + sizes2.small;
    sizes.medium = sizes1.medium + sizes2.medium;
    sizes.large = sizes1.large + sizes2.large;
    sizes.original = sizes1.original + sizes2.original;

    return sizes;
}

NSString* MXKFileSizes_description(MXKFileSizes sizes)
{
    return [NSString stringWithFormat:@"small: %tu - medium: %tu - large: %tu - original: %tu", sizes.small, sizes.medium, sizes.large, sizes.original];
}

- (void)availableCompressionSizesForAsset:(PHAsset*)asset andContentEditingInput:(PHContentEditingInput*)contentEditingInput onComplete:(void(^)(MXKFileSizes sizes))onComplete
{
    __block MXKFileSizes sizes;
    MXKFileSizes_init(&sizes);

    if (asset.mediaType == PHAssetMediaTypeImage)
    {
        // Retrieve the fullSizeImage thanks to its local file path
        NSData *data = [NSData dataWithContentsOfURL:contentEditingInput.fullSizeImageURL];
        UIImage *image = [UIImage imageWithData:data];

        MXKImageCompressionSizes compressionSizes = [self availableCompressionSizesForImage:image];

        sizes.small = compressionSizes.small.fileSize;
        sizes.medium = compressionSizes.medium.fileSize;
        sizes.large = compressionSizes.large.fileSize;
        sizes.original = compressionSizes.original.fileSize;

        onComplete(sizes);
    }
    else if (asset.mediaType == PHAssetMediaTypeVideo)
    {
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:nil resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
            if ([asset isKindOfClass:[AVURLAsset class]])
            {
                AVURLAsset* urlAsset = (AVURLAsset*)asset;

                NSNumber *size;
                [urlAsset.URL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];

                sizes.original = size.unsignedIntegerValue;
                sizes.small = sizes.original;
                sizes.medium = sizes.original;
                sizes.large = sizes.original;

                dispatch_async(dispatch_get_main_queue(), ^{
                    onComplete(sizes);
                });
            }
        }];
    }
    else
    {
        onComplete(sizes);
    }
}


- (void)availableCompressionSizesForAssets:(NSArray<PHAsset*>*)assets contentEditingInputs:(NSArray<PHContentEditingInput*> *)contentEditingInputs index:(NSUInteger)index appendTo:(MXKFileSizes)sizes onComplete:(void(^)(MXKFileSizes fileSizes))onComplete
{
    [self availableCompressionSizesForAsset:assets[index] andContentEditingInput:contentEditingInputs[index] onComplete:^(MXKFileSizes assetSizes) {

        MXKFileSizes intermediateSizes = MXKFileSizes_add(sizes, assetSizes);

        if (index == assets.count - 1)
        {
            // Filter the sizes that are similar
            if (intermediateSizes.medium >= intermediateSizes.large)
            {
                intermediateSizes.large = 0;
            }
            if (intermediateSizes.small >= intermediateSizes.medium)
            {
                intermediateSizes.medium = 0;
            }
            if (intermediateSizes.small >= intermediateSizes.original)
            {
                intermediateSizes.small = 0;
            }

            onComplete(intermediateSizes);
        }
        else
        {
            [self availableCompressionSizesForAssets:assets contentEditingInputs:contentEditingInputs index:(index + 1) appendTo:intermediateSizes onComplete:onComplete];
        }
    }];
}

- (void)availableCompressionSizesForAssets:(NSArray<PHAsset*>*)assets contentEditingInputs:(NSArray<PHContentEditingInput*> *)contentEditingInputs onComplete:(void(^)(MXKFileSizes fileSizes))onComplete
{
    __block MXKFileSizes sizes;
    MXKFileSizes_init(&sizes);

    [self availableCompressionSizesForAssets:assets contentEditingInputs:contentEditingInputs index:0 appendTo:sizes onComplete:onComplete];
}

#pragma mark - Attachment handling

- (void)sendSelectedImage:(UIImage*)selectedImage withCompressionMode:(MXKRoomInputToolbarCompressionMode)compressionMode andLocalURL:(NSURL*)imageURL
{
    // Retrieve image mimetype if the image is saved in photos library
    NSString *mimetype = nil;
    if (imageURL)
    {
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[imageURL.path pathExtension] , NULL);
        mimetype = (__bridge_transfer NSString *) UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
        CFRelease(uti);
    }
    else if (_enableAutoSaving)
    {
        // Save the original image in user's photos library
        [MXMediaManager saveImageToPhotosLibrary:selectedImage success:nil failure:nil];
    }

    // Send data without compression if the image type is not jpeg
    if (mimetype && [mimetype isEqualToString:@"image/jpeg"] == NO && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendImage:withMimeType:)])
    {
        // Check whether the url references the image in the AssetsLibrary framework
        if ([imageURL.scheme isEqualToString:@"assets-library"])
        {
            // Retrieve the local full-sized image URL
            // Use the Photos framework on iOS 8 and later (use AssetsLibrary framework on iOS < 8).
            Class PHAsset_class = NSClassFromString(@"PHAsset");
            if (PHAsset_class)
            {
                PHFetchResult *result = [PHAsset fetchAssetsWithALAssetURLs:@[imageURL] options:nil];
                if (result.count)
                {
                    PHAsset *asset = result[0];
                    PHContentEditingInputRequestOptions *option = [[PHContentEditingInputRequestOptions alloc] init];
                    [asset requestContentEditingInputWithOptions:option completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {

                        [self.delegate roomInputToolbarView:self sendImage:contentEditingInput.fullSizeImageURL withMimeType:mimetype];

                    }];
                }
                else
                {
                    NSLog(@"[MXKRoomInputToolbarView] Attach image failed");
                }
            }
            else
            {
                ALAssetsLibrary *assetLibrary=[[ALAssetsLibrary alloc] init];
                [assetLibrary assetForURL:imageURL resultBlock:^(ALAsset *asset) {

                    // asset may be nil if the image is not saved in photos library
                    if (asset)
                    {
                        ALAssetRepresentation* assetRepresentation = [asset defaultRepresentation];
                        [self.delegate roomInputToolbarView:self sendImage:assetRepresentation.url withMimeType:mimetype];
                    }
                    else
                    {
                        NSLog(@"[MXKRoomInputToolbarView] Attach image failed");
                    }

                } failureBlock:^(NSError *err) {

                    NSLog(@"[MXKRoomInputToolbarView] Attach image failed: %@", err);

                }];
            }
        }
        else
        {
            // Consider the provided URL as the filesystem one
            [self.delegate roomInputToolbarView:self sendImage:imageURL withMimeType:mimetype];
        }
    }
    else
    {
        if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:sendImage:)])
        {
            [self sendImage:selectedImage withCompressionMode:compressionMode];
        }
        else
        {
            NSLog(@"[MXKRoomInputToolbarView] Attach image is not supported");
        }
    }
}

- (void)sendImage:(UIImage*)image withCompressionMode:(MXKRoomInputToolbarCompressionMode)compressionMode
{
    if (optionsListView)
    {
        [optionsListView dismissViewControllerAnimated:NO completion:nil];
        optionsListView = nil;
    }
    
    if (compressionPrompt && compressionMode == MXKRoomInputToolbarCompressionModePrompt)
    {
        // Delay the image sending
        if (!pendingImages)
        {
            pendingImages = [NSMutableArray arrayWithObject:image];
        }
        else
        {
            [pendingImages addObject:image];
        }
        return;
    }

    // Get availabe sizes for this image
    MXKImageCompressionSizes compressionSizes = [self availableCompressionSizesForImage:image];

    // Apply the compression mode
    if (compressionMode == MXKRoomInputToolbarCompressionModePrompt
        && (compressionSizes.small.fileSize || compressionSizes.medium.fileSize || compressionSizes.large.fileSize))
    {
        __weak typeof(self) weakSelf = self;
        
        compressionPrompt = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"attachment_size_prompt"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        if (compressionSizes.small.fileSize)
        {
            NSString *resolution = [NSString stringWithFormat:@"%@ (%d x %d)", [MXTools fileSizeToString:compressionSizes.small.fileSize round:NO], (int)compressionSizes.small.imageSize.width, (int)compressionSizes.small.imageSize.height];

            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_small"], resolution];
            
            [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    
                                                                    if (weakSelf)
                                                                    {
                                                                        typeof(self) self = weakSelf;
                                                                        
                                                                        // Send the small image
                                                                        UIImage *smallImage = [MXKTools reduceImage:image toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE)];
                                                                        [self.delegate roomInputToolbarView:self sendImage:smallImage];
                                                                        
                                                                        [self dismissCompressionPrompt];
                                                                    }
                                                                    
                                                                }]];
        }
        
        if (compressionSizes.medium.fileSize)
        {
            NSString *resolution = [NSString stringWithFormat:@"%@ (%d x %d)", [MXTools fileSizeToString:compressionSizes.medium.fileSize round:NO], (int)compressionSizes.medium.imageSize.width, (int)compressionSizes.medium.imageSize.height];

            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_medium"], resolution];
            
            [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    
                                                                    if (weakSelf)
                                                                    {
                                                                        typeof(self) self = weakSelf;
                                                                        
                                                                        // Send the medium image
                                                                        UIImage *mediumImage = [MXKTools reduceImage:image toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE)];
                                                                        [self.delegate roomInputToolbarView:self sendImage:mediumImage];
                                                                        
                                                                        [self dismissCompressionPrompt];
                                                                    }
                                                                    
                                                                }]];
        }
        
        if (compressionSizes.large.fileSize)
        {
            NSString *resolution = [NSString stringWithFormat:@"%@ (%d x %d)", [MXTools fileSizeToString:compressionSizes.large.fileSize round:NO], (int)compressionSizes.large.imageSize.width, (int)compressionSizes.large.imageSize.height];

            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_large"], resolution];
            
            [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    
                                                                    if (weakSelf)
                                                                    {
                                                                        typeof(self) self = weakSelf;
                                                                        
                                                                        // Send the large image
                                                                        UIImage *largeImage = [MXKTools reduceImage:image toFitInSize:CGSizeMake(compressionSizes.actualLargeSize, compressionSizes.actualLargeSize)];
                                                                        [self.delegate roomInputToolbarView:self sendImage:largeImage];
                                                                        
                                                                        [self dismissCompressionPrompt];
                                                                    }
                                                                    
                                                                }]];
        }
        
        NSString *resolution = [NSString stringWithFormat:@"%@ (%d x %d)", [MXTools fileSizeToString:compressionSizes.original.fileSize round:NO], (int)compressionSizes.original.imageSize.width, (int)compressionSizes.original.imageSize.height];

        NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_original"], resolution];
        
        [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                
                                                                if (weakSelf)
                                                                {
                                                                    typeof(self) self = weakSelf;
                                                                    
                                                                    // Send the original image
                                                                    [self.delegate roomInputToolbarView:self sendImage:image];
                                                                    
                                                                    [self dismissCompressionPrompt];
                                                                }
                                                                
                                                            }]];
        
        [compressionPrompt addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                
                                                                if (weakSelf)
                                                                {
                                                                    typeof(self) self = weakSelf;
                                                                    
                                                                    [self dismissCompressionPrompt];
                                                                }
                                                                
                                                            }]];
        
        [compressionPrompt popoverPresentationController].sourceView = self;
        [compressionPrompt popoverPresentationController].sourceRect = self.bounds;
        [self.delegate roomInputToolbarView:self presentAlertController:compressionPrompt];
    }
    else
    {
        // By default the original image is sent
        UIImage *finalImage = image;
        
        switch (compressionMode)
        {
            case MXKRoomInputToolbarCompressionModePrompt:
                // Here the image size is too small to need compression - send the original image
                break;
                
            case MXKRoomInputToolbarCompressionModeSmall:
                if (compressionSizes.small.fileSize)
                {
                    finalImage = [MXKTools reduceImage:image toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_SMALL_IMAGE_SIZE)];
                }
                break;
                
            case MXKRoomInputToolbarCompressionModeMedium:
                if (compressionSizes.medium.fileSize)
                {
                    finalImage = [MXKTools reduceImage:image toFitInSize:CGSizeMake(MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE, MXKROOM_INPUT_TOOLBAR_VIEW_MEDIUM_IMAGE_SIZE)];
                }
                break;
                
            case MXKRoomInputToolbarCompressionModeLarge:
                if (compressionSizes.large.fileSize)
                {
                    finalImage = [MXKTools reduceImage:image toFitInSize:CGSizeMake(compressionSizes.actualLargeSize, compressionSizes.actualLargeSize)];
                }
                break;
                
            default:
                // no compression, send original
                break;
        }
        
        // Send the image
        [self.delegate roomInputToolbarView:self sendImage:finalImage];
    }
}

- (void)sendSelectedVideo:(NSURL*)selectedVideo isPhotoLibraryAsset:(BOOL)isPhotoLibraryAsset
{
    // Check condition before saving this media in user's library
    if (_enableAutoSaving && !isPhotoLibraryAsset)
    {
        [MXMediaManager saveMediaToPhotosLibrary:selectedVideo isImage:NO success:nil failure:nil];
    }
    
    if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:sendVideo:withThumbnail:)])
    {
        // Retrieve the video frame at 1 sec to define the video thumbnail
        AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:selectedVideo options:nil];
        AVAssetImageGenerator *assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
        assetImageGenerator.appliesPreferredTrackTransform = YES;
        CMTime time = CMTimeMake(1, 1);
        CGImageRef imageRef = [assetImageGenerator copyCGImageAtTime:time actualTime:NULL error:nil];
        
        // Finalize video attachment
        UIImage* videoThumbnail = [[UIImage alloc] initWithCGImage:imageRef];
        CFRelease(imageRef);
        
        [self.delegate roomInputToolbarView:self sendVideo:selectedVideo withThumbnail:videoThumbnail];
    }
    else
    {
        NSLog(@"[RoomInputToolbarView] Attach video is not supported");
    }
}

- (void)sendSelectedAssets:(NSArray<PHAsset*>*)assets withCompressionMode:(MXKRoomInputToolbarCompressionMode)compressionMode
{
    // Get metadata about selected media
    NSMutableArray<PHContentEditingInput*> *contentEditingInputs = [NSMutableArray arrayWithCapacity:assets.count];

    [self contentEditingInputsForAssets:assets withResult:contentEditingInputs onComplete:^{

        // Sanity check: check whether a content editing input has been retrieved for each asset.
        // Remove the assets without content editing input.
        NSMutableArray<PHAsset*> *updatedAssets;
        for (NSUInteger index = 0; index < contentEditingInputs.count;)
        {
            PHContentEditingInput *contentEditingInput = contentEditingInputs[index];
            
            if (contentEditingInput.mediaType == PHAssetMediaTypeUnknown)
            {
                // Filter out unsupported and fake content
                if (!updatedAssets)
                {
                    updatedAssets = [NSMutableArray arrayWithArray:assets];
                }
                
                [updatedAssets removeObjectAtIndex:index];
                [contentEditingInputs removeObjectAtIndex:index];
            }
            else
            {
                index++;
            }
        }

        NSArray<PHAsset*> *assetsToSend = updatedAssets ? updatedAssets : assets;
        if (assetsToSend.count)
        {
            [self availableCompressionSizesForAssets:assetsToSend contentEditingInputs:contentEditingInputs onComplete:^(MXKFileSizes fileSizes) {

                [self sendSelectedAssets:contentEditingInputs withFileSizes:fileSizes andCompressionMode:compressionMode];
            }];
        }

    }];
}

- (void)sendSelectedAssets:(NSMutableArray<PHContentEditingInput*> *)contentEditingInputs withFileSizes:(MXKFileSizes)fileSizes andCompressionMode:(MXKRoomInputToolbarCompressionMode)compressionMode
{
    if (compressionMode == MXKRoomInputToolbarCompressionModePrompt
        && (fileSizes.small || fileSizes.medium || fileSizes.large))
    {
        // Ask the user for the compression value
        compressionPrompt = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"attachment_multiselection_size_prompt"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        __weak typeof(self) weakSelf = self;

        if (fileSizes.small)
        {
            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_small"], [MXTools fileSizeToString:fileSizes.small round:NO]];
            
            [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    
                                                                    if (weakSelf)
                                                                    {
                                                                        typeof(self) self = weakSelf;
                                                                        
                                                                        [self dismissCompressionPrompt];
                                                                        
                                                                        [self sendSelectedAssets:contentEditingInputs withFileSizes:fileSizes andCompressionMode:MXKRoomInputToolbarCompressionModeSmall];
                                                                    }
                                                                    
                                                                }]];
        }

        if (fileSizes.medium)
        {
            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_medium"], [MXTools fileSizeToString:fileSizes.medium round:NO]];
            
            [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    
                                                                    if (weakSelf)
                                                                    {
                                                                        typeof(self) self = weakSelf;
                                                                        
                                                                        [self dismissCompressionPrompt];
                                                                        
                                                                        [self sendSelectedAssets:contentEditingInputs withFileSizes:fileSizes andCompressionMode:MXKRoomInputToolbarCompressionModeMedium];
                                                                    }
                                                                    
                                                                }]];
        }

        if (fileSizes.large)
        {
            NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_large"], [MXTools fileSizeToString:fileSizes.large round:NO]];
            
            [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction * action) {
                                                                    
                                                                    if (weakSelf)
                                                                    {
                                                                        typeof(self) self = weakSelf;
                                                                        
                                                                        [self dismissCompressionPrompt];
                                                                        
                                                                        [self sendSelectedAssets:contentEditingInputs withFileSizes:fileSizes andCompressionMode:MXKRoomInputToolbarCompressionModeLarge];
                                                                    }
                                                                    
                                                                }]];
        }

        NSString *title = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"attachment_original"], [MXTools fileSizeToString:fileSizes.original round:NO]];
        
        [compressionPrompt addAction:[UIAlertAction actionWithTitle:title
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                
                                                                if (weakSelf)
                                                                {
                                                                    typeof(self) self = weakSelf;
                                                                    
                                                                    [self dismissCompressionPrompt];
                                                                    
                                                                    [self sendSelectedAssets:contentEditingInputs withFileSizes:fileSizes andCompressionMode:MXKRoomInputToolbarCompressionModeNone];
                                                                }
                                                                
                                                            }]];
        
        [compressionPrompt addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                
                                                                if (weakSelf)
                                                                {
                                                                    typeof(self) self = weakSelf;
                                                                    
                                                                    [self dismissCompressionPrompt];
                                                                }
                                                                
                                                            }]];
        
        [compressionPrompt popoverPresentationController].sourceView = self;
        [compressionPrompt popoverPresentationController].sourceRect = self.bounds;
        [self.delegate roomInputToolbarView:self presentAlertController:compressionPrompt];
    }
    else
    {
        // Send all media with the selected compression mode
        for (PHContentEditingInput *contentEditingInput in contentEditingInputs)
        {
            if (contentEditingInput.mediaType == PHAssetMediaTypeImage)
            {
                // Retrieve the fullSizeImage thanks to its local file path
                NSData *data = [NSData dataWithContentsOfURL:contentEditingInput.fullSizeImageURL];
                UIImage *image = [UIImage imageWithData:data];

                [self sendSelectedImage:image withCompressionMode:compressionMode andLocalURL:contentEditingInput.fullSizeImageURL];
            }
            else if (contentEditingInput.mediaType == PHAssetMediaTypeVideo)
            {
                if ([contentEditingInput.avAsset isKindOfClass:[AVURLAsset class]])
                {
                    AVURLAsset *avURLAsset = (AVURLAsset*)contentEditingInput.avAsset;
                    [self sendSelectedVideo:avURLAsset.URL isPhotoLibraryAsset:YES];
                }
                else
                {
                    NSLog(@"[MediaPickerVC] Selected video asset is not initialized from an URL!");
                }
            }
        }
    }
}

- (void)contentEditingInputsForAssets:(NSArray<PHAsset*>*)assets withResult:(NSMutableArray<PHContentEditingInput*> *)contentEditingInputs onComplete:(void(^)())onComplete
{
    NSParameterAssert(contentEditingInputs);

    PHContentEditingInputRequestOptions *editOptions = [[PHContentEditingInputRequestOptions alloc] init];

    [assets[contentEditingInputs.count] requestContentEditingInputWithOptions:editOptions completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
        
        // Sanity check
        if (contentEditingInput)
        {
            [contentEditingInputs addObject:contentEditingInput];
        }
        else
        {
            // Create a fake content. It will be filter out after
            PHContentEditingInput *fake = [[PHContentEditingInput alloc] init];
            [contentEditingInputs addObject:fake];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (contentEditingInputs.count == assets.count)
            {
                // We get all results
                onComplete();
            }
            else
            {
                // Continue recursively
                [self contentEditingInputsForAssets:assets withResult:contentEditingInputs onComplete:onComplete];
            }
            
        });
    }];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissMediaPicker];
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage])
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
                     if (weakSelf)
                     {
                         typeof(self) self = weakSelf;
                         
                         // Dismiss the image view
                         [self dismissValidationViews];
                         
                         // attach the selected image
                         [self sendSelectedImage:selectedImage withCompressionMode:MXKRoomInputToolbarCompressionModePrompt andLocalURL:[info objectForKey:UIImagePickerControllerReferenceURL]];
                     }
                     
                 }];
                
                // the user wants to use an other image
                [imageValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                 {
                     if (weakSelf)
                     {
                         typeof(self) self = weakSelf;
                         
                         // dismiss the image view
                         [self dismissValidationViews];
                         
                         // Open again media gallery
                         self->mediaPicker = [[UIImagePickerController alloc] init];
                         self->mediaPicker.delegate = self;
                         self->mediaPicker.sourceType = picker.sourceType;
                         self->mediaPicker.allowsEditing = NO;
                         self->mediaPicker.mediaTypes = picker.mediaTypes;
                         [self.delegate roomInputToolbarView:self presentViewController:self->mediaPicker];
                     }
                 }];
                
                imageValidationView.image = selectedImage;
                
                [validationViews addObject:imageValidationView];
                [imageValidationView showFullScreen];
                [self.delegate roomInputToolbarView:self hideStatusBar:YES];
            }
            else
            {
                // Suggest compression before sending image
                [self sendSelectedImage:selectedImage withCompressionMode:MXKRoomInputToolbarCompressionModePrompt andLocalURL:nil];
            }
        }
    }
    else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie])
    {
        NSURL* selectedVideo = [info objectForKey:UIImagePickerControllerMediaURL];
        
        [self sendSelectedVideo:selectedVideo isPhotoLibraryAsset:(picker.sourceType == UIImagePickerControllerSourceTypePhotoLibrary)];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissMediaPicker];
}

- (void)dismissValidationViews
{
    if (validationViews.count)
    {
        for (MXKImageView *validationView in validationViews)
        {
            [validationView dismissSelection];
            [validationView removeFromSuperview];
        }
        
        [validationViews removeAllObjects];
        
        // Restore status bar
        [self.delegate roomInputToolbarView:self hideStatusBar:NO];
    }
}

- (void)dismissValidationView:(MXKImageView*)validationView
{
    [validationView dismissSelection];
    [validationView removeFromSuperview];
    
    if (validationViews.count)
    {
        [validationViews removeObject:validationView];
        
        if (!validationViews.count)
        {
            // Restore status bar
            [self.delegate roomInputToolbarView:self hideStatusBar:NO];
        }
    }
}

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
                if ([MIMEType hasPrefix:@"image/"] && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendImage:)])
                {
                    UIImage *pasteboardImage = [dict objectForKey:key];
                    if (pasteboardImage)
                    {
                        MXKImageView *imageValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                        imageValidationView.stretchable = YES;
                        
                        // the user validates the image
                        [imageValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             if (weakSelf)
                             {
                                 typeof(self) self = weakSelf;
                                 [self dismissValidationView:imageView];
                                 [self.delegate roomInputToolbarView:self sendImage:pasteboardImage];
                             }
                         }];
                        
                        // the user wants to use an other image
                        [imageValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             // Dismiss the image validation view.
                             if (weakSelf)
                             {
                                 typeof(self) self = weakSelf;
                                 [self dismissValidationView:imageView];
                             }
                         }];
                        
                        imageValidationView.image = pasteboardImage;
                        
                        [validationViews addObject:imageValidationView];
                        [imageValidationView showFullScreen];
                        [self.delegate roomInputToolbarView:self hideStatusBar:YES];
                    }
                    
                    break;
                }
                else if ([MIMEType hasPrefix:@"video/"] && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendVideo:withThumbnail:)])
                {
                    NSData *pasteboardVideoData = [dict objectForKey:key];
                    NSString *fakePasteboardURL = [NSString stringWithFormat:@"%@%@", kPasteboardItemPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
                    NSString *cacheFilePath = [MXMediaManager cachePathForMediaWithURL:fakePasteboardURL andType:MIMEType inFolder:nil];
                    
                    if ([MXMediaManager writeMediaData:pasteboardVideoData toFilePath:cacheFilePath])
                    {
                        NSURL *videoLocalURL = [NSURL fileURLWithPath:cacheFilePath isDirectory:NO];
                        
                        // Retrieve the video frame at 1 sec to define the video thumbnail
                        AVURLAsset *urlAsset = [[AVURLAsset alloc] initWithURL:videoLocalURL options:nil];
                        AVAssetImageGenerator *assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
                        assetImageGenerator.appliesPreferredTrackTransform = YES;
                        CMTime time = CMTimeMake(1, 1);
                        CGImageRef imageRef = [assetImageGenerator copyCGImageAtTime:time actualTime:NULL error:nil];
                        UIImage* videoThumbnail = [[UIImage alloc] initWithCGImage:imageRef];
                        CFRelease (imageRef);
                        
                        MXKImageView *videoValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                        videoValidationView.stretchable = YES;
                        
                        // the user validates the image
                        [videoValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             if (weakSelf)
                             {
                                 typeof(self) self = weakSelf;
                                 [self dismissValidationView:imageView];
                                 
                                 [self.delegate roomInputToolbarView:self sendVideo:videoLocalURL withThumbnail:videoThumbnail];
                             }
                         }];
                        
                        // the user wants to use an other image
                        [videoValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             // Dismiss the video validation view.
                             if (weakSelf)
                             {
                                 typeof(self) self = weakSelf;
                                 [self dismissValidationView:imageView];
                             }
                         }];
                        
                        videoValidationView.image = videoThumbnail;
                        
                        [validationViews addObject:videoValidationView];
                        [videoValidationView showFullScreen];
                        [self.delegate roomInputToolbarView:self hideStatusBar:YES];
                        
                        // Add video icon
                        UIImageView *videoIconView = [[UIImageView alloc] initWithImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_video"]];
                        videoIconView.center = videoValidationView.center;
                        videoIconView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
                        [videoValidationView addSubview:videoIconView];
                    }
                    break;
                }
                else if ([MIMEType hasPrefix:@"application/"] && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendFile:withMimeType:)])
                {
                    NSData *pasteboardDocumentData = [dict objectForKey:key];
                    NSString *fakePasteboardURL = [NSString stringWithFormat:@"%@%@", kPasteboardItemPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
                    NSString *cacheFilePath = [MXMediaManager cachePathForMediaWithURL:fakePasteboardURL andType:MIMEType inFolder:nil];
                    
                    if ([MXMediaManager writeMediaData:pasteboardDocumentData toFilePath:cacheFilePath])
                    {
                        NSURL *localURL = [NSURL fileURLWithPath:cacheFilePath isDirectory:NO];
                        
                        MXKImageView *docValidationView = [[MXKImageView alloc] initWithFrame:CGRectZero];
                        docValidationView.stretchable = YES;
                        
                        // the user validates the image
                        [docValidationView setRightButtonTitle:[NSBundle mxk_localizedStringForKey:@"ok"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             if (weakSelf)
                             {
                                 typeof(self) self = weakSelf;
                                 [self dismissValidationView:imageView];
                                 
                                 [self.delegate roomInputToolbarView:self sendFile:localURL withMimeType:MIMEType];
                             }
                         }];
                        
                        // the user wants to use an other image
                        [docValidationView setLeftButtonTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] handler:^(MXKImageView* imageView, NSString* buttonTitle)
                         {
                             // Dismiss the validation view.
                             if (weakSelf)
                             {
                                 typeof(self) self = weakSelf;
                                 [self dismissValidationView:imageView];
                             }
                         }];
                        
                        docValidationView.image = nil;
                        
                        [validationViews addObject:docValidationView];
                        [docValidationView showFullScreen];
                        [self.delegate roomInputToolbarView:self hideStatusBar:YES];
                        
                        // Create a fake name based on fileData to keep the same name for the same file.
                        NSString *dataHash = [pasteboardDocumentData mx_MD5];
                        if (dataHash.length > 7)
                        {
                            // Crop
                            dataHash = [dataHash substringToIndex:7];
                        }
                        NSString *extension = [MXTools fileExtensionFromContentType:MIMEType];
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
                    
                    if ([MIMEType hasPrefix:@"image/"] && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendImage:)])
                    {
                        return YES;
                    }
                    
                    if ([MIMEType hasPrefix:@"video/"] && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendVideo:withThumbnail:)])
                    {
                        return YES;
                    }
                    
                    if ([MIMEType hasPrefix:@"application/"] && [self.delegate respondsToSelector:@selector(roomInputToolbarView:sendFile:withMimeType:)])
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
