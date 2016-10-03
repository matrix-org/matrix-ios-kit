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

@interface MXKTools : NSObject

#pragma mark - Time

/**
 Format time interval.
 ex: "5m 31s".
 
 @param secondsInterval time interval in seconds.
 @return formatted string
 */
+ (NSString*)formatSecondsInterval:(CGFloat)secondsInterval;

/**
 Format time interval but rounded to the nearest time unit below.
 ex: "5s", "1m", "2h" or "3d".

 @param secondsInterval time interval in seconds.
 @return formatted string
 */
+ (NSString*)formatSecondsIntervalFloored:(CGFloat)secondsInterval;

#pragma mark - File

/**
 Round file size.
 */
+ (long long)roundFileSize:(long long)filesize;

/**
 Return file size in string format.
 
 @param fileSize the file size in bytes.
 @param round tells whether the size must be rounded to hide decimal digits
 */
+ (NSString*)fileSizeToString:(long)fileSize round:(BOOL)round;

/**
 Get folder size
 
 @param folderPath
 @return folder size in bytes
 */
+ (long long)folderSize:(NSString *)folderPath;

/**
 List files in folder
 
 @param folderPath
 @param isTimeSorted if YES, the files are sorted by creation date from the oldest to the most recent one.
 @param largeFilesFirst if YES move the largest file to the list head (large > 100KB). It can be combined with isTimeSorted.
 @return the list of files by name.
 */
+ (NSArray*)listFiles:(NSString *)folderPath timeSorted:(BOOL)isTimeSorted largeFilesFirst:(BOOL)largeFilesFirst;

/**
 Deduce the file extension from a contentType
 
 @param contentType
 @return file extension (extension divider is included)
 */
+ (NSString*)fileExtensionFromContentType:(NSString*)contentType;

#pragma mark - Hex color to UIColor conversion

/**
 Build a UIColor from an hexadecimal color value
 
 @param rgbValue the color expressed in hexa (0xRRGGBB)
 @return the UIColor
 */
+ (UIColor*)colorWithRGBValue:(NSUInteger)rgbValue;

/**
 Build a UIColor from an hexadecimal color value with transparency

 @param argbValue the color expressed in hexa (0xAARRGGBB)
 @return the UIColor
 */
+ (UIColor*)colorWithARGBValue:(NSUInteger)argbValue;

/**
 Return an hexadecimal color value from UIColor
 
 @param the UIColor
 @return rgbValue the color expressed in hexa (0xRRGGBB)
 */
+ (NSUInteger)rgbValueWithColor:(UIColor*)color;

/**
 Return an hexadecimal color value with transparency from UIColor
 
 @param the UIColor
 @return argbValue the color expressed in hexa (0xAARRGGBB)
 */
+ (NSUInteger)argbValueWithColor:(UIColor*)color;

#pragma mark - Image processing

/**
 Force image orientation to up
 
 @param imageSrc
 @return image with `UIImageOrientationUp` orientation.
 */
+ (UIImage*)forceImageOrientationUp:(UIImage*)imageSrc;

/**
 Compute image size to fit in specific box size (in aspect fit mode)
 
 @param originalSize the original size
 @param maxSize the box size
 @param canExpand tell whether the image can be expand or not
 @return the resized size.
 */
+ (CGSize)resizeImageSize:(CGSize)originalSize toFitInSize:(CGSize)maxSize canExpand:(BOOL)canExpand;

/**
 Compute image size to fill specific box size (in aspect fill mode)
 
 @param originalSize the original size
 @param maxSize the box size
 @param canExpand tell whether the image can be expand or not
 @return the resized size.
 */
+ (CGSize)resizeImageSize:(CGSize)originalSize toFillWithSize:(CGSize)maxSize canExpand:(BOOL)canExpand;

/**
 Reduce image to fit in the provided size.
 The aspect ratio is kept.
 If the image is smaller than the provided size, the image is not recomputed.
 
 @param image
 @param size to fit in.
 @return resized image.
 */
+ (UIImage *)reduceImage:(UIImage *)image toFitInSize:(CGSize)size;

/**
 Resize image to a provided size.
 
 @param image
 @param the destinated
 @return resized image.
 */
