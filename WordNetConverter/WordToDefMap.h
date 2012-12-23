//
//  WordToDefMap.h
//  WordNetConverter
//
//  Created by James Weinert on 12/16/12.
//  Copyright (c) 2012 James Weinert. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WordToDefMap : NSObject
@property (nonatomic, assign) NSUInteger wordID;
@property (nonatomic, assign) NSUInteger defID;
@property (nonatomic, assign) NSUInteger priority;

@end
