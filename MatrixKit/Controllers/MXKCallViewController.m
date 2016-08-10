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

#import "MXKCallViewController.h"

#import "MXKMediaManager.h"
#import "MXKAlert.h"

#import "NSBundle+MatrixKit.h"

#import "MXKTools.h"

NSString *const kMXKCallViewControllerWillAppearNotification = @"kMXKCallViewControllerWillAppearNotification";
NSString *const kMXKCallViewControllerAppearedNotification = @"kMXKCallViewControllerAppearedNotification";
NSString *const kMXKCallViewControllerWillDisappearNotification = @"kMXKCallViewControllerWillDisappearNotification";
NSString *const kMXKCallViewControllerDisappearedNotification = @"kMXKCallViewControllerDisappearedNotification";
NSString *const kMXKCallViewControllerBackToAppNotification = @"kMXKCallViewControllerBackToAppNotification";

@interface MXKCallViewController ()
{
    AVAudioPlayer *audioPlayer;
    
    NSTimer *vibrateTimer;
    NSTimer *hideOverlayTimer;
    NSTimer *updateStatusTimer;
    
    Boolean isMovingLocalPreview;
    Boolean isSelectingLocalPreview;
    
    CGPoint startNewLocalMove;

    /**
     The popup showed in case of call stack error.
     */
    MXKAlert *errorAlert;
}

@property (nonatomic) MXCall *mxCall;

@property (nonatomic) MXUser *peer;

@property (nonatomic, assign) Boolean isRinging;
@property (nonatomic, assign) Boolean isSpeakerPhone;
@property (nonatomic, assign) Boolean isMuted;

@end

@implementation MXKCallViewController
@synthesize backgroundImageView;
@synthesize localPreviewContainerView, localPreviewActivityView, remotePreviewContainerView;
@synthesize overlayContainerView, callContainerView, callerImageView, callerNameLabel, callStatusLabel;
@synthesize callToolBar, rejectCallButton, answerCallButton, endCallButton;
@synthesize callControlContainerView, speakerButton, muteButton;
@synthesize backToAppButton;
@synthesize backToAppStatusWindow;
@synthesize mxCall;

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKCallViewController class])
                          bundle:[NSBundle bundleForClass:[MXKCallViewController class]]];
}

+ (instancetype)callViewController:(MXCall*)call
{
    MXKCallViewController* instance = [[[self class] alloc] initWithNibName:NSStringFromClass([MXKCallViewController class])
                                                                     bundle:[NSBundle bundleForClass:[MXKCallViewController class]]];
    instance.mxCall = call;
    
    return instance;
}

