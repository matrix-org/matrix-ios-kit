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

#import "MXKTools.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <AddressBook/AddressBook.h>

#import "NSBundle+MatrixKit.h"

#import "MXKAlert.h"
#import "MXCall.h"

@implementation MXKTools

#pragma mark - Time interval

+ (NSString*)formatSecondsInterval:(CGFloat)secondsInterval
{
    NSMutableString* formattedString = [[NSMutableString alloc] init];
    
    if (secondsInterval < 1)
    {
        [formattedString appendFormat:@"< 1%@", [NSBundle mxk_localizedStringForKey:@"format_time_s"]];;
    }
    else if (secondsInterval < 60)
    {
        [formattedString appendFormat:@"%d%@", (int)secondsInterval, [NSBundle mxk_localizedStringForKey:@"format_time_s"]];
    }
    else if (secondsInterval < 3600)
    {
        [formattedString appendFormat:@"%d%@ %2d%@", (int)(secondsInterval/60), [NSBundle mxk_localizedStringForKey:@"format_time_m"],
         ((int)secondsInterval) % 60, [NSBundle mxk_localizedStringForKey:@"format_time_s"]];
    }
    else if (secondsInterval >= 3600)
    {
        [formattedString appendFormat:@"%d%@ %d%@ %d%@", (int)(secondsInterval / 3600), [NSBundle mxk_localizedStringForKey:@"format_time_h"],
         ((int)(secondsInterval) % 3600) / 60, [NSBundle mxk_localizedStringForKey:@"format_time_m"],
         (int)(secondsInterval) % 60, [NSBundle mxk_localizedStringForKey:@"format_time_s"]];
    }
    [formattedString appendString:@" left"];
    
    return formattedString;
}

+ (NSString *)formatSecondsIntervalFloored:(CGFloat)secondsInterval
{
    NSString* formattedString;

    if (secondsInterval < 0)
    {
        formattedString = [NSString stringWithFormat:@"0%@", [NSBundle mxk_localizedStringForKey:@"format_time_s"]];
    }
    else
    {
        NSUInteger seconds = secondsInterval;
        if (seconds < 60)
        {
            formattedString = [NSString stringWithFormat:@"%tu%@", seconds, [NSBundle mxk_localizedStringForKey:@"format_time_s"]];
        }
        else if (secondsInterval < 3600)
        {
            formattedString = [NSString stringWithFormat:@"%tu%@", seconds / 60, [NSBundle mxk_localizedStringForKey:@"format_time_m"]];
        }
        else if (secondsInterval < 86400)
        {
            formattedString = [NSString stringWithFormat:@"%tu%@", seconds / 3600, [NSBundle mxk_localizedStringForKey:@"format_time_h"]];
        }
        else
        {
            formattedString = [NSString stringWithFormat:@"%tu%@", seconds / 86400, [NSBundle mxk_localizedStringForKey:@"format_time_d"]];
        }
    }

    return formattedString;
}

#pragma mark - File

// return an array of files attributes
+ (NSArray*)listAttributesFiles:(NSString *)folderPath
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:nil];
    NSEnumerator *contentsEnumurator = [contents objectEnumerator];
    
    NSString *file;
    NSMutableArray* res = [[NSMutableArray alloc] init];
    
    while (file = [contentsEnumurator nextObject])
        
    {
        NSString* itemPath = [folderPath stringByAppendingPathComponent:file];
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
        
        // is directory
        if ([[fileAttributes objectForKey:NSFileType] isEqual:NSFileTypeDirectory])
            
        {
            [res addObjectsFromArray:[MXKTools listAttributesFiles:itemPath]];
        }
        else
            
        {
            NSMutableDictionary* att = [fileAttributes mutableCopy];
            // add the file path
            [att setObject:itemPath forKey:@"NSFilePath"];
            [res addObject:att];
        }
    }
    
    return res;
}

