//
//  S1ContentViewModel.m
//  Stage1st
//
//  Created by Zheng Li on 10/9/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "S1ContentViewModel.h"
#import "S1DataCenter.h"
#import "S1Topic.h"
#import "S1Parser.h"
#import "DDXML.h"
#import "DDXMLElementAdditions.h"
#import <ReactiveObjc/ReactiveObjC.h>
#import <Reachability/Reachability.h>

@interface S1ContentViewModel ()

@property (nonatomic, strong) NSArray<Floor *> *floors;

@end

@implementation S1ContentViewModel

- (instancetype)initWithTopic:(S1Topic *)topic dataCenter:(S1DataCenter *)dataCenter {
    self = [super init];
    if (self != nil) {
        // Initialization code
        if ([topic isImmutable]) {
            _topic = [topic copy];
        } else {
            _topic = topic;
        }

        if (topic.lastViewedPage != nil) {
            _currentPage = [topic.lastViewedPage unsignedIntegerValue];
        } else {
            _currentPage = 1;
        }
        _previousPage = _currentPage;

        _cachedViewPosition = [[NSMutableDictionary<NSNumber *, NSNumber *> alloc] init];
        if (topic.lastViewedPosition != nil && topic.lastViewedPage != nil) {
            [_cachedViewPosition setObject:topic.lastViewedPosition forKey:topic.lastViewedPage];
        }

        _totalPages = ([topic.replyCount unsignedIntegerValue] / 30) + 1;

        if (_topic.favorite == nil) {
            _topic.favorite = @(NO);
        }

        DDLogInfo(@"[ContentVM] Initialize with TopicID: %@", _topic.topicID);

        _dataCenter = dataCenter;

        __weak __typeof__(self) weakSelf = self;
        [RACObserve(self, currentPage) subscribeNext:^(id x) {
            DDLogDebug(@"[ContentVM] Current page changed to: %@", x);
        }];

        [RACObserve(self.topic, replyCount) subscribeNext:^(id x) {
            __strong __typeof__(self) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }

            DDLogInfo(@"[ContentVM] reply count changed: %@", x);
            strongSelf.totalPages = ([x unsignedIntegerValue] / 30) + 1;
        }];
    }

    return self;
}

- (void)setCurrentPage:(NSUInteger)currentPage {
    _previousPage = _currentPage;
    _currentPage = currentPage;
}

