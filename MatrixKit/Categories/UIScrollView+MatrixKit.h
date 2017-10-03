/*
 Copyright 2017 Vector Creations Ltd
 
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

#import <UIKit/UIKit.h>

/**
 Define a `UIScrollView` category at MatrixKit level to handle the adjusted content inset which is not defined before iOS 11.
 */
@interface UIScrollView (MatrixKit)

/**
 Get the total adjustment in a scroll view.
 The insets derived from the content insets and the safe area of the scroll view.
 */
@property(nonatomic, readonly) UIEdgeInsets mxk_adjustedContentInset;

@end
