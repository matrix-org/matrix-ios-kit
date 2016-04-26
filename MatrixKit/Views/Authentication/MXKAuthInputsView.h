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

#import <MatrixSDK/MatrixSDK.h>

#import "MXKAlert.h"

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
/**
 Tells the delegate that a MXKAlert must be presented.
 
 @param authInputsView the authentication inputs view.
 @param alert the alert to present.
 */
- (void)authInputsView:(MXKAuthInputsView*)authInputsView presentMXKAlert:(MXKAlert*)alert;

/**
 For some input fields, the return key of the keyboard is defined as `Done` key.
 By this method, the delegate is notified when this key is pressed.
 */
- (void)authInputsViewDidPressDoneKey:(MXKAuthInputsView *)authInputsView;

@optional

/**
 The matrix REST Client used to validate potential email address.
 */
- (MXRestClient *)authInputsViewEmailValidationRestClient:(MXKAuthInputsView *)authInputsView;
@end

/**
 `MXKAuthInputsView` is a base class to handle authentication inputs.
 */
@interface MXKAuthInputsView : UIView <UITextFieldDelegate>
{
@protected
    /**
     The authentication type (`MXKAuthenticationTypeLogin` by default).
     */
    MXKAuthenticationType type;
    
    /**
     The authentication session (nil by default).
     */
    MXAuthenticationSession *currentSession;
    
    /**
     Alert used to display inputs error.
     */
    MXKAlert *inputsAlert;
}

/**
 The view delegate.
 */
@property (nonatomic) id <MXKAuthInputsViewDelegate> delegate;

/**
 The current authentication type (`MXKAuthenticationTypeLogin` by default).
 */
@property (nonatomic, readonly) MXKAuthenticationType authType;

/**
 The current authentication session if any.
 */
@property (nonatomic, readonly) MXAuthenticationSession *authSession;

/**
 The current filled user identifier (nil by default).
 */
@property (nonatomic, readonly) NSString *userId;

/**
 The current filled password (nil by default).
 */
@property (nonatomic, readonly) NSString *password;

/**
 The layout constraint defined on the view height. This height takes into account shown/hidden fields.
 */
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *viewHeightConstraint;

/**
 Returns the `UINib` object initialized for the auth inputs view.
 
 @return The initialized `UINib` object or `nil` if there were errors during
 initialization or the nib file could not be located.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKAuthInputsView` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 
 @return An initialized `MXKAuthInputsView` object if successful, `nil` otherwise.
 */
+ (instancetype)authInputsView;

/**
 Finalize the authentication inputs view with a session and a type.
 Use this method to restore the view in its initial step.
 
 @discussion You may override this method to check/update the flows listed in the provided authentication session.
 
 @param authSession the authentication session returned by the homeserver.
 @param authType the authentication type (see 'MXKAuthenticationType').
 @return YES if the provided session and type are supported by the MXKAuthInputsView-inherited class. Note the unsupported flows should be here removed from the stored authentication session (see the resulting session in the property named 'authSession').
 */
- (BOOL)setAuthSession:(MXAuthenticationSession *)authSession withAuthType:(MXKAuthenticationType)authType;

/**
 Check the validity of the required parameters.
 
 @return an error message in case of wrong parameters (nil by default).
 */
- (NSString*)validateParameters;

/**
 Prepare the set of the inputs in order to launch an authentication process.
 
 @param callback the block called when the parameters are prepared. The resulting parameter dictionary is nil
 if something fails (for example when a parameter or a required input is missing).
 */
- (void)prepareParameters:(void (^)(NSDictionary *parameters))callback;

/**
 Update the current authentication session by providing the list of successful stages.
 
 @param completedStages the list of stages the client has completed successfully. This is an array of MXLoginFlowType.
 @param callback the block called when the parameters have been updated for the next stage. The resulting parameter dictionary is nil
 if something fails (for example when a parameter or a required input is missing).
 */
- (void)updateAuthSessionWithCompletedStages:(NSArray *)completedStages didUpdateParameters:(void (^)(NSDictionary *parameters))callback;

/**
 Update the current authentication session by providing a set of registration parameters.
 
 @discussion This operation failed if the current authentication type is MXKAuthenticationTypeLogin.
 
 @param registrationParameters a set of parameters to use during the current registration process.
 @return YES if the provided set of parameters is supported.
 */
- (BOOL)setExternalRegistrationParameters:(NSDictionary *)registrationParameters;

/**
 Tell whether all required fields are set
 */
- (BOOL)areAllRequiredFieldsSet;

/**
 Tell whether the email field is empty while the email binding is supported.
 */
- (BOOL)shouldPromptUserForEmailAddress;

/**
 Force dismiss keyboard
 */
- (void)dismissKeyboard;

/**
 Switch in next authentication flow step by updating the layout.
 */
- (void)nextStep;

/**
 Dispose any resources and listener.
 */
- (void)destroy;

@end