+ (long long)roundFileSize:(long long)filesize
{
    static long long roundedFactor = (100 * 1024);
    static long long smallRoundedFactor = (10 * 1024);
    long long roundedFileSize = filesize;
    
    if (filesize > roundedFactor)
    {
        roundedFileSize = ((filesize + (roundedFactor /2)) / roundedFactor) * roundedFactor;
    }
    else if (filesize > smallRoundedFactor)
    {
        roundedFileSize = ((filesize + (smallRoundedFactor /2)) / smallRoundedFactor) * smallRoundedFactor;
    }
    
    return roundedFileSize;
}

+ (NSString*)fileSizeToString:(long)fileSize
{
    if (fileSize < 0)
    {
        return @"";
    }
    else if (fileSize < 1024)
    {
        return [NSString stringWithFormat:@"%ld bytes", fileSize];
    }
    else if (fileSize < (1024 * 1024))
    {
        return [NSString stringWithFormat:@"%.2f KB", (fileSize / 1024.0)];
    }
    else
    {
        return [NSString stringWithFormat:@"%.2f MB", (fileSize / 1024.0 / 1024.0)];
    }
}

// recursive method to compute the folder content size
+ (long long)folderSize:(NSString *)folderPath
{
    long long folderSize = 0;
    NSArray *fileAtts = [MXKTools listAttributesFiles:folderPath];
    
    for(NSDictionary *fileAtt in fileAtts)
    {
        folderSize += [[fileAtt objectForKey:NSFileSize] intValue];
    }
    
    return folderSize;
}

// return the list of files by name
// isTimeSorted : the files are sorted by creation date from the oldest to the most recent one
// largeFilesFirst: move the largest file to the list head (large > 100KB). It can be combined isTimeSorted
+ (NSArray*)listFiles:(NSString *)folderPath timeSorted:(BOOL)isTimeSorted largeFilesFirst:(BOOL)largeFilesFirst
{
    NSArray* attFilesList = [MXKTools listAttributesFiles:folderPath];
    
    if (attFilesList.count > 0)
    {
        
        // sorted by timestamp (oldest first)
        if (isTimeSorted)
        {
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"NSFileCreationDate" ascending:YES selector:@selector(compare:)];
            attFilesList = [attFilesList sortedArrayUsingDescriptors:@[ sortDescriptor]];
        }
        
        // list the large files first
        if (largeFilesFirst)
        {
            NSMutableArray* largeFilesAttList = [[NSMutableArray alloc] init];
            NSMutableArray* smallFilesAttList = [[NSMutableArray alloc] init];
            
            for (NSDictionary* att in attFilesList)
            {
                if ([[att objectForKey:NSFileSize] intValue] > 100 * 1024)
                {
                    [largeFilesAttList addObject:att];
                }
                else
                {
                    [smallFilesAttList addObject:att];
                }
            }
            
            NSMutableArray* mergedList = [[NSMutableArray alloc] init];
            [mergedList addObjectsFromArray:largeFilesAttList];
            [mergedList addObjectsFromArray:smallFilesAttList];
            attFilesList = mergedList;
        }
        
        // list filenames
        NSMutableArray* res = [[NSMutableArray alloc] init];
        for (NSDictionary* att in attFilesList)
        {
            [res addObject:[att valueForKey:@"NSFilePath"]];
        }
        
        return res;
    }
    else
    {
        return nil;
    }
}


// cache the value to improve the UX.
static NSMutableDictionary *fileExtensionByContentType = nil;

// return the file extension from a contentType
+ (NSString*)fileExtensionFromContentType:(NSString*)contentType
{
    // sanity checks
    if (!contentType || (0 == contentType.length))
    {
        return @"";
    }
    
    NSString* fileExt = nil;
    
    if (!fileExtensionByContentType)
    {
        fileExtensionByContentType  = [[NSMutableDictionary alloc] init];
    }
    
    fileExt = fileExtensionByContentType[contentType];
    
    if (!fileExt)
    {
        fileExt = @"";
        
        // else undefined type
        if ([contentType isEqualToString:@"application/jpeg"])
        {
            fileExt = @".jpg";
        }
        else if ([contentType isEqualToString:@"audio/x-alaw-basic"])
        {
            fileExt = @".alaw";
        }
        else if ([contentType isEqualToString:@"audio/x-caf"])
        {
            fileExt = @".caf";
        }
        else if ([contentType isEqualToString:@"audio/aac"])
        {
            fileExt =  @".aac";
        }
        else
        {
            CFStringRef mimeType = (__bridge CFStringRef)contentType;
            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
            
            NSString* extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
            
            CFRelease(uti);
            
            if (extension)
            {
                fileExt = [NSString stringWithFormat:@".%@", extension];
            }
        }
        
        [fileExtensionByContentType setObject:fileExt forKey:contentType];
    }
    
    return fileExt;
}