+ (NSString *)processHTMLString:(NSString *)HTMLString withFloorID:(NSInteger)floorID {
    DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:[HTMLString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    // process images
    NSArray *images = [xmlDoc nodesForXPath:@"//img" error:nil];
    NSInteger imageCount = 1;
    for (DDXMLElement *image in images) {
        NSString *imageSrc = [[image attributeForName:@"src"] stringValue];
        NSString *imageFile = [[image attributeForName:@"file"] stringValue];
        if (imageFile) {
            [image removeAttributeForName:@"src"];
            [image addAttributeWithName:@"src" stringValue:imageFile];
            
        }
        else if (imageSrc && (![imageSrc hasPrefix:@"http"])) {
            [image removeAttributeForName:@"src"];
            NSString *baseURLString = [[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"];
            [image addAttributeWithName:@"src" stringValue:[baseURLString stringByAppendingString:imageSrc]];
        }
        if ([[image attributeForName:@"src"] stringValue]) {
            if (![imageSrc hasPrefix:@"static/image/smiley"]) {
                DDXMLElement *linkElement = image;
                DDXMLElement *imageElement = [[DDXMLElement alloc] initWithName:@"img"];
                [imageElement addAttributeWithName:@"id" stringValue:[NSString stringWithFormat:@"%ld-img%ld", (long)floorID, (long)imageCount]];
                imageCount += 1;
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Display"] || [MyAppDelegate.reachability isReachableViaWiFi]) {
                    [imageElement addAttributeWithName:@"src" stringValue:[[image attributeForName:@"src"] stringValue]];
                } else {
                    NSString *placeholderURL = [[[NSUserDefaults standardUserDefaults] valueForKey:@"BaseURL"] stringByAppendingString:@"stage1streader-placeholder.png"];
                    [imageElement addAttributeWithName:@"src" stringValue:placeholderURL];
                }
                NSString *linkString = [NSString stringWithFormat:@"window.webkit.messageHandlers.stage1st.postMessage({'type': 'image', 'src': '%@', 'id': '%@'})", [[image attributeForName:@"src"] stringValue], [[imageElement attributeForName:@"id"] stringValue]];
                [linkElement removeAttributeForName:@"onclick"];
                [linkElement addAttributeWithName:@"href" stringValue:@"javascript:void(0);"];
                [linkElement addAttributeWithName:@"onclick" stringValue:linkString];
                [linkElement addChild:imageElement];
                [linkElement removeAttributeForName:@"src"];
                [linkElement setName:@"a"];
            }
        }
        
        //clean image's attribute (if it is not a mahjong face, it is the linkElement)
        [image removeAttributeForName:@"onmouseover"];
        [image removeAttributeForName:@"file"];
        [image removeAttributeForName:@"id"];
        [image removeAttributeForName:@"lazyloadthumb"];
        [image removeAttributeForName:@"border"];
        [image removeAttributeForName:@"width"];
        [image removeAttributeForName:@"height"];
        
    }
    
    // process spoiler
    NSArray<NSString *> *spoilerXpathList = @[
        @"//font[@color='LemonChiffon']",
        @"//font[@color='Yellow']",
        @"//font[@color='#fffacd']",
        @"//font[@color='#FFFFCC']",
        @"//font[@color='White']"
    ];
    NSArray< DDXMLElement *> *spoilers = @[];
    for (NSString *spoilerXpath in spoilerXpathList) {
        NSArray< DDXMLElement *> * _Nullable temp = [xmlDoc nodesForXPath:spoilerXpath error:nil];
        if (temp != nil) {
            spoilers = [spoilers arrayByAddingObjectsFromArray:temp];
        }
    }
    
    for (DDXMLElement *spoilerElement in spoilers) {
        [spoilerElement removeAttributeForName:@"color"];
        [spoilerElement setName:@"div"];
        [spoilerElement addAttributeWithName:@"style" stringValue:@"display:none;"];
        NSUInteger index = [spoilerElement index];
        DDXMLElement *parentElement = (DDXMLElement *)[spoilerElement parent];
        [spoilerElement detach];
        [parentElement setOwner: xmlDoc];
        DDXMLElement *containerElement = [[DDXMLElement alloc] initWithName:@"div"];
        DDXMLElement *buttonElement = [[DDXMLElement alloc] initWithName:@"input"];
        [buttonElement addAttributeWithName:@"value" stringValue:@"显示反白内容"];
        [buttonElement addAttributeWithName:@"type" stringValue:@"button"];
        [buttonElement addAttributeWithName:@"style" stringValue:@"width:80px;font-size:10px;margin:0px;padding:0px;"];
        [buttonElement addAttributeWithName:@"onclick" stringValue:@"var e = this.parentNode.getElementsByTagName('div')[0];e.style.display = '';e.style.border = '#aaa 1px solid';this.style.display = 'none';"];
        [containerElement addChild:buttonElement];
        [containerElement addChild:spoilerElement];
        [parentElement insertChild:containerElement atIndex:index];
    }
    
    // process indent
    NSArray *paragraphs = [xmlDoc nodesForXPath:@"//td[@class='t_f']//p[@style]" error:nil];
    if (paragraphs != nil) {
        for(DDXMLElement *paragraph in paragraphs) {
            [paragraph removeAttributeForName:@"style"];
        }
    }

    NSString *processedString = [xmlDoc XMLStringWithOptions:DDXMLNodePrettyPrint];
    processedString = [processedString substringWithRange:NSMakeRange(183,[processedString length]-183-17)];
    if (processedString) {
        return [processedString stringByReplacingOccurrencesOfString:@"<br></br>" withString:@"<br />"];
    } else {
        DDLogError(@"[ContentViewModel] Fail to modify image: %@", HTMLString);
        return HTMLString;
    }
}

@end
