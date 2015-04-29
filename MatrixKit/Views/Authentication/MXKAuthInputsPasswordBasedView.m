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

#import "MXKAuthInputsPasswordBasedView.h"

@implementation MXKAuthInputsPasswordBasedView
@dynamic displayNameTextField;

+ (UINib *)nib {
    return [UINib nibWithNibName:NSStringFromClass([MXKAuthInputsPasswordBasedView class])
                          bundle:[NSBundle bundleForClass:[MXKAuthInputsPasswordBasedView class]]];
}

- (CGFloat)actualHeight {
    if (self.authType == MXKAuthenticationTypeLogin) {
        return self.displayNameTextField.frame.origin.y;
    }
    return super.actualHeight;
}

- (BOOL)areAllRequiredFieldsFilled {
    BOOL ret = [super areAllRequiredFieldsFilled];
    
    // Check user login and pass fields
    ret = (ret && self.userLoginTextField.text.length && self.passWordTextField.text.length);
    return ret;
}

- (void)setAuthType:(MXKAuthenticationType)authType {
    if (authType == MXKAuthenticationTypeLogin) {
        self.passWordTextField.returnKeyType = UIReturnKeyDone;
        self.emailTextField.hidden = YES;
        self.emailInfoLabel.hidden = YES;
    } else {
        self.passWordTextField.returnKeyType = UIReturnKeyNext;
        self.emailTextField.hidden = NO;
        self.emailInfoLabel.hidden = NO;
    }
    super.authType = authType;
}

- (void)dismissKeyboard {
    [self.userLoginTextField resignFirstResponder];
    [self.passWordTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
    
    [super dismissKeyboard];
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
            [self.passWordTextField becomeFirstResponder];
        } else if (textField == self.passWordTextField) {
            [self.displayNameTextField becomeFirstResponder];
        } else if (textField == self.displayNameTextField) {
            [self.emailTextField becomeFirstResponder];
        }
    }
    
    return YES;
}
@end
