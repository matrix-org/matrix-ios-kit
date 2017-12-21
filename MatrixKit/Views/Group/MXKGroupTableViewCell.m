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

#import "MXKGroupTableViewCell.h"

#import "NSBundle+MatrixKit.h"

@implementation MXKGroupTableViewCell
@synthesize delegate;

#pragma mark - Class methods

- (void)render:(MXKCellData *)cellData
{
    groupCellData = (id<MXKGroupCellDataStoring>)cellData;
    if (groupCellData)
    {
        // Render the current group values.
        _groupName.text = groupCellData.groupDisplayname;
        _groupDescription.text = groupCellData.group.profile.shortDescription;
        
        if (_memberCount)
        {
            if (groupCellData.group.summary.usersSection.totalUserCountEstimate > 1)
            {
                _memberCount.text = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"num_members_other"], @(groupCellData.group.summary.usersSection.totalUserCountEstimate)];
            }
            else if (groupCellData.group.summary.usersSection.totalUserCountEstimate == 1)
            {
                _memberCount.text = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"num_members_one"], @1];
            }
            else
            {
                _memberCount.text = nil;
            }
        }
    }
    else
    {
        _groupName.text = nil;
        _groupDescription.text = nil;
        _memberCount.text = nil;
    }
}

- (MXKCellData*)renderedCellData
{
    return groupCellData;
}

+ (CGFloat)heightForCellData:(MXKCellData *)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // The height is fixed
    //@TODO: change this to handle dynamic font
    return 70;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    groupCellData = nil;
}

@end
