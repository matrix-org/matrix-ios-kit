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
#import <MediaPlayer/MediaPlayer.h>

#import "MXKCallViewController.h"

#import "MXKMediaManager.h"

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
    self.peer = _peer;
    
    updateStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeStatusLabel) userInfo:nil repeats:YES];
    
    // TODO: handle speaker and mute options
    speakerButton.hidden = YES;
    muteButton.hidden = YES;
    
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
            // Only one-to-one room are supported.
            // TODO: Handle conference call
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
        }
        
        
        // Observe call state change
        call.delegate = self;
        [self call:call stateDidChange:call.state reason:nil];
        
        if (call.isVideoCall)
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
        else
        {
            localPreviewContainerView.hidden = YES;
            remotePreviewContainerView.hidden = YES;
        }
    }
    
    mxCall = call;
}

- (void)setPeer:(MXUser *)peer
{
    _peer = peer;
    
    if (peer)
    {
        // Display caller info
        callerNameLabel.text = [peer displayname];
        if (!callerNameLabel.text.length)
        {
            callerNameLabel.text = peer.userId;
        }
        
        // Suppose avatar url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        NSString *avatarThumbURL = [self.mainSession.matrixRestClient urlOfContentThumbnail:peer.avatarUrl toFitViewSize:callerImageView.frame.size withMethod:MXThumbnailingMethodCrop];
        callerImageView.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
        [callerImageView setImageURL:avatarThumbURL withImageOrientation:UIImageOrientationUp andPreviewImage:[UIImage imageNamed:@"default-profile"]];
        [callerImageView.layer setCornerRadius:callerImageView.frame.size.width / 2];
        callerImageView.clipsToBounds = YES;
        
        // TODO add observer on this user to be able update his display name and avatar.
    }
    else
    {
        callerNameLabel.text = nil;
        callerImageView.image = [UIImage imageNamed:@"default-profile"];
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
                audioUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"ring" ofType:@"mp3"]];
            }
            else
            {
                audioUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"ringback" ofType:@"mp3"]];
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
        [mxCall answer];
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
        // TODO
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
            callStatusLabel.text = @"Calling";
            break;
        case MXCallStateRinging:
            self.isRinging = YES;
            if (call.isVideoCall)
            {
                callStatusLabel.text = @"Incoming Video Call";
            }
            else
            {
                callStatusLabel.text = @"Incoming Voice Call";
            }
            // Update bottom bar
            endCallButton.hidden = YES;
            rejectCallButton.hidden = NO;
            answerCallButton.hidden = NO;
            break;
        case MXCallStateCreateAnswer:
        case MXCallStateConnecting:
            self.isRinging = NO;
            callStatusLabel.text = @"Call Connecting";
            break;
        case MXCallStateConnected:
            self.isRinging = NO;
            [self updateTimeStatusLabel];
            break;
        case MXCallStateInviteExpired:
            // MXCallStateInviteExpired state is sent as an notification
            // MXCall will move quickly to the MXCallStateEnded state
            self.isRinging = NO;
            callStatusLabel.text = @"Call Invite Expired";
            break;
        case MXCallStateEnded:
        {
            self.isRinging = NO;
            callStatusLabel.text = @"Call Ended";
            
            if (audioPlayer)
            {
                [audioPlayer stop];
            }
            
            NSError* error = nil;
            NSURL *audioUrl;
            audioUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"callend" ofType:@"mp3"]];
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioUrl error:&error];
            if (error)
            {
                NSLog(@"[MXKCallVC] ringing initWithContentsOfURL failed : %@", error);
            }
            
            audioPlayer.numberOfLoops = 0;
            [audioPlayer play];
            
            [self dismiss];
            
            break;
        }
        default:
            break;
    }
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
            mxCall.videoOrientation = deviceOrientation;
        }
        else if (forcePortrait)
        {
            mxCall.videoOrientation = UIDeviceOrientationPortrait;
        }
    }
}

@end
