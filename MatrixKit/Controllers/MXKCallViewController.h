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
#import <AVFoundation/AVFoundation.h>

#import <MatrixSDK/MatrixSDK.h>

#import "MXKViewController.h"

#import "MXKImageView.h"

@class MXKCallViewController;

/**
 Delegate for `MXKCallViewController` object
 */
@protocol MXKCallViewControllerDelegate <NSObject>

/**
 Tells the delegate to dismiss the call view controller.
 This callback is called when the user wants to go back into the app during a call or when the call is ended.
 The delegate should check the state of the associated call to know the actual reason.
 
 @param callViewController the call view controller.
 @param completion the block to execute at the end of the operation.
 */
- (void)dismissCallViewController:(MXKCallViewController *)callViewController completion:(void (^)())completion;

@end

extern NSString *const kMXKCallViewControllerWillAppearNotification;
extern NSString *const kMXKCallViewControllerAppearedNotification;
extern NSString *const kMXKCallViewControllerWillDisappearNotification;
extern NSString *const kMXKCallViewControllerDisappearedNotification;
extern NSString *const kMXKCallViewControllerBackToAppNotification;

/**
 'MXKCallViewController' instance displays a call. Only one matrix session is supported by this view controller.
 */
@interface MXKCallViewController : MXKViewController <MXCallDelegate, AVAudioPlayerDelegate>

@property (weak, nonatomic) IBOutlet MXKImageView *backgroundImageView;

@property (weak, nonatomic, readonly) IBOutlet UIView *localPreviewContainerView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *localPreviewActivityView;

@property (weak, nonatomic, readonly) IBOutlet UIView *remotePreviewContainerView;

@property (weak, nonatomic) IBOutlet UIView *overlayContainerView;
@property (weak, nonatomic) IBOutlet UIView *callContainerView;
@property (weak, nonatomic) IBOutlet MXKImageView *callerImageView;
@property (weak, nonatomic) IBOutlet UILabel *callerNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *callStatusLabel;

@property (weak, nonatomic) IBOutlet UIView *callToolBar;
@property (weak, nonatomic) IBOutlet UIButton *rejectCallButton;
@property (weak, nonatomic) IBOutlet UIButton *answerCallButton;
@property (weak, nonatomic) IBOutlet UIButton *endCallButton;

@property (weak, nonatomic) IBOutlet UIView *callControlContainerView;
@property (weak, nonatomic) IBOutlet UIButton *speakerButton;
@property (weak, nonatomic) IBOutlet UIButton *audioMuteButton;
@property (weak, nonatomic) IBOutlet UIButton *videoMuteButton;

@property (weak, nonatomic) IBOutlet UIButton *backToAppButton;
@property (weak, nonatomic) IBOutlet UIButton *cameraSwitchButton;

@property (unsafe_unretained, nonatomic) IBOutlet NSLayoutConstraint *localPreviewContainerViewLeadingConstraint;
@property (unsafe_unretained, nonatomic) IBOutlet NSLayoutConstraint *localPreviewContainerViewTopConstraint;
@property (unsafe_unretained, nonatomic) IBOutlet NSLayoutConstraint *localPreviewContainerViewHeightConstraint;
@property (unsafe_unretained, nonatomic) IBOutlet NSLayoutConstraint *localPreviewContainerViewWidthConstraint;

/**
 The default picture displayed when no picture is available.
 */
@property (nonatomic) UIImage *picturePlaceholder;

/**
 The call status bar displayed on the top of the app during a call.
 */
@property (nonatomic, readonly) UIWindow *backToAppStatusWindow;

/**
 The current call
 */
@property (nonatomic) MXCall *mxCall;

/**
 The current peer
 */
@property (nonatomic, readonly) MXUser *peer;

/**
 The delegate.
 */
@property (nonatomic, weak) id<MXKCallViewControllerDelegate> delegate;

/*
 Specifies whether a ringtone must be played on incoming call.
 It's important to set this value before you will set `mxCall` otherwise value of this property can has no effect.
 
 Defaults to YES.
 */
@property (nonatomic) BOOL playRingtone;

#pragma mark - Class methods

/**
 Returns the `UINib` object initialized for a `MXKCallViewController`.
 
 @return The initialized `UINib` object or `nil` if there were errors during initialization
 or the nib file could not be located.
 
 @discussion You may override this method to provide a customized nib. If you do,
 you should also override `roomViewController` to return your
 view controller loaded from your custom nib.
 */
+ (UINib *)nib;

/**
 Creates and returns a new `MXKCallViewController` object.
 
 @discussion This is the designated initializer for programmatic instantiation.
 
 @param call a MXCall instance.
 @return An initialized `MXKRoomViewController` object if successful, `nil` otherwise.
 */
+ (instancetype)callViewController:(MXCall *)call;

/**
 Return an audio file url based on the provided name.
 
 @param soundName audio file name without extension.
 @return a NSURL instance.
 */
- (NSURL*)audioURLWithName:(NSString *)soundName;

/**
 Refresh the peer information in the call viewcontroller's view.
 */
- (void)updatePeerInfoDisplay;

/**
 Adjust the layout of the preview container.
 */
- (void)updateLocalPreviewLayout;

/**
 Show/Hide the overlay view.
 
 @param isShown tell whether the overlay is shown or not.
 */
- (void)showOverlayContainer:(BOOL)isShown;

/**
 Set up or teardown the promixity monitoring and enable/disable the idle timer according to call type, state & audio route.
 */
- (void)updateProximityAndSleep;

/**
 Action registered on the event 'UIControlEventTouchUpInside' for each UIButton instance.
 */
- (IBAction)onButtonPressed:(id)sender;

@end
