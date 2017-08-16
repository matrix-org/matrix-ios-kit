//
//  MXKPieChartHUD.h
//  Pods
//
//  Created by Aram Sargsyan on 8/15/17.
//
//

#import <UIKit/UIKit.h>

@interface MXKPieChartHUD : UIView

+ (MXKPieChartHUD *)showLoadingHudOnView:(UIView *)view WithMessage:(NSString *)message;

- (void)setProgress:(CGFloat)progress;

@end
