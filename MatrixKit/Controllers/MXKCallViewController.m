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

#import "MXMediaManager.h"
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
    
    // the room events listener
    id roomListener;
    
    // Observe kMXRoomDidFlushDataNotification to take into account the updated room members when the room history is flushed.
    id roomDidFlushDataNotificationObserver;
    
    // Observe AVAudioSessionRouteChangeNotification
    id audioSessionRouteChangeNotificationObserver;

    // Cache of the current audio session category
    NSString *savedAVAudioSessionCategory;
}

@property (nonatomic, assign) Boolean isRinging;

@end

@implementation MXKCallViewController
@synthesize backgroundImageView;
@synthesize localPreviewContainerView, localPreviewActivityView, remotePreviewContainerView;
@synthesize overlayContainerView, callContainerView, callerImageView, callerNameLabel, callStatusLabel;
@synthesize callToolBar, rejectCallButton, answerCallButton, endCallButton;
@synthesize callControlContainerView, speakerButton, audioMuteButton, videoMuteButton;
@synthesize backToAppButton, cameraSwitchButton;
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
    
    // Load the view controller's view now (buttons and views will then be available).
    if ([instance respondsToSelector:@selector(loadViewIfNeeded)])
    {
        // iOS 9 and later
        [instance loadViewIfNeeded];
    }
    else if (instance.view)
    {
        // Patch: on iOS < 9.0, we load the view by calling its getter.
    }
    
    instance.mxCall = call;
    
    return instance;
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    updateStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeStatusLabel) userInfo:nil repeats:YES];
    
    self.callerImageView.backgroundColor = [UIColor clearColor];
    self.backToAppButton.backgroundColor = [UIColor clearColor];
    self.audioMuteButton.backgroundColor = [UIColor clearColor];
    self.videoMuteButton.backgroundColor = [UIColor clearColor];
    self.speakerButton.backgroundColor = [UIColor clearColor];
    
    [self.backToAppButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_backtoapp"] forState:UIControlStateNormal];
    [self.backToAppButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_backtoapp"] forState:UIControlStateHighlighted];
    [self.audioMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_audio_unmute"] forState:UIControlStateNormal];
    [self.audioMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_audio_mute"] forState:UIControlStateSelected];
    [self.videoMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_video_unmute"] forState:UIControlStateNormal];
    [self.videoMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_video_mute"] forState:UIControlStateSelected];
    [self.speakerButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_speaker_off"] forState:UIControlStateNormal];
    [self.speakerButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_speaker_on"] forState:UIControlStateSelected];
    
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
    
    [self updateLocalPreviewLayout];
    [self showOverlayContainer:YES];
    
    if (mxCall)
    {
        // Refresh call display according to the call room state.
        [self callRoomStateDidChange];
        
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
        [_delegate dismissCallViewController:self completion:nil];
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
        
        [self removeObservers];
        
        mxCall = nil;
    }
    
    if (call && call.room)
    {
        mxCall = call;
        
        [self addMatrixSession:mxCall.room.mxSession];
        
        // Register a listener to handle messages related to room name, members...
        roomListener = [mxCall.room.liveTimeline listenToEventsOfTypes:@[kMXEventTypeStringRoomName, kMXEventTypeStringRoomTopic, kMXEventTypeStringRoomAliases, kMXEventTypeStringRoomAvatar, kMXEventTypeStringRoomCanonicalAlias, kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            
            // Consider only live events
            if (mxCall && direction == MXTimelineDirectionForwards)
            {
                // The room state has been changed
                [self callRoomStateDidChange];
            }
            
        }];
        
        // Observe room history flush (sync with limited timeline, or state event redaction)
        roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            MXRoom *room = notif.object;
            if (mxCall && self.mainSession == room.mxSession && [mxCall.room.state.roomId isEqualToString:room.state.roomId])
            {
                // The existing room history has been flushed during server sync.
                // Take into account the updated room state
                [self callRoomStateDidChange];
            }
            
        }];
        
        audioSessionRouteChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            [self updateProximityAndSleep];
            
        }];
        
        // Display room call information
        [self callRoomStateDidChange];
        
        // Hide video mute on voice call
        self.videoMuteButton.hidden = !call.isVideoCall;
        
        // Hide camera switch on voice call
        self.cameraSwitchButton.hidden = !call.isVideoCall;
        
        // Observe call state change
        call.delegate = self;
        [self call:call stateDidChange:call.state reason:nil];
        
        if (call.isVideoCall && localPreviewContainerView)
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
}

- (void)setPeer:(MXUser *)peer
{
    _peer = peer;
    
    [self updatePeerInfoDisplay];
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
        peerAvatarURL = _peer.avatarUrl;
    }
    else if (mxCall.isConferenceCall)
    {
        peerDisplayName = mxCall.room.state.displayname;
        peerAvatarURL = mxCall.room.state.avatar;
    }
    
    callerNameLabel.text = peerDisplayName;
    if (peerAvatarURL)
    {
        // Suppose avatar url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        NSString *avatarThumbURL = [self.mainSession.matrixRestClient urlOfContentThumbnail:peerAvatarURL toFitViewSize:callerImageView.frame.size withMethod:MXThumbnailingMethodCrop];
        callerImageView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        callerImageView.enableInMemoryCache = YES;
        [callerImageView setImageURL:avatarThumbURL withType:nil andImageOrientation:UIImageOrientationUp previewImage:self.picturePlaceholder];
    }
    else
    {
        callerImageView.image = self.picturePlaceholder;
    }
    
    // Round caller image view
    [callerImageView.layer setCornerRadius:callerImageView.frame.size.width / 2];
    callerImageView.clipsToBounds = YES;
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

            // Make the ringback ringing even in silent mode
            if (!savedAVAudioSessionCategory)
            {
                savedAVAudioSessionCategory = [[AVAudioSession sharedInstance] category];
            }
            
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
            
            NSError* error = nil;
            NSURL *audioUrl;
            if (mxCall.isIncoming)
            {
                audioUrl = [self audioURLWithName:@"ring"];
                
                // Vibrate on incoming call
                vibrateTimer = [NSTimer scheduledTimerWithTimeInterval:1.24875 target:self selector:@selector(vibrate) userInfo:nil repeats:YES];
            }
            else
            {
                audioUrl = [self audioURLWithName:@"ringback"];
            }
            
            audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioUrl error:&error];
            
            if (error)
            {
                NSLog(@"[MXKCallVC] ringing initWithContentsOfURL failed : %@", error);
            }
            
            audioPlayer.numberOfLoops = -1;
            [audioPlayer play];
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

#pragma mark - Sounds

- (NSURL*)audioURLWithName:(NSString*)soundName
{
    return [NSBundle mxk_audioURLFromMXKAssetsBundleWithName:soundName];
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
    else if (sender == audioMuteButton)
    {
        mxCall.audioMuted = !mxCall.audioMuted;
        audioMuteButton.selected = mxCall.audioMuted;
    }
    else if (sender == videoMuteButton)
    {
        mxCall.videoMuted = !mxCall.videoMuted;
        videoMuteButton.selected = mxCall.videoMuted;
    }
    else if (sender == speakerButton)
    {
        mxCall.audioToSpeaker = !mxCall.audioToSpeaker;
        speakerButton.selected = mxCall.audioToSpeaker;
    }
    else if (sender == cameraSwitchButton)
    {
        switch (mxCall.cameraPosition)
        {
            case AVCaptureDevicePositionFront:
                mxCall.cameraPosition = AVCaptureDevicePositionBack;
                break;
                
            default:
                mxCall.cameraPosition = AVCaptureDevicePositionFront;
                break;
        }
    }
    else if (sender == backToAppButton)
    {
        if (_delegate)
        {
            // Dismiss the view controller whereas the call is still running
            [_delegate dismissCallViewController:self completion:nil];
        }
    }
    
    [self updateProximityAndSleep];
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
            callStatusLabel.text = [NSBundle mxk_localizedStringForKey:@"call_waiting"];;
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
            
            // Check whether it is an actual state change or just a refresh
            if (event)
            {
                // Turn on speaker on connected video call (ONLY when the built-in receiver is currently used)
                call.audioToSpeaker = (call.isVideoCall && self.isBuiltInReceiverAudioOuput);
                speakerButton.selected = call.audioToSpeaker;
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
            
            NSString *soundName = [self soundNameForCallEnding];
            if (soundName)
            {
                NSError *error = nil;
                NSURL *audioUrl = [self audioURLWithName:soundName];
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
            }
            
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
    
    [self updateProximityAndSleep];
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

    // Restore audio category
    if (savedAVAudioSessionCategory)
    {
        [[AVAudioSession sharedInstance] setCategory:savedAVAudioSessionCategory error:nil];
        savedAVAudioSessionCategory = nil;
    }
}

#pragma mark - Internal

- (void)removeObservers
{
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    if (audioSessionRouteChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:audioSessionRouteChangeNotificationObserver];
        audioSessionRouteChangeNotificationObserver = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (roomListener && mxCall.room)
    {
        [mxCall.room.liveTimeline removeListener:roomListener];
        roomListener = nil;
    }
}

- (void)callRoomStateDidChange
{
    // Handle peer here
    if (mxCall.isIncoming)
    {
        self.peer = [mxCall.room.mxSession getOrCreateUser:mxCall.callerId];
    }
    else
    {
        // For 1:1 call, find the other peer
        // Else, the room information will be used to display information about the call
        MXUser *theMember = nil;
        if (!mxCall.isConferenceCall)
        {
            NSArray *members = mxCall.room.state.joinedMembers;
            for (MXUser *member in members)
            {
                if (![member.userId isEqualToString:mxCall.callerId])
                {
                    theMember = member;
                    break;
                }
            }
        }
        
        self.peer = theMember;
    }
}

- (void)vibrate
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (BOOL)isBuiltInReceiverAudioOuput
{
    BOOL isBuiltInReceiverUsed = NO;
    
    // Check whether the audio output is the built-in receiver
    AVAudioSessionRouteDescription *audioRoute= [[AVAudioSession sharedInstance] currentRoute];
    if (audioRoute.outputs.count)
    {
        // TODO: handle the case where multiple outputs are returned
        AVAudioSessionPortDescription *audioOutputs = audioRoute.outputs.firstObject;
        isBuiltInReceiverUsed = ([audioOutputs.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]);
    }
    
    return isBuiltInReceiverUsed;
}

- (NSString *)soundNameForCallEnding
{
    if (mxCall.endReason == MXCallEndReasonUnknown)
        return nil;
    
    if (mxCall.isEstablished)
        return @"callend";
    
    if (mxCall.endReason == MXCallEndReasonBusy || (!mxCall.isIncoming && mxCall.endReason == MXCallEndReasonMissed))
        return @"busy";
    
    return nil;
}

#pragma mark - UI methods

- (void)updateLocalPreviewLayout
{
    UIInterfaceOrientation screenOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    CGFloat maxPreviewFrameSize, minPreviewFrameSize;
    
    if (_localPreviewContainerViewWidthConstraint.constant < _localPreviewContainerViewHeightConstraint.constant)
    {
        maxPreviewFrameSize = _localPreviewContainerViewHeightConstraint.constant;
        minPreviewFrameSize = _localPreviewContainerViewWidthConstraint.constant;
    }
    else
    {
        minPreviewFrameSize = _localPreviewContainerViewHeightConstraint.constant;
        maxPreviewFrameSize = _localPreviewContainerViewWidthConstraint.constant;
    }
    
    if (UIInterfaceOrientationIsLandscape(screenOrientation))
    {
        _localPreviewContainerViewHeightConstraint.constant = minPreviewFrameSize;
        _localPreviewContainerViewWidthConstraint.constant = maxPreviewFrameSize;
    }
    else
    {
        _localPreviewContainerViewHeightConstraint.constant = maxPreviewFrameSize;
        _localPreviewContainerViewWidthConstraint.constant = minPreviewFrameSize;
    }
    
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
    CGPoint previewOrigin = self.localPreviewContainerView.frame.origin;
    
    if (previewOrigin.x != 20)
    {
        CGFloat posX = (bounds.size.width - _localPreviewContainerViewWidthConstraint.constant - 20.0);
        _localPreviewContainerViewLeadingConstraint.constant = posX;
    }
    
    if (previewOrigin.y != 20)
    {
        CGFloat posY = (bounds.size.height - _localPreviewContainerViewHeightConstraint.constant - 20.0);
        _localPreviewContainerViewTopConstraint.constant = posY;
    }
}

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

- (void)updateProximityAndSleep
{
    BOOL isBuiltInReceiverUsed = self.isBuiltInReceiverAudioOuput;
    
    BOOL inCall = (mxCall.state == MXCallStateConnected || mxCall.state == MXCallStateRinging || mxCall.state == MXCallStateInviteSent || mxCall.state == MXCallStateConnecting || mxCall.state == MXCallStateCreateOffer || mxCall.state == MXCallStateCreateAnswer);
    
    // Enable the proximity monitoring when the built in receiver is used as the audio output.
    BOOL enableProxMonitoring = inCall && isBuiltInReceiverUsed;
    [[UIDevice currentDevice] setProximityMonitoringEnabled:enableProxMonitoring];
    
    // Disable the idle timer during a video call, or during a voice call which is performed with the built-in receiver.
    // Note: if the device is locked, VoIP calling get dropped if an incoming GSM call is received.
    BOOL disableIdleTimer = inCall && (mxCall.isVideoCall || isBuiltInReceiverUsed);
    [UIApplication sharedApplication].idleTimerDisabled = disableIdleTimer;
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
    if (isMovingLocalPreview)
    {
        UITouch *touch = [touches anyObject];
        CGPoint point = [touch locationInView:self.view];
        
        CGRect bounds = self.view.bounds;
        CGFloat midX = bounds.size.width / 2.0;
        CGFloat midY = bounds.size.height / 2.0;
        
        CGFloat posX = (point.x < midX) ? 20.0 : (bounds.size.width - _localPreviewContainerViewWidthConstraint.constant - 20.0);
        CGFloat posY = (point.y < midY) ? 20.0 : (bounds.size.height - _localPreviewContainerViewHeightConstraint.constant - 20.0);
        
        _localPreviewContainerViewLeadingConstraint.constant = posX;
        _localPreviewContainerViewTopConstraint.constant = posY;
        
        [self.view setNeedsUpdateConstraints];
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
    
    [self showOverlayContainer:YES];
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
            [self updateLocalPreviewLayout];
        }
        else if (forcePortrait)
        {
            mxCall.selfOrientation = UIDeviceOrientationPortrait;
            [self updateLocalPreviewLayout];
        }        
    }
}

@end
