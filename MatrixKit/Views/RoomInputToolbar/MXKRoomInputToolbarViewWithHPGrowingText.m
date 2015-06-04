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

#import "MXKRoomInputToolbarViewWithHPGrowingText.h"

@interface MXKRoomInputToolbarViewWithHPGrowingText()
{
    
    // HPGrowingTextView triggers growingTextViewDidChange event when it recomposes itself
    // Save the last edited text to prevent unexpected typing events
    NSString* lastEditedText;
}

/**
 Message composer defined in `messageComposerContainer`.
 */
@property (weak, nonatomic) IBOutlet HPGrowingTextView *growingTextView;

@end

@implementation MXKRoomInputToolbarViewWithHPGrowingText

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomInputToolbarViewWithHPGrowingText class])
                          bundle:[NSBundle bundleForClass:[MXKRoomInputToolbarViewWithHPGrowingText class]]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Handle message composer based on HPGrowingTextView use
    _growingTextView.delegate = self;
    
    [_growingTextView setTranslatesAutoresizingMaskIntoConstraints: NO];
    
    // Add an accessory view to the text view in order to retrieve keyboard view.
    inputAccessoryView = [[UIView alloc] initWithFrame:CGRectZero];
    _growingTextView.internalTextView.inputAccessoryView = self.inputAccessoryView;
    
    // set text input font
    _growingTextView.font = [UIFont systemFontOfSize:14];
    
    // draw a rounded border around the textView
    _growingTextView.layer.cornerRadius = 5;
    _growingTextView.layer.borderWidth = 1;
    _growingTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    _growingTextView.clipsToBounds = YES;
    _growingTextView.backgroundColor = [UIColor whiteColor];
    
    // on IOS 8, the growing textview animation could trigger weird UI animations
    // indeed, the messages tableView can be refreshed while its height is updated (e.g. when setting a message)
    _growingTextView.animateHeightChange = NO;
    
    lastEditedText = nil;
}

- (void)dealloc
{
    [self destroy];
}

- (void)destroy
{
    if (_growingTextView)
    {
        _growingTextView.delegate = nil;
    }
    
    [super destroy];
}

- (void)setMaxHeight:(CGFloat)maxHeight
{
    _growingTextView.maxHeight = maxHeight - (self.messageComposerContainerTopConstraint.constant + self.messageComposerContainerBottomConstraint.constant);
    [_growingTextView refreshHeight];
}

- (NSString*)textMessage
{
    return _growingTextView.text;
}

- (void)setTextMessage:(NSString *)textMessage
{
    _growingTextView.text = textMessage;
    self.rightInputToolbarButton.enabled = textMessage.length;
}

- (void)setPlaceholder:(NSString *)inPlaceholder
{
    [super setPlaceholder:inPlaceholder];
    _growingTextView.placeholder = inPlaceholder;
}

- (void)dismissKeyboard
{
    [_growingTextView resignFirstResponder];
}

#pragma mark - HPGrowingTextView delegate

- (void)growingTextViewDidEndEditing:(HPGrowingTextView *)sender
{
    
    if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:isTyping:)])
    {
        [self.delegate roomInputToolbarView:self isTyping:NO];
    }
}

- (void)growingTextViewDidChange:(HPGrowingTextView *)sender
{
    
    NSString *msg = _growingTextView.text;
    
    // HPGrowingTextView triggers growingTextViewDidChange event when it recomposes itself.
    // Save the last edited text to prevent unexpected typing events
    if (![lastEditedText isEqualToString:msg])
    {
        lastEditedText = msg;
        if (msg.length)
        {
            if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:isTyping:)])
            {
                [self.delegate roomInputToolbarView:self isTyping:YES];
            }
            self.rightInputToolbarButton.enabled = YES;
        }
        else
        {
            if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:isTyping:)])
            {
                [self.delegate roomInputToolbarView:self isTyping:NO];
            }
            self.rightInputToolbarButton.enabled = NO;
        }
    }
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height
{
    // Update growing text's superview (toolbar view)
    CGFloat updatedHeight = height + (self.messageComposerContainerTopConstraint.constant + self.messageComposerContainerBottomConstraint.constant);
    if ([self.delegate respondsToSelector:@selector(roomInputToolbarView:heightDidChanged:)])
    {
        [self.delegate roomInputToolbarView:self heightDidChanged:updatedHeight];
    }
}

@end
