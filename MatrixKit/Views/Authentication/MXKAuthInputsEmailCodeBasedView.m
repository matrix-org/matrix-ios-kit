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

#import "MXKAuthInputsEmailCodeBasedView.h"

@implementation MXKAuthInputsEmailCodeBasedView

+ (UINib *)nib {
    return [UINib nibWithNibName:NSStringFromClass([MXKAuthInputsEmailCodeBasedView class])
                          bundle:[NSBundle bundleForClass:[MXKAuthInputsEmailCodeBasedView class]]];
}

- (CGFloat)actualHeight {
    if (self.authType == MXKAuthenticationTypeLogin) {
        return self.displayNameTextField.frame.origin.y;
    }
    return super.actualHeight;
}

- (BOOL)areAllRequiredFieldsFilled {
    BOOL ret = [super areAllRequiredFieldsFilled];
    
    // Check required fields //FIXME what are required fields in this authentication flow?
    ret = (ret && self.userLoginTextField.text.length && self.emailAndTokenTextField.text.length);
    return ret;
}

- (void)setAuthType:(MXKAuthenticationType)authType {
    // Set initial layout
    self.userLoginTextField.hidden = NO;
    self.promptEmailTokenLabel.hidden = YES;
    
    if (authType == MXKAuthenticationTypeLogin) {
        self.emailAndTokenTextField.returnKeyType = UIReturnKeyDone;
    } else {
        self.emailAndTokenTextField.returnKeyType = UIReturnKeyNext;
    }
    
    super.authType = authType;
}

- (void)dismissKeyboard {
    [self.userLoginTextField resignFirstResponder];
    [self.emailAndTokenTextField resignFirstResponder];
    
    [super dismissKeyboard];
}

- (void)nextStep {
    // Consider here the email token has been requested with success
    [super nextStep];
    
    self.userLoginTextField.hidden = YES;
    self.promptEmailTokenLabel.hidden = NO;
    self.emailAndTokenTextField.returnKeyType = UIReturnKeyDone;
}

#pragma mark UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    if (textField.returnKeyType == UIReturnKeyDone) {
        // "Done" key has been pressed
        [textField resignFirstResponder];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsDoneKeyHasBeenPressed:)]) {
            // Launch authentication now
            [self.delegate authInputsDoneKeyHasBeenPressed:self];
        }
    } else {
        //"Next" key has been pressed
        if (textField == self.userLoginTextField) {
            [self.emailAndTokenTextField becomeFirstResponder];
        } else if (textField == self.emailAndTokenTextField) {
            [self.displayNameTextField becomeFirstResponder];
        }
    }
    
    return YES;
}

@end