//
//  MXKPieChartHUD.m
//  Pods
//
//  Created by Aram Sargsyan on 8/15/17.
//
//

#import "MXKPieChartHUD.h"
#import "NSBundle+MatrixKit.h"
#import "MXKPieChartView.h"

@interface MXKPieChartHUD ()

@property (weak, nonatomic) IBOutlet UIView *hudView;
@property (weak, nonatomic) IBOutlet MXKPieChartView *pieChartView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;


@end

@implementation MXKPieChartHUD

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self configureFromNib];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self configureFromNib];
    }
    return self;
}

- (void)configureFromNib
{
    NSBundle *bundle = [NSBundle mxk_bundleForClass:self.class];
    [bundle loadNibNamed:NSStringFromClass(self.class) owner:self options:nil];
    self.hudView.frame = self.bounds;
    
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 10.0;
    
    self.pieChartView.backgroundColor = [UIColor clearColor];
    self.pieChartView.progressColor = [UIColor whiteColor];
    self.pieChartView.unprogressColor = [UIColor clearColor];
    self.pieChartView.tintColor = [UIColor cyanColor];
    
    [self addSubview:self.hudView];
}

#pragma mark - Public

+ (MXKPieChartHUD *)showLoadingHudOnView:(UIView *)view WithMessage:(NSString *)message
{
    MXKPieChartHUD *hud = [[MXKPieChartHUD alloc] init];
    [view addSubview:hud];
    
    hud.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSLayoutConstraint *centerXConstraint = [NSLayoutConstraint constraintWithItem:hud attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
    NSLayoutConstraint *centerYConstraint = [NSLayoutConstraint constraintWithItem:hud attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:hud attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:160];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:hud attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:100];
    [NSLayoutConstraint activateConstraints:@[centerXConstraint, centerYConstraint, widthConstraint, heightConstraint]];
    
    hud.titleLabel.text = message;
    
    return hud;
}

- (void)setProgress:(CGFloat)progress
{
    [UIView animateWithDuration:0.2 animations:^{
        [self.pieChartView setProgress:progress];
    }];
    
}



@end
