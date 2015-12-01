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

#import "MXKRoomOutgoingBubbleTableViewCell.h"

#import "MXEvent+MatrixKit.h"

#import "NSBundle+Matrixkit.h"

@implementation MXKRoomOutgoingBubbleTableViewCell

- (void)render:(MXKCellData *)cellData
{
    [super render:cellData];
    
    if (self.bubbleData)
    {
        // Add unsent label for failed components (only if bubbleInfoContainer is defined)
        if (self.bubbleInfoContainer)
        {
            for (MXKRoomBubbleComponent *component in self.bubbleData.bubbleComponents)
            {
                if (component.event.mxkState == MXKEventStateSendingFailed)
                {
                    UIButton *unsentButton = [[UIButton alloc] initWithFrame:CGRectMake(0, component.position.y, 58 , 20)];
                    
                    [unsentButton setTitle:[NSBundle mxk_localizedStringForKey:@"unsent"] forState:UIControlStateNormal];
                    [unsentButton setTitle:[NSBundle mxk_localizedStringForKey:@"unsent"] forState:UIControlStateSelected];
                    [unsentButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
                    [unsentButton setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
                    
                    unsentButton.backgroundColor = [UIColor whiteColor];
                    unsentButton.titleLabel.font =  [UIFont systemFontOfSize:14];
                    
                    [unsentButton addTarget:self action:@selector(onResendToggle:) forControlEvents:UIControlEventTouchUpInside];
                    
                    [self.bubbleInfoContainer addSubview:unsentButton];
                    self.bubbleInfoContainer.hidden = NO;
                    self.bubbleInfoContainer.userInteractionEnabled = YES;
                    
                    // ensure that bubbleInfoContainer is at front to catch the tap event
                    [self.bubbleInfoContainer.superview bringSubviewToFront:self.bubbleInfoContainer];
                }
            }
        }
    }
}

- (void)didEndDisplay
{
    [super didEndDisplay];
    
    self.bubbleInfoContainer.userInteractionEnabled = NO;
}

#pragma mark - User actions

- (IBAction)onResendToggle:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]] && self.delegate)
    {
        MXEvent *selectedEvent = nil;
        if (self.bubbleData.bubbleComponents.count == 1)
        {
            MXKRoomBubbleComponent *component = [self.bubbleData.bubbleComponents firstObject];
            selectedEvent = component.event;
        }
        else if (self.bubbleData.bubbleComponents.count)
        {
            // Here the selected view is a textView (attachment has no more than one component)
            
            // Look for the selected component
            UIButton *unsentButton = (UIButton *)sender;
            for (MXKRoomBubbleComponent *component in self.bubbleData.bubbleComponents)
            {
                if (unsentButton.frame.origin.y == component.position.y)
                {
                    selectedEvent = component.event;
                    break;
                }
            }
        }
        
        if (selectedEvent)
        {
            [self.delegate cell:self didRecognizeAction:kMXKRoomBubbleCellUnsentButtonPressed userInfo:@{kMXKRoomBubbleCellEventKey:selectedEvent}];
        }
    }
}

@end