#pragma mark - Hex color to UIColor conversion

+ (UIColor *)colorWithRGBValue:(NSUInteger)rgbValue
{
    return [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
}

+ (UIColor *)colorWithARGBValue:(NSUInteger)argbValue
{
    return [UIColor colorWithRed:((float)((argbValue & 0xFF0000) >> 16))/255.0 green:((float)((argbValue & 0xFF00) >> 8))/255.0 blue:((float)(argbValue & 0xFF))/255.0 alpha:((float)((argbValue & 0xFF000000) >> 24))/255.0];
}

+ (NSUInteger)rgbValueWithColor:(UIColor*)color
{
    CGFloat red, green, blue, alpha;
    
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    NSUInteger rgbValue = ((int)(red * 255) << 16) + ((int)(green * 255) << 8) + (blue * 255);
    
    return rgbValue;
}

+ (NSUInteger)argbValueWithColor:(UIColor*)color
{
    CGFloat red, green, blue, alpha;
    
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    NSUInteger argbValue = ((int)(alpha * 255) << 24) + ((int)(red * 255) << 16) + ((int)(green * 255) << 8) + (blue * 255);
    
    return argbValue;
}

#pragma mark - Image

+ (UIImage*)forceImageOrientationUp:(UIImage*)imageSrc
{
    if ((imageSrc.imageOrientation == UIImageOrientationUp) || (!imageSrc))
    {
        // Nothing to do
        return imageSrc;
    }
    
    // Draw the entire image in a graphics context, respecting the image’s orientation setting
    UIGraphicsBeginImageContext(imageSrc.size);
    [imageSrc drawAtPoint:CGPointMake(0, 0)];
    UIImage *retImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return retImage;
}

+ (CGSize)resizeImageSize:(CGSize)originalSize toFitInSize:(CGSize)maxSize canExpand:(BOOL)canExpand
{
    if ((originalSize.width == 0) || (originalSize.height == 0))
    {
        return CGSizeZero;
    }
    
    CGSize resized = originalSize;
    
    if ((maxSize.width > 0) && (maxSize.height > 0) && (canExpand || ((originalSize.width > maxSize.width) || (originalSize.height > maxSize.height))))
    {
        CGFloat ratioX = maxSize.width  / originalSize.width;
        CGFloat ratioY = maxSize.height / originalSize.height;
        
        CGFloat scale = MIN(ratioX, ratioY);
        resized.width  *= scale;
        resized.height *= scale;
        
        // padding
        resized.width  = floorf(resized.width  / 2) * 2;
        resized.height = floorf(resized.height / 2) * 2;
    }
    
    return resized;
}

+ (CGSize)resizeImageSize:(CGSize)originalSize toFillWithSize:(CGSize)maxSize canExpand:(BOOL)canExpand
{
    CGSize resized = originalSize;
    
    if ((maxSize.width > 0) && (maxSize.height > 0) && (canExpand || ((originalSize.width > maxSize.width) && (originalSize.height > maxSize.height))))
    {
        CGFloat ratioX = maxSize.width  / originalSize.width;
        CGFloat ratioY = maxSize.height / originalSize.height;
        
        CGFloat scale = MAX(ratioX, ratioY);
        resized.width  *= scale;
        resized.height *= scale;
        
        // padding
        resized.width  = floorf(resized.width  / 2) * 2;
        resized.height = floorf(resized.height / 2) * 2;
    }
    
    return resized;
}

+ (UIImage *)reduceImage:(UIImage *)image toFitInSize:(CGSize)size
{
    UIImage *resizedImage = image;
    
    // Check whether resize is required
    if (size.width && size.height)
    {
        CGFloat width = image.size.width;
        CGFloat height = image.size.height;
        
        if (width > size.width)
        {
            height = (height * size.width) / width;
            height = floorf(height / 2) * 2;
            width = size.width;
        }
        if (height > size.height)
        {
            width = (width * size.height) / height;
            width = floorf(width / 2) * 2;
            height = size.height;
        }
        
        if (width != image.size.width || height != image.size.height)
        {
            // Create the thumbnail
            CGSize imageSize = CGSizeMake(width, height);
            UIGraphicsBeginImageContext(imageSize);
            
            //            // set to the top quality
            //            CGContextRef context = UIGraphicsGetCurrentContext();
            //            CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
            
            CGRect thumbnailRect = CGRectMake(0, 0, 0, 0);
            thumbnailRect.origin = CGPointMake(0.0,0.0);
            thumbnailRect.size.width  = imageSize.width;
            thumbnailRect.size.height = imageSize.height;
            
            [image drawInRect:thumbnailRect];
            resizedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    }
    
    return resizedImage;
}

+ (UIImage*)resizeImage:(UIImage *)image toSize:(CGSize)size
{
    UIImage *resizedImage = image;
    
    // Check whether resize is required
    if (size.width && size.height)
    {
        UIGraphicsBeginImageContext(size);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resizedImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    return resizedImage;
}

+ (UIImage*)paintImage:(UIImage*)image withColor:(UIColor*)color
{
    UIImage *newImage;
    
    const CGFloat *colorComponents = CGColorGetComponents(color.CGColor);
    
    // Create a new image with the same size
    UIGraphicsBeginImageContextWithOptions(image.size, 0, 0);
    
    CGContextRef gc = UIGraphicsGetCurrentContext();
    
    CGRect rect = (CGRect){ .size = image.size};
    
    [image drawInRect:rect
            blendMode:kCGBlendModeNormal
                alpha:1];
    
    // Binarize the image: Transform all colors into the provided color but keep the alpha
    CGContextSetBlendMode(gc, kCGBlendModeSourceIn);
    CGContextSetRGBFillColor(gc, colorComponents[0], colorComponents[1], colorComponents[2], colorComponents[3]);
    CGContextFillRect(gc, rect);
    
    // Retrieve the result into an UIImage
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (UIImageOrientation)imageOrientationForRotationAngleInDegree:(NSInteger)angle
{
    NSInteger modAngle = angle % 360;
    
    UIImageOrientation orientation = UIImageOrientationUp;
    if (45 <= modAngle && modAngle < 135)
    {
        return UIImageOrientationRight;
    }
    else if (135 <= modAngle && modAngle < 225)
    {
        return UIImageOrientationDown;
    }
    else if (225 <= modAngle && modAngle < 315)
    {
        return UIImageOrientationLeft;
    }
    
    return orientation;
}


+ (void)convertVideoToMP4:(NSURL*)videoLocalURL
                  success:(void(^)(NSURL *videoLocalURL, NSString *mimetype, CGSize size, double durationInMs))success
                  failure:(void(^)())failure
{
    NSParameterAssert(success);
    NSParameterAssert(failure);
    
    NSURL *outputVideoLocalURL;
    NSString *mimetype;
    
    // Define a random output URL in the cache foler
    NSString * outputFileName = [NSString stringWithFormat:@"%.0f.mp4",[[NSDate date] timeIntervalSince1970]];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheRoot = [paths objectAtIndex:0];
    outputVideoLocalURL = [NSURL fileURLWithPath:[cacheRoot stringByAppendingPathComponent:outputFileName]];
    
    // Convert video container to mp4
    // Use medium quality to save bandwidth
    AVURLAsset* videoAsset = [AVURLAsset URLAssetWithURL:videoLocalURL options:nil];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:videoAsset presetName:AVAssetExportPresetMediumQuality];
    exportSession.outputURL = outputVideoLocalURL;
    
    // Check output file types supported by the device
    NSArray *supportedFileTypes = exportSession.supportedFileTypes;
    if ([supportedFileTypes containsObject:AVFileTypeMPEG4])
    {
        exportSession.outputFileType = AVFileTypeMPEG4;
        mimetype = @"video/mp4";
    }
    else
    {
        NSLog(@"[MXKTools] convertVideoToMP4: Warning: MPEG-4 file format is not supported. Use QuickTime format.");
        
        // Fallback to QuickTime format
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        mimetype = @"video/quicktime";
    }
    
    // Export video file
    [exportSession exportAsynchronouslyWithCompletionHandler:^{

        AVAssetExportSessionStatus status = exportSession.status;

        // Come back to the UI thread to avoid race conditions
        dispatch_async(dispatch_get_main_queue(), ^{

            // Check status
            if (status == AVAssetExportSessionStatusCompleted)
            {

                AVURLAsset* asset = [AVURLAsset URLAssetWithURL:outputVideoLocalURL
                                                        options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [NSNumber numberWithBool:YES],
                                                                 AVURLAssetPreferPreciseDurationAndTimingKey,
                                                                 nil]
                                     ];

                double durationInMs = (1000 * CMTimeGetSeconds(asset.duration));

                // Extract the video size
                CGSize videoSize;
                NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                if (videoTracks.count > 0)
                {

                    AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
                    videoSize = videoTrack.naturalSize;

                    // The operation is complete
                    success(outputVideoLocalURL, mimetype, videoSize, durationInMs);
                }
                else
                {

                    NSLog(@"[MXKTools] convertVideoToMP4: Video export failed. Cannot extract video size.");

                    // Remove output file (if any)
                    [[NSFileManager defaultManager] removeItemAtPath:[outputVideoLocalURL path] error:nil];
                    failure();
                }
            }
            else
            {

                NSLog(@"[MXKTools] convertVideoToMP4: Video export failed. exportSession.status: %tu", status);

                // Remove output file (if any)
                [[NSFileManager defaultManager] removeItemAtPath:[outputVideoLocalURL path] error:nil];
                failure();
            }
        });

    }];
}

static NSMutableDictionary* backgroundByImageNameDict;

+ (UIColor*)convertImageToPatternColor:(NSString*)reourceName backgroundColor:(UIColor*)backgroundColor patternSize:(CGSize)patternSize resourceSize:(CGSize)resourceSize
{
    if (!reourceName)
    {
        return backgroundColor;
    }
    
    if (!backgroundByImageNameDict)
    {
        backgroundByImageNameDict = [[NSMutableDictionary alloc] init];
    }
    
    NSString* key = [NSString stringWithFormat:@"%@ %f %f", reourceName, patternSize.width, resourceSize.width];
    
    UIColor* bgColor = [backgroundByImageNameDict objectForKey:key];
    
    if (!bgColor)
    {
        UIImageView* backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, patternSize.width, patternSize.height)];
        backgroundView.backgroundColor = backgroundColor;
        
        CGFloat offsetX = (patternSize.width - resourceSize.width) / 2.0f;
        CGFloat offsetY = (patternSize.height - resourceSize.height) / 2.0f;
        
        UIImageView* resourceImageView = [[UIImageView alloc] initWithFrame:CGRectMake(offsetX, offsetY, resourceSize.width, resourceSize.height)];
        resourceImageView.backgroundColor = [UIColor clearColor];
        resourceImageView.image = [MXKTools resizeImage:[UIImage imageNamed:reourceName] toSize:resourceSize];
        
        [backgroundView addSubview:resourceImageView];
        
        // Create a "canvas" (image context) to draw in.
        UIGraphicsBeginImageContextWithOptions(backgroundView.frame.size, NO, 0);
        
        // set to the top quality
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        [[backgroundView layer] renderInContext: UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        
        bgColor = [[UIColor alloc] initWithPatternImage:image];
        [backgroundByImageNameDict setObject:bgColor forKey:key];
    }
    
    return bgColor;
}

#pragma mark - App permissions

+ (void)checkAccessForMediaType:(NSString *)mediaType
            manualChangeMessage:(NSString *)manualChangeMessage
      showPopUpInViewController:(UIViewController *)viewController
              completionHandler:(void (^)(BOOL))handler
{
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (granted)
            {
                handler(YES);
            }
            else
            {
                // Access not granted to mediaType
                // Display manualChangeMessage
                MXKAlert *alert = [[MXKAlert alloc] initWithTitle:nil message:manualChangeMessage style:MXKAlertStyleAlert];

                // On iOS >= 8, add a shortcut to the app settings
                if (UIApplicationOpenSettingsURLString)
                {
                    [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"settings"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {

                        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        [[UIApplication sharedApplication] openURL:url];

                        // Note: it does not worth to check if the user changes the permission
                        // because iOS restarts the app in case of change of app privacy settings
                        handler(NO);
                    }];
                }

                alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    
                    handler(NO);
                }];
                
                [alert showInViewController:viewController];
            }
            
        });
    }];
}

