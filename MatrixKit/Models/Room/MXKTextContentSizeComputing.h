/*
Copyright 2019 The Matrix.org Foundation C.I.C

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

/**
 `MXKTextContentSizeComputing` delegates the computation of size for rendered strings.
 */
@protocol MXKTextContentSizeComputing <NSObject>

/**
 Get the size of a UITextview for rendering a text.

 @param attributedString the text to render.
 @param maxWidth the max width.
 @param removeVerticalInset YES to not take incount inset heigt.
 */
- (CGSize)textContentSizeForAttributedString:(NSAttributedString*)attributedString withMaxWith:(CGFloat)maxWidth removeVerticalInset:(BOOL)removeVerticalInset;

@end
