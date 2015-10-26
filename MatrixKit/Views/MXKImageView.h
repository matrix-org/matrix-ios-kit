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

/**
 Customize UIView in order to display image defined with remote url. Zooming inside the image (Stretching) is supported.
 */
@interface MXKImageView : UIView <UIScrollViewDelegate>

typedef void (^blockMXKImageView_onClick)(MXKImageView *imageView, NSString* title);

/**
 Load an image by its url.
 
 The image extension is extracted from the provided mime type (if any). If no type is available, we look for a potential extension
 in the url. By default 'image/jpeg' is considered.
 
 @param imageURL the remote image url
 @param mimeType the media mime type, it is used to define the file extension (may be nil).
 @param orientation the actual orientation of the encoded image (used UIImageOrientationUp by default).
 @param previewImage image displayed until the actual image is available.
 */
- (void)setImageURL:(NSString *)imageURL withType:(NSString *)mimeType andImageOrientation:(UIImageOrientation)orientation previewImage:(UIImage*)previewImage;

/**
 Toggle display to fullscreen.
 */
- (void)showFullScreen;

// Use this boolean to hide activity indicator during image downloading
@property (nonatomic) BOOL hideActivityIndicator;

// Information about the media represented by this image (image, video...)
@property (strong, nonatomic) NSDictionary *mediaInfo;

@property (strong, nonatomic) UIImage *image;

@property (nonatomic) BOOL stretchable;
@property (nonatomic, readonly) BOOL fullScreen;

// the image is cached in memory.
// The medias manager uses a LRU cache.
// to avoid loading from the file system.
@property (nonatomic) BOOL enableInMemoryCache;

// mediaManager folder where the image is stored
@property (nonatomic) NSString* mediaFolder;

// Let the user defines some custom buttons over the tabbar
- (void)setLeftButtonTitle :leftButtonTitle handler:(blockMXKImageView_onClick)handler;
- (void)setRightButtonTitle:rightButtonTitle handler:(blockMXKImageView_onClick)handler;

- (void)dismissSelection;

@end

