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
 Authentication type: register or login
 */
typedef enum {
    MXKAuthenticationTypeRegister,
    MXKAuthenticationTypeLogin
} MXKAuthenticationType;

@class MXKAuthInputsView;

/**
 `MXKAuthInputsView` delegate
 */
@protocol MXKAuthInputsViewDelegate <NSObject>
@optional
/**
 For some input fields, the return key of the keyboard is defined as `Done` key.
 By this method, the delegate is notified when this key is pressed. The set of inputs may be considered to
 process the current authentication step.
 */
- (void)authInputsDoneKeyHasBeenPressed:(MXKAuthInputsView *)mxkAuthInputsView;
@end

/**
 `MXKAuthInputsView` is a base class to handle authentication inputs.
 */
@interface MXKAuthInputsView : UIView <UITextFieldDelegate>

/**
 The authentication type (`MXKAuthenticationTypeLogin` by default).
 */
@property (nonatomic) MXKAuthenticationType authType;

/**
 The view delegate.
 */
@property (nonatomic) id <MXKAuthInputsViewDelegate> delegate;

/**
 The text field related to the display name (nil by default).
 This item is optional, it may be displayed in case of registration.
 */
@property (weak, nonatomic) UITextField *displayNameTextField;

/**
 *  Returns the `UINib` object initialized for the auth inputs view.
 *
 *  @return The initialized `UINib` object or `nil` if there were errors during
 *  initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 *  Creates and returns a new `MXKAuthInputsView` object.
 *
 *  @discussion This is the designated initializer for programmatic instantiation.
 *
 *  @return An initialized `MXKAuthInputsView` object if successful, `nil` otherwise.
 */
+ (instancetype)authInputsView;

/**
 The actual view height. This height takes into account shown/hidden fields.
 */
- (CGFloat)actualHeight;

/**
 YES when all required fields are filled.
 */
- (BOOL)areAllRequiredFieldsFilled;

/**
 Force dismiss keyboard
 */
- (void)dismissKeyboard;

/**
 Switch in next authentication flow step by updating the layout.
 */
- (void)nextStep;

/**
 Return in initial step of the authentication flow.
 */
- (void)resetStep;
@end
