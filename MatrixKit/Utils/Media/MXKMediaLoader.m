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

#import "MXKMediaManager.h"
#import "MXKTools.h"
#import "MatrixSDK.h"

NSString *const kMXKMediaDownloadProgressNotification = @"kMXKMediaDownloadProgressNotification";
NSString *const kMXKMediaDownloadDidFinishNotification = @"kMXKMediaDownloadDidFinishNotification";
NSString *const kMXKMediaDownloadDidFailNotification = @"kMXKMediaDownloadDidFailNotification";

NSString *const kMXKMediaUploadProgressNotification = @"kMXKMediaUploadProgressNotification";
NSString *const kMXKMediaUploadDidFinishNotification = @"kMXKMediaUploadDidFinishNotification";
NSString *const kMXKMediaUploadDidFailNotification = @"kMXKMediaUploadDidFailNotification";

NSString *const kMXKMediaLoaderProgressValueKey = @"kMXKMediaLoaderProgressValueKey";
NSString *const kMXKMediaLoaderCompletedBytesCountKey = @"kMXKMediaLoaderCompletedBytesCountKey";
NSString *const kMXKMediaLoaderTotalBytesCountKey = @"kMXKMediaLoaderTotalBytesCountKey";
NSString *const kMXKMediaLoaderCurrentDataRateKey = @"kMXKMediaLoaderCurrentDataRateKey";

NSString *const kMXKMediaLoaderFilePathKey = @"kMXKMediaLoaderFilePathKey";
NSString *const kMXKMediaLoaderErrorKey = @"kMXKMediaLoaderErrorKey";

NSString *const kMXKMediaUploadIdPrefix = @"upload-";

@implementation MXKMediaLoader

@synthesize statisticsDict;

- (void)cancel
{
    // Cancel potential connection
    if (downloadConnection)
    {
        NSLog(@"[MXKMediaLoader] Media download has been cancelled (%@)", mediaURL);
        if (onError){
            onError(nil);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadDidFailNotification
                                                            object:mediaURL
                                                          userInfo:nil];
        // Reset blocks
        onSuccess = nil;
        onError = nil;
        [downloadConnection cancel];
        downloadConnection = nil;
        downloadData = nil;
    }
    else
    {
        if (operation && operation.operation
            && operation.operation.state != NSURLSessionTaskStateCanceling && operation.operation.state != NSURLSessionTaskStateCompleted)
        {
            NSLog(@"[MXKMediaLoader] Media upload has been cancelled");
            [operation cancel];
            operation = nil;
        }
        
        // Reset blocks
        onSuccess = nil;
        onError = nil;
    }
    statisticsDict = nil;
}

- (void)dealloc
{
    [self cancel];
    
    mxSession = nil;
}

#pragma mark - Download

- (void)downloadMediaFromURL:(NSString *)url
           andSaveAtFilePath:(NSString *)filePath
                     success:(blockMXKMediaLoader_onSuccess)success
                     failure:(blockMXKMediaLoader_onError)failure
{
    // Report provided params
    mediaURL = url;
    outputFilePath = filePath;
    onSuccess = success;
    onError = failure;
    
    downloadStartTime = statsStartTime = CFAbsoluteTimeGetCurrent();
    lastProgressEventTimeStamp = -1;
    
    // Start downloading
    NSURL *nsURL = [NSURL URLWithString:url];
    downloadData = [[NSMutableData alloc] init];
    
    downloadConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:nsURL] delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    expectedSize = response.expectedContentLength;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"[MXKMediaLoader] Failed to download media (%@): %@", mediaURL, error);
    // send the latest known upload info
    [self progressCheckTimeout:nil];
    statisticsDict = nil;
    if (onError)
    {
        onError (error);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadDidFailNotification
                                                        object:mediaURL
                                                      userInfo:@{kMXKMediaLoaderErrorKey:error}];
    
    downloadData = nil;
    downloadConnection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append data
    [downloadData appendData:data];
    
    if (expectedSize > 0)
    {
        float progressValue = ((float)downloadData.length) / ((float)expectedSize);
        if (progressValue > 1)
        {
            // Should never happen
            progressValue = 1.0;
        }
        
        CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
        CGFloat meanRate = downloadData.length / (currentTime - downloadStartTime);
        
        // build the user info dictionary
        NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
        [dict setValue:[NSNumber numberWithFloat:progressValue] forKey:kMXKMediaLoaderProgressValueKey];
        [dict setValue:[NSNumber numberWithUnsignedInteger:downloadData.length] forKey:kMXKMediaLoaderCompletedBytesCountKey];
        [dict setValue:[NSNumber numberWithLongLong:expectedSize] forKey:kMXKMediaLoaderTotalBytesCountKey];
        [dict setValue:[NSNumber numberWithFloat:meanRate] forKey:kMXKMediaLoaderCurrentDataRateKey];
        
        statisticsDict = dict;
        
        // after 0.1s, resend the progress info
        // the upload can be stuck
        [progressCheckTimer invalidate];
        progressCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(progressCheckTimeout:) userInfo:self repeats:NO];
        
        // trigger the event only each 0.1s to avoid send to many events
        if ((lastProgressEventTimeStamp == -1) || ((currentTime - lastProgressEventTimeStamp) > 0.1))
        {
            lastProgressEventTimeStamp = currentTime;
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadProgressNotification object:mediaURL userInfo:statisticsDict];
        }
    }
}

