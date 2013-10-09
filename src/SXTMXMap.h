//
//  SXTMXMap.h
//  Sparrow TMX Map Extension
//
//  Created by Jonathan Fischer on 2013-07-18.
//  Copyright (c) 2013 Jonathan Fischer. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Foundation/Foundation.h>
#import "Sparrow.h"
@class SXTMXMap;

@interface SXTMXLayer : SPSprite

@property (copy, nonatomic) NSString *name;
@property (readonly, nonatomic) SXTMXMap *parentMap;
@property (readonly, nonatomic) NSUInteger tilesWide;
@property (readonly, nonatomic) NSUInteger tilesHigh;

- (int)indexForTileAtX:(int)x y:(int)y;

@end

@interface SXTMXObject : NSObject

@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *type;
@property (assign, nonatomic) float x;
@property (assign, nonatomic) float y;
@property (assign, nonatomic) float width;
@property (assign, nonatomic) float height;

@end

// Why is this an SPSprite? Because it gives me an easy way to attach game objects
// to the Sparrow scene.
@interface SXTMXObjectGroup : SPSprite

@property (copy, nonatomic) NSString *name;
@property (strong, nonatomic) NSMutableDictionary *objects;

@end

@interface SXTMXMap : SPSprite <NSXMLParserDelegate>

+ (SXTMXMap*)tmxMapWithContentsOfFile:(NSString *)path;
- (id)initWithContentsOfFile:(NSString*)path;

@property (readonly, nonatomic) NSUInteger tileWidth;
@property (readonly, nonatomic) NSUInteger tileHeight;
@property (readonly, nonatomic) NSUInteger tilesWide;
@property (readonly, nonatomic) NSUInteger tilesHigh;

- (SXTMXLayer*)layerNamed:(NSString*)name;
- (SXTMXObjectGroup*)objectGroupNamed:(NSString*)name;

@end
