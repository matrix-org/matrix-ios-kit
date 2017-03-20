/*
 Copyright 2016 OpenMarket Ltd
 
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

#import "MXKAttachmentInteractionController.h"
#import "MXKAttachmentAnimator.h"

@interface MXKAttachmentInteractionController ()

@property (weak, atomic) UIViewController<MXKAttachmentAnimatorDelegate> *viewController;
@property (weak) UIImageView *originalImageViewReference;
@property CGRect originalImageViewConvertedFrame;

@property UIImageView *transitioningImageView;
@property id <UIViewControllerContextTransitioning> transitionContext;

@property CGPoint translation;
@property CGPoint delta;

@end

@implementation MXKAttachmentInteractionController

#pragma mark - Lifecycle

- (instancetype)initWithViewController:(UIViewController<MXKAttachmentAnimatorDelegate> *)viewController originalImageView:(UIImageView *)imageView convertedFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
        self.viewController = viewController;
        self.originalImageViewReference = imageView;
        self.originalImageViewConvertedFrame = frame;
        self.interactionInProgress = NO;
        
        [self preparePanGestureRecognizerInView:viewController.view];
    }
    return self;
}

#pragma mark - Gesture recognizer

- (void)preparePanGestureRecognizerInView:(UIView *)view
{
    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    recognizer.minimumNumberOfTouches = 1;
    recognizer.maximumNumberOfTouches = 3;
    [view addGestureRecognizer:recognizer];
}

- (void)handleGesture:(UIPanGestureRecognizer *)recognizer
{
    CGPoint translation = [recognizer translationInView:self.viewController.view];
    self.delta = CGPointMake(translation.x - self.translation.x, translation.y - self.translation.y);
    self.translation = translation;
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            
            self.interactionInProgress = YES;
            
            if (self.viewController.navigationController) {
                [self.viewController.navigationController popViewControllerAnimated:YES];
            } else {
                [self.viewController dismissViewControllerAnimated:YES completion:nil];
            }
            
            break;
            
        case UIGestureRecognizerStateChanged:
            
            [self updateInteractiveTransition:(ABS(translation.y) / (CGRectGetHeight(self.viewController.view.frame) / 2))];
            
            break;
            
        case UIGestureRecognizerStateCancelled:
            
            self.interactionInProgress = NO;
            [self cancelInteractiveTransition];
            
            break;
            
        case UIGestureRecognizerStateEnded:
            
            self.interactionInProgress = NO;
            if (ABS(self.translation.y) < CGRectGetHeight(self.viewController.view.frame)/6) {
                [self cancelInteractiveTransition];
            } else {
                [self finishInteractiveTransition];
            }
            
            break;
            
        default:
            NSLog(@"UIGestureRecognizerState not handled");
            break;
    }
}

#pragma mark - UIPercentDrivenInteractiveTransition

- (void)startInteractiveTransition:(id <UIViewControllerContextTransitioning>)transitionContext
{
    self.transitionContext = transitionContext;
    
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIImageView *destinationImageView = [self.viewController imageViewForAnimations];
    destinationImageView.hidden = YES;

    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    toViewController.view.frame = [transitionContext finalFrameForViewController:toViewController];
    [[transitionContext containerView] insertSubview:toViewController.view belowSubview:fromViewController.view];
    self.originalImageViewReference.hidden = YES;
    
    if (self.viewController.navigationController) {
        [self.viewController.navigationController setNavigationBarHidden:YES animated:NO];
    }

    self.transitioningImageView = [[UIImageView alloc] initWithImage:destinationImageView.image];
    self.transitioningImageView.frame = [MXKAttachmentAnimator aspectFitImage:destinationImageView.image inFrame:destinationImageView.frame];
    [[transitionContext containerView] addSubview:self.transitioningImageView];
}

- (void)updateInteractiveTransition:(CGFloat)percentComplete {
    self.viewController.view.alpha = MAX(0, (1 - percentComplete));
    
    CGRect newFrame = CGRectMake(self.transitioningImageView.frame.origin.x, self.transitioningImageView.frame.origin.y + self.delta.y, CGRectGetWidth(self.transitioningImageView.frame), CGRectGetHeight(self.transitioningImageView.frame));
    self.transitioningImageView.frame = newFrame;
}

- (void)cancelInteractiveTransition {
    UIViewController *fromViewController = [self.transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIImageView *destinationImageView = [self.viewController imageViewForAnimations];
    
    [UIView animateWithDuration:([self transitionDuration:self.transitionContext]/2) animations:^{
        fromViewController.view.alpha = 1;
        self.transitioningImageView.frame = [MXKAttachmentAnimator aspectFitImage:destinationImageView.image inFrame:destinationImageView.frame];
    } completion:^(BOOL finished) {
        destinationImageView.hidden = NO;
        self.originalImageViewReference.hidden = NO;
        [self.transitioningImageView removeFromSuperview];
        
        [self.transitionContext cancelInteractiveTransition];
        [self.transitionContext completeTransition:NO];
    }];
}

- (void)finishInteractiveTransition
{
    UIViewController *fromViewController = [self.transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIImageView *destinationImageView = [self.viewController imageViewForAnimations];
    
    UIViewController *toViewController = [self.transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    
    [UIView animateWithDuration:[self transitionDuration:self.transitionContext] animations:^{
        fromViewController.view.alpha = 0.0;
        self.transitioningImageView.frame = self.originalImageViewConvertedFrame;
    } completion:^(BOOL finished) {
        [self.transitioningImageView removeFromSuperview];
        destinationImageView.hidden = NO;
        self.originalImageViewReference.hidden = NO;
        if (toViewController.navigationController) {
            [toViewController.navigationController setNavigationBarHidden:NO animated:YES];
        }
        
        [self.transitionContext finishInteractiveTransition];
        [self.transitionContext completeTransition:YES];
    }];
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.3;
}


@end