- (IBAction)progressCheckTimeout:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadProgressNotification object:mediaURL userInfo:statisticsDict];
    [progressCheckTimer invalidate];
    progressCheckTimer = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // send the latest known upload info
    [self progressCheckTimeout:nil];
    statisticsDict = nil;
    
    if (downloadData.length)
    {
        // Cache the downloaded data
        if ([MXKMediaManager writeMediaData:downloadData toFilePath:outputFilePath])
        {
            // Call registered block
            if (onSuccess)
            {
                onSuccess(outputFilePath);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadDidFinishNotification
                                                                object:mediaURL
                                                              userInfo:@{kMXKMediaLoaderFilePathKey: outputFilePath}];
        }
        else
        {
            NSLog(@"[MXKMediaLoader] Failed to write file: %@", mediaURL);
            if (onError){
                onError(nil);
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadDidFailNotification
                                                                object:mediaURL
                                                              userInfo:nil];
        }
    }
    else
    {
        NSLog(@"[MXKMediaLoader] Failed to download media: %@", mediaURL);
        if (onError){
            onError(nil);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaDownloadDidFailNotification
                                                            object:mediaURL
                                                          userInfo:nil];
    }
    
    downloadData = nil;
    downloadConnection = nil;
}

#pragma mark - Upload

- (id)initForUploadWithMatrixSession:(MXSession*)matrixSession initialRange:(CGFloat)initialRange andRange:(CGFloat)range
{
    if (self = [super init])
    {
        // Create a unique upload Id
        _uploadId = [NSString stringWithFormat:@"%@%@", kMXKMediaUploadIdPrefix, [[NSProcessInfo processInfo] globallyUniqueString]];
        
        mxSession = matrixSession;
        _uploadInitialRange = initialRange;
        _uploadRange = range;
    }
    return self;
}

- (void)uploadData:(NSData *)data filename:(NSString*)filename mimeType:(NSString *)mimeType success:(blockMXKMediaLoader_onSuccess)success failure:(blockMXKMediaLoader_onError)failure
{
    statsStartTime = CFAbsoluteTimeGetCurrent();
    lastTotalBytesWritten = 0;
    
    operation = [mxSession.matrixRestClient uploadContent:data
                                                 filename:filename
                                                 mimeType:mimeType
                                                  timeout:30
                                                  success:^(NSString *url) {
                                                      if (success)
                                                      {
                                                          success(url);
                                                      }
                                                      [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaUploadDidFinishNotification
                                                                                                          object:_uploadId
                                                                                                        userInfo:nil];
                                                  } failure:^(NSError *error) {
                                                      if (failure)
                                                      {
                                                          failure (error);
                                                      }
                                                      [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaUploadDidFailNotification
                                                                                                          object:_uploadId
                                                                                                        userInfo:@{kMXKMediaLoaderErrorKey:error}];
                                                  } uploadProgress:^(NSProgress *uploadProgress) {
                                                      [self updateUploadProgress:uploadProgress];
                                                  }];
}

- (void)updateUploadProgress:(NSProgress*)uploadProgress
{
    int64_t totalBytesWritten = uploadProgress.completedUnitCount;
    int64_t totalBytesExpectedToWrite = uploadProgress.totalUnitCount;

    // Compute the bytes written since last time
    int64_t bytesWritten = totalBytesWritten - lastTotalBytesWritten;
    lastTotalBytesWritten = totalBytesWritten;

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (!statisticsDict)
    {
        statisticsDict = [[NSMutableDictionary alloc] init];
    }
    
    CGFloat progressValue = self.uploadInitialRange + (((float)totalBytesWritten) /  ((float)totalBytesExpectedToWrite) * self.uploadRange);
    [statisticsDict setValue:[NSNumber numberWithFloat:progressValue] forKey:kMXKMediaLoaderProgressValueKey];
    
    CGFloat dataRate = 0;
    if (currentTime != statsStartTime)
    {
        dataRate = bytesWritten / (currentTime - statsStartTime);
    }
    else
    {
        dataRate = bytesWritten / 0.001;
    }
    statsStartTime = currentTime;
    
    [statisticsDict setValue:[NSNumber numberWithLongLong:totalBytesWritten] forKey:kMXKMediaLoaderCompletedBytesCountKey];
    [statisticsDict setValue:[NSNumber numberWithLongLong:totalBytesExpectedToWrite] forKey:kMXKMediaLoaderTotalBytesCountKey];
    [statisticsDict setValue:[NSNumber numberWithFloat:dataRate] forKey:kMXKMediaLoaderCurrentDataRateKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKMediaUploadProgressNotification object:_uploadId userInfo:statisticsDict];
}

@end
