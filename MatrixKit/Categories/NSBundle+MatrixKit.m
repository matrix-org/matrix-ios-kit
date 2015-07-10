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

#import "NSBundle+MatrixKit.h"

@implementation NSBundle (MatrixKit)

+ (NSBundle*)mxk_assetsBundle
{
    NSString *bundleResourcePath = [NSBundle mainBundle].resourcePath;
    NSString *assetPath = [bundleResourcePath stringByAppendingPathComponent:@"MatrixKitAssets.bundle"];
    return [NSBundle bundleWithPath:assetPath];
}

+ (UIImage *)mxk_imageFromMXKAssetsBundleWithName:(NSString *)name
{
    NSString *imagePath = [[NSBundle mxk_assetsBundle] pathForResource:name ofType:@"png" inDirectory:@"Images"];
    
    return  [UIImage imageWithContentsOfFile:imagePath];
}

+ (NSURL*)mxk_audioURLFromMXKAssetsBundleWithName:(NSString *)name
{
    return [NSURL fileURLWithPath:[[NSBundle mxk_assetsBundle] pathForResource:name ofType:@"mp3" inDirectory:@"Sounds"]];
}

@end
