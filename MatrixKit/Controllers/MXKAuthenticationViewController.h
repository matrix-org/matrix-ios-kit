/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
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

#import "MXKViewController.h"

#import "MXKAuthInputsView.h"
#import "MXKAuthenticationFallbackWebView.h"

@class MXKAuthenticationViewController;

/**
 `MXKAuthenticationViewController` delegate.
 */
@protocol MXKAuthenticationViewControllerDelegate <NSObject>

/**
 Tells the delegate the authentication process succeeded to add a new account.
 
 @param authenticationViewController the `MXKAuthenticationViewController` instance.
 @param userId the user id of the new added account.
 */
- (void)authenticationViewController:(MXKAuthenticationViewController *)authenticationViewController didLogWithUserId:(NSString*)userId;

@end

/**
 This view controller should be used to manage registration or login flows with matrix home server.
 
 Only the flow based on password is presently supported. Other flows should be added later.
 
 You may add a delegate to be notified when a new account has been added successfully.
 */
@interface MXKAuthenticationViewController : MXKViewController <UITextFieldDelegate, MXKAuthInputsViewDelegate>
{
@protected
    
    /**
     Reference to any opened alert view.
     */
    UIAlertController *alert;
    
    /**
     Tell whether the password has been reseted with success.
     Used to return on login screen on submit button pressed.
     */
    BOOL isPasswordReseted;
}

@property (weak, nonatomic) IBOutlet UIImageView *welcomeImageView;

@property (strong, nonatomic) IBOutlet UIScrollView *authenticationScrollView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *authScrollViewBottomConstraint;

@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentViewHeightConstraint;

@property (weak, nonatomic) IBOutlet UILabel *subTitleLabel;

@property (weak, nonatomic) IBOutlet UIView *authInputsContainerView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *authInputContainerViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *authInputContainerViewMinHeightConstraint;

@property (weak, nonatomic) IBOutlet UILabel *homeServerLabel;
@property (weak, nonatomic) IBOutlet UITextField *homeServerTextField;
@property (weak, nonatomic) IBOutlet UILabel *homeServerInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *identityServerLabel;
@property (weak, nonatomic) IBOutlet UITextField *identityServerTextField;
@property (weak, nonatomic) IBOutlet UILabel *identityServerInfoLabel;

@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UIButton *authSwitchButton;

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *authenticationActivityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *noFlowLabel;
@property (weak, nonatomic) IBOutlet UIButton *retryButton;

@property (weak, nonatomic) IBOutlet UIView *authFallbackContentView;
@property (weak, nonatomic) IBOutlet MXKAuthenticationFallbackWebView *authFallbackWebView;
@property (weak, nonatomic) IBOutlet UIButton *cancelAuthFallbackButton;

/**
 The current authentication type (MXKAuthenticationTypeLogin by default).
 */
@property (nonatomic) MXKAuthenticationType authType;

/**
 The view in which authentication inputs are displayed (`MXKAuthInputsView-inherited` instance).
 */
@property (nonatomic) MXKAuthInputsView *authInputsView;

/**
 The default home server url (nil by default).
 */
@property (nonatomic) NSString *defaultHomeServerUrl;

/**
 The default identity server url (nil by default).
 */
@property (nonatomic) NSString *defaultIdentityServerUrl;

/**
 Force a registration process based on a predefined set of parameters.
 Use this property to pursue a registration from the next_link sent in an email validation email.
 */
@property (nonatomic) NSDictionary* externalRegistrationParameters;

/**
 Enable/disable overall the user interaction option.
 It is used during authentication process to prevent multiple requests.
 */
@property(nonatomic,getter=isUserInteractionEnabled) BOOL userInteractionEnabled;

/**
 The delegate for the view controller.
 */
@property (nonatomic) id<MXKAuthenticationViewControllerDelegate> delegate;

/**
 Returns the `UINib` object initialized for a `MXKAuthenticationViewController`.
 
 @return The initialized `UINib` object or `nil` if there were errors during initialization
 or the nib file could not be located.
 
 @discussion You may override this method to provide a customized nib. If you do,
 you should also override `authenticationViewController` to return your
 view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKAuthenticationViewController` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 
 @return An initialized `MXKAuthenticationViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)authenticationViewController;

/**
 Register the MXKAuthInputsView class that will be used to display inputs for an authentication type.
 
 By default the 'MXKAuthInputsPasswordBasedView' class is registered for 'MXKAuthenticationTypeLogin' authentication.
 No class is registered for 'MXKAuthenticationTypeRegister' type.
 No class is registered for 'MXKAuthenticationTypeForgotPassword' type.
 
 @param authInputsViewClass a MXKAuthInputsView-inherited class.
 @param authType the concerned authentication type
 */
- (void)registerAuthInputsViewClass:(Class)authInputsViewClass forAuthType:(MXKAuthenticationType)authType;

/**
 Refresh login/register mechanism supported by the server and the application.
 */
- (void)refreshAuthenticationSession;

/**
 Handle supported flows and associated information returned by the home server.
 */
- (void)handleAuthenticationSession:(MXAuthenticationSession *)authSession;

/**
 Customize the MXHTTPClientOnUnrecognizedCertificate block that will be used to handle unrecognized certificate observed during authentication challenge from a server.
 By default we prompt the user by displaying a fingerprint (SHA256) of the certificate. The user is then able to trust or not the certificate.
 
 @param onUnrecognizedCertificateBlock the block that will be used to handle unrecognized certificate
 */
- (void)setOnUnrecognizedCertificateBlock:(MXHTTPClientOnUnrecognizedCertificate)onUnrecognizedCertificateBlock;

/**
 Check whether the current username is already in use.
 
 @param callback A block object called when the operation is completed.
 */
- (void)isUserNameInUse:(void (^)(BOOL isUserNameInUse))callback;

/**
 Action registered on the following events:
 - 'UIControlEventTouchUpInside' for each UIButton instance.
 - 'UIControlEventValueChanged' for each UISwitch instance.
 */
- (IBAction)onButtonPressed:(id)sender;

/**
 Set the home server url and force a new authentication session.
 The default home server url is used when the provided url is nil.
 
 @param homeServerUrl the home server url to use
 */
- (void)setHomeServerTextFieldText:(NSString *)homeServerUrl;

/**
 Set the identity server url.
 The default identity server url is used when the provided url is nil.
 
 @param identityServerUrl the identity server url to use
 */
- (void)setIdentityServerTextFieldText:(NSString *)identityServerUrl;

/**
 Force dismiss keyboard
 */
- (void)dismissKeyboard;

/**
 Cancel the current operation, and return to the initial step
 */
- (void)cancel;

/**
 Handle the error received during an authentication request.
 
 @param error the received error.
 */
- (void)onFailureDuringAuthRequest:(NSError *)error;

/**
 Handle the successful authentication request.
 
 @param credentials the user's credentials.
 */
- (void)onSuccessfulLogin:(MXCredentials*)credentials;

@end

