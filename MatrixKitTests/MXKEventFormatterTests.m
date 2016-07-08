//
//  MXKEventFormaterTests.m
//  MatrixKit
//
//  Created by Emmanuel ROHEE on 07/07/16.
//  Copyright © 2016 matrix.org. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "MatrixKit.h"



@interface MXEventFormaterTests : XCTestCase
{
    MXKEventFormatter *eventFormatter;
    MXEvent *anEvent;
}

@end

@implementation MXEventFormaterTests

- (void)setUp
{
    [super setUp];

    eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:nil];
    anEvent = [eventFormatter fakeRoomMessageEventForRoomId:@"aRoomId"
                                                withEventId:@"anEventId"
                                                 andContent:@{
                                                              @"msgtype": kMXMessageTypeText,
                                                              @"body": @"deded",
                                                              }];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMarkDowmToHtmlPreCode
{
    NSString *html = @"<pre><code>1\n2\n3\n4\n</code></pre>";
    NSAttributedString *as = [eventFormatter renderHTMLString:html forEvent:anEvent];

    NSString *a = as.string;

    // \R : any newlines
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\R" options:0 error:0];

    XCTAssertEqual(3, [regex numberOfMatchesInString:a options:0 range:NSMakeRange(0, a.length)], "There must be no line wrapping in <pre> blocks");

    [as enumerateAttributesInRange:NSMakeRange(0, as.length) options:(0) usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {

        UIFont *font = attrs[NSFontAttributeName];

        XCTAssertEqualObjects(font.fontName, @"Courier", "The font for <pre> and <code> should be monospace");
    }];

}


@end
