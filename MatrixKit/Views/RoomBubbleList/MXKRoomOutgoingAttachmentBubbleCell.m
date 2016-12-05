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

#import "MXKRoomOutgoingAttachmentBubbleCell.h"

#import "MXEvent+MatrixKit.h"

@implementation MXKRoomOutgoingAttachmentBubbleCell

- (void)dealloc
{
    [self stopAnimating];
}

- (void)render:(MXKCellData *)cellData
{
    [super render:cellData];
    
    if (bubbleData)
    {
        // Do not display activity indicator on outgoing attachments (These attachments are supposed to be stored locally)
        // Some download may append to retrieve the actual thumbnail after posting an image.
        self.attachmentView.hideActivityIndicator = YES;
        
        // Check if the image is uploading
        MXKRoomBubbleComponent *component = bubbleData.bubbleComponents.firstObject;
        if (component.event.sentState == MXEventSentStateEncrypting || component.event.sentState == MXEventSentStateUploading)
        {
            // Retrieve the uploadId embedded in the fake url
            bubbleData.uploadId = component.event.content[@"url"];
            
            self.attachmentView.alpha = 0.5;
            
            // Start showing upload progress
            [self startUploadAnimating];
        }
        else if (component.event.sentState == MXEventSentStateSending)
        {
            self.attachmentView.alpha = 0.5;
            [self.activityIndicator startAnimating];
        }
        else if (component.event.sentState == MXEventSentStateFailed)
        {
            self.attachmentView.alpha = 0.5;
            [self.activityIndicator stopAnimating];
        }
        else
        {
            self.attachmentView.alpha = 1;
            [self.activityIndicator stopAnimating];
        }
    }
}

- (void)didEndDisplay
{
    [super didEndDisplay];
    
    // Hide potential loading wheel
    [self stopAnimating];
}

-(void)startUploadAnimating
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaUploadProgressNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onUploadProgress:) name:kMXMediaUploadProgressNotification object:nil];
    
    [self.activityIndicator startAnimating];
    
    MXMediaLoader *uploader = [MXMediaManager existingUploaderWithId:bubbleData.uploadId];
    if (uploader && uploader.statisticsDict)
    {
        [self.activityIndicator stopAnimating];
        [self updateProgressUI:uploader.statisticsDict];
        
        // Check whether the upload is ended
        if (self.progressChartView.progress == 1.0)
        {
            self.progressView.hidden = YES;
        }
    }
    else
    {
        self.progressView.hidden = YES;
    }
}


-(void)stopAnimating
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaUploadProgressNotification object:nil];
    [self.activityIndicator stopAnimating];
}

- (void)onUploadProgress:(NSNotification *)notif
{
    // sanity check
    if ([notif.object isKindOfClass:[NSString class]])
    {
        NSString *uploadId = notif.object;
        if ([uploadId isEqualToString:bubbleData.uploadId])
        {
            [self.activityIndicator stopAnimating];
            [self updateProgressUI:notif.userInfo];
            
            // the upload is ended
            if (self.progressChartView.progress == 1.0)
            {
                self.progressView.hidden = YES;
            }
        }
    }
}

@end