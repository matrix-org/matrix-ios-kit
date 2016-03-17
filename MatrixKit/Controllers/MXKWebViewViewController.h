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

#import "MXKViewController.h"

/**
 'MXKWebViewViewController' instance is used to display a webview.
 */
@interface MXKWebViewViewController : MXKViewController
{
@protected
    
    /**
     The content of this screen is fully displayed by this webview
     */
    UIWebView *webView;
}

/**
 Init 'MXKWebViewViewController' instance with a web content url.
 
 @param URL the url to open
 */
- (id)initWithURL:(NSString*)URL;

/**
 Define the web content url to open
 */
@property (nonatomic) NSString *URL;

@end
