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


#import <XCTest/XCTest.h>

#import "MatrixKit.h"

@interface MXEventFormatterTests : XCTestCase
{
    MXKEventFormatter *eventFormatter;
    MXEvent *anEvent;
}

@end

@implementation MXEventFormatterTests

- (void)setUp
{
    [super setUp];

    // Create a minimal event formatter
    // Note: it may not be enough for testing all MXKEventFormatter methods
    eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:nil];
    
    anEvent = [[MXEvent alloc] init];
    anEvent.roomId = @"aRoomId";
    anEvent.eventId = @"anEventId";
    anEvent.wireType = kMXEventTypeStringRoomMessage;
    anEvent.originServerTs = (uint64_t) ([[NSDate date] timeIntervalSince1970] * 1000);
    anEvent.wireContent = @{
                            @"msgtype": kMXMessageTypeText,
                            @"body": @"deded",
                            };
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRenderHTMLStringWithPreCode
{
    NSString *html = @"<pre><code>1\n2\n3\n4\n</code></pre>";
    NSAttributedString *as = [eventFormatter renderHTMLString:html forEvent:anEvent];

    NSString *a = as.string;

    // \R : any newlines
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\R" options:0 error:0];
    XCTAssertEqual(3, [regex numberOfMatchesInString:a options:0 range:NSMakeRange(0, a.length)], "renderHTMLString must keep line break in <pre> and <code> blocks");

    [as enumerateAttributesInRange:NSMakeRange(0, as.length) options:(0) usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {

        UIFont *font = attrs[NSFontAttributeName];
        XCTAssertEqualObjects(font.fontName, @"Menlo-Regular", "The font for <pre> and <code> should be monospace");
    }];

}
    
- (void)testMarkdownFormatting
{
    NSString *html = [eventFormatter htmlStringFromMarkdownString:@"Line One.\nLine Two."];
    
    BOOL hardBreakExists =      [html rangeOfString:@"<br />"].location != NSNotFound;
    BOOL openParagraphExists =  [html rangeOfString:@"<p>"].location != NSNotFound;
    BOOL closeParagraphExists = [html rangeOfString:@"</p>"].location != NSNotFound;
    
    // Check for some known error cases
    XCTAssert(hardBreakExists, "The soft break (\\n) must be converted to a hard break (<br />).");
    XCTAssert(!openParagraphExists && !closeParagraphExists, "The html must not contain any opening or closing paragraph tags.");
}


@end