#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Load peer info
    [self updatePeerInfoDisplay];
    
    updateStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeStatusLabel) userInfo:nil repeats:YES];
    
    // TODO: handle speaker and mute options
    speakerButton.hidden = YES;
    muteButton.hidden = YES;
    
    self.callerImageView.backgroundColor = [UIColor clearColor];
    self.backToAppButton.backgroundColor = [UIColor clearColor];
    self.muteButton.backgroundColor = [UIColor clearColor];
    self.speakerButton.backgroundColor = [UIColor clearColor];
    
    [self.backToAppButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_backtoapp"] forState:UIControlStateNormal];
    [self.backToAppButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_backtoapp"] forState:UIControlStateHighlighted];
    [self.muteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_mute"] forState:UIControlStateNormal];
    [self.muteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_mute"] forState:UIControlStateSelected];
    [self.speakerButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_speaker"] forState:UIControlStateNormal];
    [self.speakerButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_speaker"] forState:UIControlStateSelected];
    
    // Localize string
    [answerCallButton setTitle:[NSBundle mxk_localizedStringForKey:@"answer_call"] forState:UIControlStateNormal];
    [answerCallButton setTitle:[NSBundle mxk_localizedStringForKey:@"answer_call"] forState:UIControlStateHighlighted];
    [rejectCallButton setTitle:[NSBundle mxk_localizedStringForKey:@"reject_call"] forState:UIControlStateNormal];
    [rejectCallButton setTitle:[NSBundle mxk_localizedStringForKey:@"reject_call"] forState:UIControlStateHighlighted];
    [endCallButton setTitle:[NSBundle mxk_localizedStringForKey:@"end_call"] forState:UIControlStateNormal];
    [endCallButton setTitle:[NSBundle mxk_localizedStringForKey:@"end_call"] forState:UIControlStateHighlighted];
    
    // Refresh call information
    self.mxCall = mxCall;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerWillAppearNotification object:nil];
    
    [self showOverlayContainer:YES];
    
    if (mxCall)
    {
        // Refresh call status
        [self call:mxCall stateDidChange:mxCall.state reason:nil];
    }
    
    if (_delegate)
    {
        backToAppButton.hidden = NO;
    }
    else
    {
        backToAppButton.hidden = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerAppearedNotification object:nil];
    
    // trick to hide the volume at launch
    // as the mininum volume is forced by the application
    // the volume popup can be displayed
    //    volumeView = [[MPVolumeView alloc] initWithFrame: CGRectMake(5000, 5000, 0, 0)];
    //    [self.view addSubview: volumeView];
    //
    //    dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    //        [volumeView removeFromSuperview];
    //    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerWillDisappearNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerDisappearedNotification object:nil];
}

- (void)dismiss
{
    if (_delegate)
    {
        [_delegate dismissCallViewController:self];
    }
    else
    {
        // Auto dismiss after few seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }
}

#pragma mark - override MXKViewController

- (void)destroy
{
    self.peer = nil;
    
    self.mxCall = nil;
    
    _delegate = nil;
    
    self.isRinging = NO;
    audioPlayer = nil;
    
    [hideOverlayTimer invalidate];
    [updateStatusTimer invalidate];
    
    [super destroy];
}

#pragma mark - Properties

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setMxCall:(MXCall *)call
{
    // Remove previous call (if any)
    if (mxCall)
    {
        mxCall.delegate = nil;
        mxCall.selfVideoView = nil;
        mxCall.remoteVideoView = nil;
        [self removeMatrixSession:self.mainSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
    
    
    if (call && call.room)
    {
        MXSession *mxSession = mxCall.room.mxSession;
        
        [self addMatrixSession:mxSession];
        
        // Handle peer here
        if (call.isIncoming)
        {
            self.peer = [mxSession userWithUserId:call.callerId];
        }
        else
        {
            // For 1:1 call, find the other peer
            // Else, the room information will be used to display information about the call
            NSArray *members = call.room.state.members;
            if (members.count == 2)
            {
                for (MXUser *member in members)
                {
                    if (![member.userId isEqualToString:call.callerId])
                    {
                        self.peer = member;
                        break;
                    }
                }
            }

            [self updatePeerInfoDisplay];
        }
        
        // Observe call state change
        call.delegate = self;
        [self call:call stateDidChange:call.state reason:nil];
        
        if (call.isVideoCall)
        {
            // Access to the camera is mandatory to display the self view
            // Check the permission right now
            NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
            [MXKTools checkAccessForMediaType:AVMediaTypeVideo
                          manualChangeMessage:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"camera_access_not_granted_for_call"], appDisplayName]

                    showPopUpInViewController:self completionHandler:^(BOOL granted) {

                   if (granted)
                   {
                       localPreviewContainerView.hidden = NO;
                       remotePreviewContainerView.hidden = NO;

                       call.selfVideoView = localPreviewContainerView;
                       call.remoteVideoView = remotePreviewContainerView;
                       [self applyDeviceOrientation:YES];

                       [[NSNotificationCenter defaultCenter] addObserver:self
                                                                selector:@selector(deviceOrientationDidChange)
                                                                    name:UIDeviceOrientationDidChangeNotification
                                                                  object:nil];
                   }
               }];
        }
        else
        {
            localPreviewContainerView.hidden = YES;
            remotePreviewContainerView.hidden = YES;
        }
    }
    
    mxCall = call;
}

- (void)updatePeerInfoDisplay
{
    NSString *peerDisplayName;
    NSString *peerAvatarURL;

    if (_peer)
    {
        peerDisplayName = [_peer displayname];
        if (!peerDisplayName.length)
        {
            peerDisplayName = _peer.userId;
        }

        // TODO add observer on this user to be able update his display name and avatar.
    }
    else if (mxCall.isConferenceCall)
    {
        peerDisplayName = mxCall.room.state.displayname;
        peerAvatarURL = mxCall.room.state.avatar;

        // TODO add observer on this room to be able update its display name and avatar.
    }

    callerNameLabel.text = peerDisplayName;
    if (peerAvatarURL)
    {
        // Suppose avatar url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        NSString *avatarThumbURL = [self.mainSession.matrixRestClient urlOfContentThumbnail:peerAvatarURL toFitViewSize:callerImageView.frame.size withMethod:MXThumbnailingMethodCrop];
        callerImageView.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
        callerImageView.enableInMemoryCache = YES;
        [callerImageView setImageURL:avatarThumbURL withType:nil andImageOrientation:UIImageOrientationUp previewImage:self.picturePlaceholder];
        [callerImageView.layer setCornerRadius:callerImageView.frame.size.width / 2];
        callerImageView.clipsToBounds = YES;
    }
    else
    {
        callerImageView.image = self.picturePlaceholder;
    }
}

- (void)setIsRinging:(Boolean)isRinging
{
    if (_isRinging != isRinging)
    {
        
        if (isRinging)
        {
            if (audioPlayer)
            {
                [audioPlayer stop];
            }
            
            NSError* error = nil;
            NSURL *audioUrl;
            if (mxCall.isIncoming)
            {
                audioUrl = [NSBundle mxk_audioURLFromMXKAssetsBundleWithName:@"ring"];
            }
            else
            {
                audioUrl = [NSBundle mxk_audioURLFromMXKAssetsBundleWithName:@"ringback"];
            }
            
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioUrl error:&error];
            
            if (error)
            {
                NSLog(@"[MXKCallVC] ringing initWithContentsOfURL failed : %@", error);
            }
            
            audioPlayer.numberOfLoops = -1;
            [audioPlayer play];
            
            vibrateTimer = [NSTimer scheduledTimerWithTimeInterval:1.24875 target:self selector:@selector(vibrate) userInfo:nil repeats:YES];
        }
        else
        {
            if (audioPlayer)
            {
                [audioPlayer stop];
                audioPlayer = nil;
            }
            [vibrateTimer invalidate];
            vibrateTimer = nil;
        }
        
        _isRinging = isRinging;
    }
}

- (void)setDelegate:(id<MXKCallViewControllerDelegate>)delegate
{
    _delegate = delegate;
    
    if (_delegate)
    {
        backToAppButton.hidden = NO;
    }
    else
    {
        backToAppButton.hidden = YES;
    }
}

#pragma mark - Actions

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == answerCallButton)
    {
        // If we are here, we have access to the camera
        // The following check is mainly to check microphone access permission
        NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];

        [MXKTools checkAccessForCall:mxCall.isVideoCall
         manualChangeMessageForAudio:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"microphone_access_not_granted_for_call"], appDisplayName]
         manualChangeMessageForVideo:[NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"camera_access_not_granted_for_call"], appDisplayName]
           showPopUpInViewController:self completionHandler:^(BOOL granted) {

               if (granted)
               {
                   [mxCall answer];
               }
           }];
    }
    else if (sender == rejectCallButton || sender == endCallButton)
    {
        if (mxCall.state != MXCallStateEnded)
        {
            [mxCall hangup];
        }
        else
        {
            [self dismiss];
        }
    }
    else if (sender == muteButton)
    {
        mxCall.audioMuted = !mxCall.audioMuted;
    }
    else if (sender == speakerButton)
    {
        // TODO
    }
    else if (sender == backToAppButton)
    {
        if (_delegate)
        {
            // Dismiss the view controller whereas the call is still running
            [_delegate dismissCallViewController:self];
        }
    }
}