+ (UIImage*)resizeImage:(UIImage *)image toSize:(CGSize)size;

/**
 Paint an image with a color.
 
 @discussion
 All non fully transparent (alpha = 0) will be painted with the provided color.
 
 @param image the image to paint.
 @param color the color to use.
 @result a new UIImage object.
 */
+ (UIImage*)paintImage:(UIImage*)image withColor:(UIColor*)color;

/**
 Convert a rotation angle to the most suitable image orientation.
 
 @param angle rotation angle in degree.
 @return image orientation.
 */
+ (UIImageOrientation)imageOrientationForRotationAngleInDegree:(NSInteger)angle;

#pragma mark - Video processing

/**
 Convert from a video to a MP4 video container.

 @discussion
 If the device does not support MP4 file format, the function will use the QuickTime format.

 @param the local path of the video to convert.
 @param success A block object called when the operation succeeded. It returns
                the path of the output video with some metadata.
 @param failure A block object called when the operation failed.
 */
+ (void)convertVideoToMP4:(NSURL*)videoLocalURL
                  success:(void(^)(NSURL *videoLocalURL, NSString *mimetype, CGSize size, double durationInMs))success
                  failure:(void(^)())failure;

/**
 Draw the image resource in a view and transforms it to a pattern color.
 The view size is defined by patternSize and will have a "backgroundColor" backgroundColor.
 The resource image is drawn with the resourceSize size and is centered into its parent view.
 
 @param reourceName the image resource name.
 @param backgroundColor the pattern background color.
 @param patternSize the pattern size.
 @param resourceSize the resource size in the pattern.
 @return the pattern color which can be used to define the background color of a view in order to display the provided image as its background.
 */
+ (UIColor*)convertImageToPatternColor:(NSString*)reourceName backgroundColor:(UIColor*)backgroundColor patternSize:(CGSize)patternSize resourceSize:(CGSize)resourceSize;

#pragma mark - App permissions

/**
 Check permission to access a media.
 
@discussion
 If the access was not yet granted, a dialog will be shown to the user.
 If it is the first attempt to access the media, the dialog is the classic iOS one.
 Else, the dialog will ask the user to manually change the permission in the app settings.

 @param mediaType the media type, either AVMediaTypeVideo or AVMediaTypeAudio.
 @param manualChangeMessage the message to display if the end user must change the app settings manually.
 @param viewController the view controller to attach the dialog displaying manualChangeMessage.
 @param handler the block called with the result of requesting access
 */
+ (void)checkAccessForMediaType:(NSString *)mediaType
            manualChangeMessage:(NSString*)manualChangeMessage
      showPopUpInViewController:(UIViewController*)viewController
              completionHandler:(void (^)(BOOL granted))handler;

/**
 Check required permission for the provided call.

 @param isVideoCall flag set to YES in case of video call.
 @param manualChangeMessage the message to display if the end user must change the app settings manually.
 @param viewController the view controller to attach the dialog displaying manualChangeMessage.
 @param handler the block called with the result of requesting access
 */
+ (void)checkAccessForCall:(BOOL)isVideoCall
manualChangeMessageForAudio:(NSString*)manualChangeMessageForAudio
manualChangeMessageForVideo:(NSString*)manualChangeMessageForVideo
 showPopUpInViewController:(UIViewController*)viewController
         completionHandler:(void (^)(BOOL granted))handler;

/**
 Check permission to access Contacts.

 @discussion
 If the access was not yet granted, a dialog will be shown to the user.
 If it is the first attempt to access the media, the dialog is the classic iOS one.
 Else, the dialog will ask the user to manually change the permission in the app settings.

 @param manualChangeMessage the message to display if the end user must change the app settings manually.
                            If nil, the dialog for displaying manualChangeMessage will not be shown.
 @param viewController the view controller to attach the dialog displaying manualChangeMessage.
 @param handler the block called with the result of requesting access
 */
+ (void)checkAccessForContacts:(NSString*)manualChangeMessage
     showPopUpInViewController:(UIViewController*)viewController
             completionHandler:(void (^)(BOOL granted))handler;

@end
