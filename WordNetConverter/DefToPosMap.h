//
//  DefToPosMap.h
//  WordNetConverter
//
//  Created by James Weinert on 12/16/12.
//  Copyright (c) 2012 James Weinert. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DefToPosMap : NSObject
@property (nonatomic, assign) NSInteger partOfSpeech;
@property (nonatomic, assign) NSUInteger defID;
@property (nonatomic, assign) NSString *definition;

@end
