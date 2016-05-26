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

#import "NSBundle+MatrixKit.h"

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

- (id)initWithLocalHTMLFile:(NSString*)localHTMLFile
{
    self = [super init];
    if (self)
    {
        _localHTMLFile = localHTMLFile;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Init the webview
    webView = [[UIWebView alloc] initWithFrame:self.view.frame];
    webView.backgroundColor= [UIColor whiteColor];
    webView.delegate = self;
    webView.scalesPageToFit = YES;
    
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
    
    backButton = [[UIBarButtonItem alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    
    if (_URL.length)
    {
        self.URL = _URL;
    }
    else if (_localHTMLFile.length)
    {
        self.localHTMLFile = _localHTMLFile;
    }
}

- (void)destroy
{
    if (webView)
    {
        webView.delegate = nil;
        [webView stopLoading];
        [webView removeFromSuperview];
        webView = nil;
    }
    
    backButton = nil;
    
    _URL = nil;
    _localHTMLFile = nil;

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
    _localHTMLFile = nil;
    
    if (URL.length)
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URL]];
        [webView loadRequest:request];
    }
}

- (void)setLocalHTMLFile:(NSString *)localHTMLFile
{
    [webView stopLoading];
    
    _localHTMLFile = localHTMLFile;
    _URL = nil;
    
    if (localHTMLFile.length)
    {
        NSString* htmlString = [NSString stringWithContentsOfFile:localHTMLFile encoding:NSUTF8StringEncoding error:nil];
        [webView loadHTMLString:htmlString baseURL:nil];
    }
}

- (void)goBack
{
    if (webView.canGoBack)
    {
        [webView goBack];
    }
    else if (_localHTMLFile.length)
    {
        // Reload local html file
        self.localHTMLFile = _localHTMLFile;
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    // Handle back button visibility here
    BOOL canGoBack = webView.canGoBack;
    
    if (_localHTMLFile.length && !canGoBack)
    {
        // Check whether the current content is not the local html file
        canGoBack = (![webView.request.URL.absoluteString isEqualToString:@"about:blank"]);
    }
    
    if (canGoBack)
    {
        self.navigationItem.rightBarButtonItem = backButton;
    }
    else
    {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

@end
