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

#import "MXKWebViewViewController.h"

@implementation MXKWebViewViewController

- (id)initWithURL:(NSString*)URL
{
    self = [super init];
    if (self)
    {
        _URL = URL;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Init the webview
    webView = [[UIWebView alloc] initWithFrame:self.view.frame];
    webView.backgroundColor= [UIColor whiteColor];
    
    [webView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.view addSubview:webView];
    
    // Force webview in full width (to handle auto-layout in case of screen rotation)
    NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:webView
                                                                      attribute:NSLayoutAttributeLeading
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.view
                                                                      attribute:NSLayoutAttributeLeading
                                                                     multiplier:1.0
                                                                       constant:0];
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:webView
                                                                       attribute:NSLayoutAttributeTrailing
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.view
                                                                       attribute:NSLayoutAttributeTrailing
                                                                      multiplier:1.0
                                                                        constant:0];
    // Force webview in full height
    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:webView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.topLayoutGuide
                                                                     attribute:NSLayoutAttributeBottom
                                                                    multiplier:1.0
                                                                      constant:0];
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:webView
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.bottomLayoutGuide
                                                                        attribute:NSLayoutAttributeTop
                                                                       multiplier:1.0
                                                                         constant:0];
    
    if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
    {
        [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, bottomConstraint]];
    }
    else
    {
        [self.view addConstraint:leftConstraint];
        [self.view addConstraint:rightConstraint];
        [self.view addConstraint:topConstraint];
        [self.view addConstraint:bottomConstraint];
    }
    
    if (self.URL.length)
    {
        // And load the expected URL
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.URL]];
        [webView loadRequest:request];
    }
}

- (void)destroy
{
    [webView stopLoading];
    [webView removeFromSuperview];
    webView = nil;

    [super destroy];
}

- (void)dealloc
{
    [self destroy];
}

- (void)setURL:(NSString *)URL
{
    [webView stopLoading];
    
    _URL = URL;
    
    if (URL.length)
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URL]];
        [webView loadRequest:request];
    }
}

@end
