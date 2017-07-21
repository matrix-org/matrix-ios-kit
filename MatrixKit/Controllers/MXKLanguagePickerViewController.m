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

#import "MXKLanguagePickerViewController.h"

#import "NSBundle+MatrixKit.h"

#import "NBPhoneNumberUtil.h"

NSString* const kMXKLanguagePickerViewControllerCellId = @"kMXKLanguagePickerViewControllerCellId";

NSString* const kMXKLanguagePickerCellDataKeyText = @"text";
NSString* const kMXKLanguagePickerCellDataKeyLanguage = @"language";

@interface MXKLanguagePickerViewController ()
{
    NSMutableArray<NSDictionary*> *cellDataArray;
    NSMutableArray<NSDictionary*>*filteredCellDataArray;
    
    NSString *previousSearchPattern;
}

@end

@implementation MXKLanguagePickerViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKLanguagePickerViewController class])
                          bundle:[NSBundle bundleForClass:[MXKLanguagePickerViewController class]]];
}

+ (instancetype)languagePickerViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKLanguagePickerViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKLanguagePickerViewController class]]];
}

- (void)finalizeInit
{
    [super finalizeInit];

    cellDataArray = [NSMutableArray array];
    filteredCellDataArray = nil;

    previousSearchPattern = nil;

    // Populate cellDataArray with language available in the app bundle
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray<NSString *> *localizations = [mainBundle localizations];

    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:mainBundle.preferredLocalizations.firstObject];
    for (NSString *language in localizations)
    {
        NSString *languageDescription = [locale displayNameForKey:NSLocaleIdentifier value:language];
        if (!languageDescription)
        {
            // This is the "Base" localization, call it default.
            // Get the language chosen by the OS
            NSString *defaultLanguageDescription = [locale displayNameForKey:NSLocaleIdentifier value:mainBundle.preferredLocalizations.firstObject];

            languageDescription = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"language_picker_default_language"], defaultLanguageDescription];

            [cellDataArray addObject:@{
                                       kMXKLanguagePickerCellDataKeyText:languageDescription
                                       }];
        }
        else
        {
            [cellDataArray addObject:@{
                                       kMXKLanguagePickerCellDataKeyText: languageDescription,
                                       kMXKLanguagePickerCellDataKeyLanguage: language
                                       }];
        }
    }

    // Default to "" in order to differentiate it from nil
    _selectedLanguage = @"";
}

- (void)destroy
{
    [super destroy];

    cellDataArray = nil;
    filteredCellDataArray = nil;

    previousSearchPattern = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!self.tableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }

    // Hide search bar by default
    [self hideSearchBar:YES];

    self.navigationItem.title = [NSBundle mxk_localizedStringForKey:@"language_picker_title"];
}

- (void)hideSearchBar:(BOOL)hidden
{
    self.searchBar.hidden = hidden;
    self.tableView.contentInset = UIEdgeInsetsMake(hidden ? -44 : 0, 0, 0 ,0);
    [self.view setNeedsUpdateConstraints];
}

#pragma mark - UITableView dataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (filteredCellDataArray)
    {
        return filteredCellDataArray.count;
    }
    return cellDataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kMXKLanguagePickerViewControllerCellId];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kMXKLanguagePickerViewControllerCellId];
    }
    
    NSInteger index = indexPath.row;
    NSDictionary *itemCellData;
    
    if (filteredCellDataArray)
    {
        if (index < filteredCellDataArray.count)
        {
            itemCellData = filteredCellDataArray[index];
        }
    }
    else if (index < cellDataArray.count)
    {
        itemCellData = cellDataArray[index];
    }
    
    if (itemCellData)
    {
        cell.textLabel.text = itemCellData[kMXKLanguagePickerCellDataKeyText];

        // Mark the cell with the selected language
        if (_selectedLanguage == itemCellData[kMXKLanguagePickerCellDataKeyLanguage] || [_selectedLanguage isEqualToString:itemCellData[kMXKLanguagePickerCellDataKeyLanguage]])
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    
    return cell;
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (self.delegate)
    {
        NSInteger index = indexPath.row;
        NSString *language;
        
        if (filteredCellDataArray)
        {
            if (index < filteredCellDataArray.count)
            {
                language = filteredCellDataArray[index][kMXKLanguagePickerCellDataKeyLanguage];
            }
        }
        else if (index < cellDataArray.count)
        {
            language = cellDataArray[index][kMXKLanguagePickerCellDataKeyLanguage];
        }
        
        if (language)
        {
            [self.delegate languagePickerViewController:self didSelectLangugage:language];
        }
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if (searchText.length)
    {
        searchText = [searchText lowercaseString];
        
        if (previousSearchPattern && [searchText hasPrefix:previousSearchPattern])
        {
            for (NSUInteger index = 0; index < filteredCellDataArray.count;)
            {
                NSString *text = [filteredCellDataArray[index][kMXKLanguagePickerCellDataKeyText] lowercaseString];
                
                if ([text hasPrefix:searchText] == NO)
                {
                    [filteredCellDataArray removeObjectAtIndex:index];
                }
                else
                {
                    index++;
                }
            }
        }
        else
        {
            filteredCellDataArray = [NSMutableArray array];
            
            for (NSUInteger index = 0; index < cellDataArray.count; index++)
            {
                NSString *text = [cellDataArray[index][kMXKLanguagePickerCellDataKeyText] lowercaseString];
                
                if ([text hasPrefix:searchText])
                {
                    [filteredCellDataArray addObject:cellDataArray[index]];
                }
            }
        }
        
        previousSearchPattern = searchText;
    }
    else
    {
        previousSearchPattern = nil;
        filteredCellDataArray = nil;
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    previousSearchPattern = nil;
    filteredCellDataArray = nil;
}

@end