+ (void)checkAccessForCall:(BOOL)isVideoCall
manualChangeMessageForAudio:(NSString*)manualChangeMessageForAudio
manualChangeMessageForVideo:(NSString*)manualChangeMessageForVideo
 showPopUpInViewController:(UIViewController*)viewController
         completionHandler:(void (^)(BOOL granted))handler
{
    // Check first microphone permission
    [MXKTools checkAccessForMediaType:AVMediaTypeAudio manualChangeMessage:manualChangeMessageForAudio showPopUpInViewController:viewController completionHandler:^(BOOL granted) {

        if (granted)
        {
            // Check camera permission in case of video call
            if (isVideoCall)
            {
                [MXKTools checkAccessForMediaType:AVMediaTypeVideo manualChangeMessage:manualChangeMessageForVideo showPopUpInViewController:viewController completionHandler:^(BOOL granted) {

                    handler(granted);
                }];
            }
            else
            {
                handler(YES);
            }
        }
        else
        {
            handler(NO);
        }
    }];
}

+ (void)checkAccessForContacts:(NSString *)manualChangeMessage
     showPopUpInViewController:(UIViewController *)viewController
             completionHandler:(void (^)(BOOL granted))handler
{
    // Check if the application is allowed to list the contacts
    ABAuthorizationStatus cbStatus = ABAddressBookGetAuthorizationStatus();
    if (cbStatus == kABAuthorizationStatusAuthorized)
    {
        handler(YES);
    }
    else if (cbStatus == kABAuthorizationStatusNotDetermined)
    {
        // Request address book access
        ABAddressBookRef ab = ABAddressBookCreateWithOptions(nil, nil);
        if (ab)
        {
            ABAddressBookRequestAccessWithCompletion(ab, ^(bool granted, CFErrorRef error) {
                dispatch_async(dispatch_get_main_queue(), ^{

                    if (granted)
                    {
                        handler(YES);
                    }

                });
            });

            CFRelease(ab);
        }
        else
        {
            // No phonebook
            handler(YES);
        }
    }
    else if (cbStatus == kABAuthorizationStatusDenied && viewController && manualChangeMessage)
    {
        // Access not granted to the local contacts
        // Display manualChangeMessage
        MXKAlert *alert = [[MXKAlert alloc] initWithTitle:nil message:manualChangeMessage style:MXKAlertStyleAlert];

        // On iOS >= 8, add a shortcut to the app settings
        if (UIApplicationOpenSettingsURLString)
        {
            [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"settings"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {

                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                [[UIApplication sharedApplication] openURL:url];

                // Note: it does not worth to check if the user changes the permission
                // because iOS restarts the app in case of change of app privacy settings
                handler(NO);
            }];
        }

        alert.cancelButtonIndex = [alert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {

            handler(NO);
        }];

        [alert showInViewController:viewController];
    }
    else
    {
        handler(NO);
    }
}

@end