#pragma mark - MXCallDelegate

- (void)call:(MXCall *)call stateDidChange:(MXCallState)state reason:(MXEvent *)event
{
    // Set default configuration of bottom bar
    endCallButton.hidden = NO;
    rejectCallButton.hidden = YES;
    answerCallButton.hidden = YES;
    
    [localPreviewActivityView stopAnimating];
    
    switch (state)
    {
        case MXCallStateFledgling:
            self.isRinging = NO;
            callStatusLabel.text = nil;
            break;
        case MXCallStateWaitLocalMedia:
            self.isRinging = NO;
            [localPreviewActivityView startAnimating];
            break;
        case MXCallStateCreateOffer:
        case MXCallStateInviteSent:
            self.isRinging = YES;
            callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"call_ring"];
            break;
        case MXCallStateRinging:
            self.isRinging = YES;
            if (call.isVideoCall)
            {
                callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"incoming_video_call"];
            }
            else
            {
                callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"incoming_voice_call"];
            }
            // Update bottom bar
            endCallButton.hidden = YES;
            rejectCallButton.hidden = NO;
            answerCallButton.hidden = NO;
            break;
        case MXCallStateCreateAnswer:
        case MXCallStateConnecting:
            self.isRinging = NO;
            callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"call_connecting"];
            break;
        case MXCallStateConnected:
            self.isRinging = NO;
            [self updateTimeStatusLabel];

            if (call.isVideoCall && call.isConferenceCall)
            {
                // Do not show self view anymore because it is returned by the conference bridge
                self.localPreviewContainerView.hidden = YES;

                // Well, hide does not work. So, shrink the view to nil
                self.localPreviewContainerView.frame = CGRectMake(0, 0, 0, 0);
            }
            break;
        case MXCallStateInviteExpired:
            // MXCallStateInviteExpired state is sent as an notification
            // MXCall will move quickly to the MXCallStateEnded state
            self.isRinging = NO;
            callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"call_invite_expired"];
            break;
        case MXCallStateEnded:
        {
            self.isRinging = NO;
            callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"call_ended"];
            
            if (audioPlayer)
            {
                [audioPlayer stop];
            }
            
            NSError* error = nil;
            NSURL *audioUrl;
            audioUrl = [NSBundle mxk_audioURLFromMXKAssetsBundleWithName:@"callend"];
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioUrl error:&error];
            if (error)
            {
                NSLog(@"[MXKCallVC] ringing initWithContentsOfURL failed : %@", error);
            }

            // Listen (audioPlayerDidFinishPlaying) for the end of the playback of "callend"
            // to release the audio session
            audioPlayer.delegate = self;

            audioPlayer.numberOfLoops = 0;
            [audioPlayer play];

            // Except in case of call error, quit the screen right now
            if (!errorAlert)
            {
                [self dismiss];
            }

            break;
        }
        default:
            break;
    }
}

