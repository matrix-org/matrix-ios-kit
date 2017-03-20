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

#import "MXKAttachmentAnimator.h"

@interface MXKAttachmentAnimator ()

@property PhotoBrowserAnimationType animationType;
@property UIImageView *originalImageView;
@property CGRect convertedFrame;

@end

@implementation MXKAttachmentAnimator

#pragma mark - Lifecycle

- (instancetype)initWithAnimationType:(PhotoBrowserAnimationType)animationType originalImageView:(UIImageView *)originalImageView convertedFrame:(CGRect)frame
{
    self = [self init];
    if (self) {
        self.animationType = animationType;
        self.originalImageView = originalImageView;
        self.convertedFrame = frame;
    }
    return self;
}

#pragma mark - Public

+ (CGRect)aspectFitImage:(UIImage *)image inFrame:(CGRect)targetFrame
{
    if (CGSizeEqualToSize(image.size, targetFrame.size)) {
        return targetFrame;
    }
    CGFloat targetWidth = CGRectGetWidth(targetFrame);
    CGFloat targetHeight = CGRectGetHeight(targetFrame);
    CGFloat imageWidth = image.size.width;
    CGFloat imageHeight = image.size.height;
    
    CGFloat factor = MIN(targetWidth/imageWidth, targetHeight/imageHeight);
    
    CGSize finalSize = CGSizeMake(imageWidth * factor, imageHeight * factor);
    CGRect finalFrame = CGRectMake((targetWidth - finalSize.width)/2 + 0, (targetHeight - finalSize.height)/2 + targetFrame.origin.y, finalSize.width, finalSize.height);
    
    return finalFrame;
}

#pragma mark - Animations

- (void)animateZoomInAnimation:(id<UIViewControllerContextTransitioning>)transitionContext
{
    self.originalImageView.hidden = YES;
    
    //toViewController
    UIViewController<MXKAttachmentAnimatorDelegate> *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    toViewController.view.frame = [transitionContext finalFrameForViewController:toViewController];
    [[transitionContext containerView] addSubview:toViewController.view];
    toViewController.view.alpha = 0.0;
    
    if ([toViewController conformsToProtocol:@protocol(MXKAttachmentAnimatorDelegate)]) {
        NSLog(@"conforms");
    } else {
        NSLog(@"doesnt conform");
    }
    
    UIImageView *destinationImageView = [toViewController imageViewForAnimations];
    destinationImageView.hidden = YES;
    
    //transitioningImageView
    UIImageView *transitioningImageView = [[UIImageView alloc] initWithImage:self.originalImageView.image];
    transitioningImageView.frame = self.convertedFrame;
    [[transitionContext containerView] addSubview:transitioningImageView];
    CGRect finalFrameForTransitioningView = [[self class] aspectFitImage:self.originalImageView.image inFrame:toViewController.view.frame];
    
    
    //animation
    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        toViewController.view.alpha = 1.0;
        transitioningImageView.frame = finalFrameForTransitioningView;
    } completion:^(BOOL finished) {
        [transitioningImageView removeFromSuperview];
        destinationImageView.hidden = NO;
        self.originalImageView.hidden = NO;
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

- (void)animateZoomOutAnimation:(id<UIViewControllerContextTransitioning>)transitionContext
{
    //fromViewController
    UIViewController<MXKAttachmentAnimatorDelegate> *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIImageView *destinationImageView = [fromViewController imageViewForAnimations];
    destinationImageView.hidden = YES;
    
    //toViewController
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    toViewController.view.frame = [transitionContext finalFrameForViewController:toViewController];
    [[transitionContext containerView] insertSubview:toViewController.view belowSubview:fromViewController.view];
    self.originalImageView.hidden = YES;
    
    //transitioningImageView
    UIImageView *transitioningImageView = [[UIImageView alloc] initWithImage:destinationImageView.image];
    transitioningImageView.frame = [[self class] aspectFitImage:destinationImageView.image inFrame:destinationImageView.frame];
    [[transitionContext containerView] addSubview:transitioningImageView];
    
    if (fromViewController.navigationController) {
        [fromViewController.navigationController setNavigationBarHidden:YES animated:YES];
    }
    
    //animation
    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        fromViewController.view.alpha = 0.0;
        transitioningImageView.frame = self.convertedFrame;
    } completion:^(BOOL finished) {
        [transitioningImageView removeFromSuperview];
        destinationImageView.hidden = NO;
        self.originalImageView.hidden = NO;
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.3;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    switch (self.animationType) {
        case PhotoBrowserZoomInAnimation:
            [self animateZoomInAnimation:transitionContext];
            break;
            
        case PhotoBrowserZoomOutAnimation:
            [self animateZoomOutAnimation:transitionContext];
            break;
    }
}


@end
