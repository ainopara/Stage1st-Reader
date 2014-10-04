//
//  S1ContentViewController.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <UIKit/UIKit.h>

@class S1Topic, S1Floor, S1Tracer, S1HTTPClient;

@interface S1ContentViewController : UIViewController

@property (nonatomic, strong) S1Topic *topic;
@property (nonatomic, strong) NSArray *topicFloors;
@property (nonatomic, strong) S1Tracer *tracer;



@end