- (void)call:(MXCall *)call didEncounterError:(NSError *)error
{
    NSLog(@"[MXKCallViewController] didEncounterError. mxCall.state: %tu. Stop call due to error: %@", mxCall.state, error);

    if (mxCall.state != MXCallStateEnded)
    {
        // Popup the error to the user
        NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
        if (!title)
        {
            title = [NSBundle mxk_localizedStringForKey:@"error"];
        }
        NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];

        __weak typeof(self) weakSelf = self;
        errorAlert = [[MXKAlert alloc] initWithTitle:title message:msg style:MXKAlertStyleAlert];
        errorAlert.cancelButtonIndex = [errorAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                style:MXKAlertActionStyleDefault
                                                              handler:^(MXKAlert *alert)
                                        {
                                            errorAlert = nil;
                                            [weakSelf dismiss];
                                        }];
        [errorAlert showInViewController:self];
        
        // And interrupt the call
        [mxCall hangup];
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // Release the audio session to allow resuming of background music app
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

#pragma mark - Internal

- (void)vibrate
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

#pragma mark - UI methods

- (void)showOverlayContainer:(BOOL)isShown
{
    if (mxCall && !mxCall.isVideoCall) isShown = YES;
    if (mxCall.state != MXCallStateConnected) isShown = YES;
    
    if (isShown)
    {
        overlayContainerView.hidden = NO;
        if (mxCall && mxCall.isVideoCall)
        {
            [hideOverlayTimer invalidate];
            hideOverlayTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(hideOverlay:) userInfo:nil repeats:NO];
        }
    }
    else
    {
        overlayContainerView.hidden = YES;
    }
}

