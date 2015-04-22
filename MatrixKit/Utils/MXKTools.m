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

@implementation MXKTools

#pragma mark - Time interval

+ (NSString*)formatSecondsInterval:(CGFloat)secondsInterval {
    NSMutableString* formattedString = [[NSMutableString alloc] init];
    
    if (secondsInterval < 1) {
        [formattedString appendString:@"< 1s"];
    } else if (secondsInterval < 60)
    {
        [formattedString appendFormat:@"%ds", (int)secondsInterval];
    }
    else if (secondsInterval < 3600)
    {
        [formattedString appendFormat:@"%dm %2ds", (int)(secondsInterval/60), ((int)secondsInterval) % 60];
    }
    else if (secondsInterval >= 3600)
    {
        [formattedString appendFormat:@"%dh %dm %ds", (int)(secondsInterval / 3600),
         ((int)(secondsInterval) % 3600) / 60,
         (int)(secondsInterval) % 60];
    }
    [formattedString appendString:@" left"];
    
    return formattedString;
}

#pragma mark - File

// return an array of files attributes
+ (NSArray*)listAttributesFiles:(NSString *)folderPath {
    
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

// recursive method to compute the folder content size
+ (long long)folderSize:(NSString *)folderPath {
    long long folderSize = 0;
    NSArray *fileAtts = [MXKTools listAttributesFiles:folderPath];
    
    for(NSDictionary *fileAtt in fileAtts) {
        folderSize += [[fileAtt objectForKey:NSFileSize] intValue];
    }    
    
    return folderSize;
}

// return the list of files by name
// isTimeSorted : the files are sorted by creation date from the oldest to the most recent one
// largeFilesFirst: move the largest file to the list head (large > 100KB). It can be combined isTimeSorted
+ (NSArray*)listFiles:(NSString *)folderPath timeSorted:(BOOL)isTimeSorted largeFilesFirst:(BOOL)largeFilesFirst {
    
    NSArray* attFilesList = [MXKTools listAttributesFiles:folderPath];
    
    if (attFilesList.count > 0) {
        
        // sorted by timestamp (oldest first)
        if (isTimeSorted) {
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"NSFileCreationDate" ascending:YES selector:@selector(compare:)];
            attFilesList = [attFilesList sortedArrayUsingDescriptors:@[ sortDescriptor]];
        }
        
        // list the large files first
        if (largeFilesFirst) {
            NSMutableArray* largeFilesAttList = [[NSMutableArray alloc] init];
            NSMutableArray* smallFilesAttList = [[NSMutableArray alloc] init];
            
            for (NSDictionary* att in attFilesList) {
                if ([[att objectForKey:NSFileSize] intValue] > 100 * 1024) {
                    [largeFilesAttList addObject:att];
                } else {
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
        for (NSDictionary* att in attFilesList) {
            [res addObject:[att valueForKey:@"NSFilePath"]];
        }
        
        return res;
    } else {
        return nil;
    }
}

// return the file extension from a contentType
+ (NSString*)fileExtensionFromContentType:(NSString*)contentType {
    if (!contentType) {
        return @"";
    }
    
    CFStringRef mimeType = (__bridge CFStringRef)contentType;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
    
    NSString* extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    
    CFRelease(uti);
    
    if (extension) {
        return [NSString stringWithFormat:@".%@", extension];
    }
    
    // else undefined type
    if ([contentType isEqualToString:@"application/jpeg"]) {
        return @".jpg";
    } else  if ([contentType isEqualToString:@"audio/x-alaw-basic"]) {
        return @".alaw";
    } else  if ([contentType isEqualToString:@"audio/x-caf"]) {
        return @".caf";
    } else  if ([contentType isEqualToString:@"audio/aac"]) {
        return @".aac";
    }
    
    return @"";
}

#pragma mark - Image

+ (UIImage*)forceImageOrientationUp:(UIImage*)imageSrc {
    if ((imageSrc.imageOrientation == UIImageOrientationUp) || (!imageSrc)) {
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

+ (UIImage *)resize:(UIImage *)image toFitInSize:(CGSize)size {
    UIImage *resizedImage = image;
    
    // Check whether resize is required
    if (size.width && size.height) {
        CGFloat width = image.size.width;
        CGFloat height = image.size.height;
        
        if (width > size.width) {
            height = (height * size.width) / width;
            height = floorf(height / 2) * 2;
            width = size.width;
        }
        if (height > size.height) {
            width = (width * size.height) / height;
            width = floorf(width / 2) * 2;
            height = size.height;
        }
        
        if (width != image.size.width || height != image.size.height) {
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

+ (UIImageOrientation)imageOrientationForRotationAngleInDegree:(NSInteger)angle {
    NSInteger modAngle = angle % 360;
    
    UIImageOrientation orientation = UIImageOrientationUp;
    if (45 <= modAngle && modAngle < 135) {
        return UIImageOrientationRight;
    } else if (135 <= modAngle && modAngle < 225) {
        return UIImageOrientationDown;
    } else if (225 <= modAngle && modAngle < 315) {
        return UIImageOrientationLeft;
    }
    
    return orientation;
}


+ (void)convertVideoToMP4:(NSURL*)videoLocalURL
                  success:(void(^)(NSURL *videoLocalURL, NSString *mimetype, CGSize size, double durationInMs))success
                  failure:(void(^)())failure {

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
    if ([supportedFileTypes containsObject:AVFileTypeMPEG4]) {

        exportSession.outputFileType = AVFileTypeMPEG4;
        mimetype = @"video/mp4";
    }
    else {

        NSLog(@"[MXKTools] convertVideoToMP4: Warning: MPEG-4 file format is not supported. Use QuickTime format.");

        // Fallback to QuickTime format
        exportSession.outputFileType = AVFileTypeQuickTimeMovie;
        mimetype = @"video/quicktime";
    }

    // Export video file
    [exportSession exportAsynchronouslyWithCompletionHandler:^{

        // Check status
        if ([exportSession status] == AVAssetExportSessionStatusCompleted) {

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
            if (videoTracks.count > 0) {

                AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
                videoSize = videoTrack.naturalSize;

                // The operation is complete
                success(outputVideoLocalURL, mimetype, videoSize, durationInMs);
            }
            else {

                NSLog(@"[MXKTools] convertVideoToMP4: Video export failed. Cannot extract video size.");

                // Remove output file (if any)
                [[NSFileManager defaultManager] removeItemAtPath:[outputVideoLocalURL path] error:nil];
                failure();
            }
        }
        else {

            NSLog(@"[MXKTools] convertVideoToMP4: Video export failed. exportSession.status: %d", (int)exportSession.status);

            // Remove output file (if any)
            [[NSFileManager defaultManager] removeItemAtPath:[outputVideoLocalURL path] error:nil];
            failure();
        }
    }];
}

@end
