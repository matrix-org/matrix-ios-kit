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

#import "MXKInterleavedRecentTableViewCell.h"

#import "MXKRecentCellDataStoring.h"

#import "MXKSessionRecentsDataSource.h"

#import "MXKTools.h"

@implementation MXKInterleavedRecentTableViewCell

#pragma mark - Class methods
+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKInterleavedRecentTableViewCell class])
                          bundle:[NSBundle bundleForClass:[MXKInterleavedRecentTableViewCell class]]];
}

- (NSString *)reuseIdentifier
{
    return kMXKRecentCellIdentifier;
}

- (void)awakeFromNib
{
    CAShapeLayer *userFlagMaskLayer = [[CAShapeLayer alloc] init];
    userFlagMaskLayer.frame = _userFlag.bounds;
    
    UIBezierPath *path = [[UIBezierPath alloc] init];
    [path moveToPoint:CGPointMake(0, 0)];
    [path addLineToPoint:CGPointMake(_userFlag.frame.size.width, _userFlag.frame.size.height)];
    [path addLineToPoint:CGPointMake(_userFlag.frame.size.width, 0)];
    [path closePath];
    
    userFlagMaskLayer.path = path.CGPath;
    _userFlag.layer.mask = userFlagMaskLayer;
}

- (void)render:(MXKCellData *)cellData
{
    [super render:cellData];
    
    id<MXKRecentCellDataStoring> roomCellData = (id<MXKRecentCellDataStoring>)cellData;
    if (roomCellData)
    {
        NSUInteger hash = [roomCellData.roomDataSource.mxSession.myUser.userId hash];
        _userFlag.backgroundColor = [MXKTools colorWithRGBValue:hash];
    }
}

@end