- (void)toggleOverlay
{
    [self showOverlayContainer:overlayContainerView.isHidden];
}

- (void)hideOverlay:(NSTimer*)theTimer
{
    [self showOverlayContainer:NO];
    hideOverlayTimer = nil;
}

- (void)updateTimeStatusLabel
{
    if (mxCall.state == MXCallStateConnected)
    {
        NSUInteger duration = mxCall.duration / 1000;
        NSUInteger secs = duration % 60;
        NSUInteger mins = (duration - secs) / 60;
        callStatusLabel.text = [NSString stringWithFormat:@"%02tu:%02tu", mins, secs];
    }
}

#pragma mark - UIResponder Touch Events

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    if ((!self.localPreviewContainerView.hidden) && CGRectContainsPoint(self.localPreviewContainerView.frame, point))
        
    {
        // Starting to move the local preview view
        isSelectingLocalPreview = YES;
    }
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
    isMovingLocalPreview = NO;
    isSelectingLocalPreview = NO;
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    CGPoint lastPoint = [touch previousLocationInView:self.view];
    if (isMovingLocalPreview)
    {
        CGRect bounds = self.view.bounds;
        CGFloat midX = bounds.size.width / 2.0;
        CGFloat midY = bounds.size.height / 2.0;
        
        CGRect frame = self.localPreviewContainerView.frame;
        
        CGFloat dx = (point.x-lastPoint.x);
        CGFloat dy = (point.y-lastPoint.y);
        if ((dx*dx + dy*dy) > 60.0)
        {
            frame.origin.x = (dx < 0.0) ? 20.0 : (bounds.size.width - frame.size.width - 20.0);
            frame.origin.y = (dy < 0.0) ? 20.0 : (bounds.size.height - frame.size.height - 20.0);
        }
        else
        {
            frame.origin.x = (point.x < midX) ? 20.0 : (bounds.size.width - frame.size.width - 20.0);
            frame.origin.y = (point.y < midY) ? 20.0 : (bounds.size.height - frame.size.height - 20.0);
        }
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.2];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        self.localPreviewContainerView.frame = frame;
        [UIView commitAnimations];
    }
    else
    {
        [self toggleOverlay];
    }
    isMovingLocalPreview = NO;
    isSelectingLocalPreview = NO;
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    
    if (isSelectingLocalPreview)
    {
        isMovingLocalPreview = YES;
        self.localPreviewContainerView.center = point;
    }
}

#pragma mark - UIDeviceOrientationDidChangeNotification

- (void)deviceOrientationDidChange
{
    [self applyDeviceOrientation:NO];
}

- (void)applyDeviceOrientation:(BOOL)forcePortrait
{
    if (mxCall)
    {
        UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
        
        // Set the camera orientation according to the orientation supported by the app
        if (UIDeviceOrientationPortrait == deviceOrientation || UIDeviceOrientationLandscapeLeft == deviceOrientation || UIDeviceOrientationLandscapeRight == deviceOrientation)
        {
            mxCall.selfOrientation = deviceOrientation;
        }
        else if (forcePortrait)
        {
            mxCall.selfOrientation = UIDeviceOrientationPortrait;
        }

        // Rotate the self view so that it shows the user like in a mirror
        // The translation is required in landscape because else the self video view
        // goes out of the screen
        float selfVideoRotation = 0;
        float translation = 0;
        switch (mxCall.selfOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                selfVideoRotation = M_PI/2;
                translation = -20;
                break;
            case UIInterfaceOrientationLandscapeRight:
                selfVideoRotation = -M_PI/2;
                translation = 20;
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                selfVideoRotation = M_PI;
                break;
            default:
                break;
        }

        if (!forcePortrait) {
            [UIView animateWithDuration:.3
                             animations:^{
                                 CGAffineTransform transform = CGAffineTransformMakeRotation(selfVideoRotation);
                                 transform = CGAffineTransformTranslate(transform, 0, translation);
                                 mxCall.selfVideoView.transform = transform;
                             }];
        }
    }
}

@end
