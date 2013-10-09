//
//  SXTMXMap.m
//  Sparrow TMX Map Extension
//
//  Created by Jonathan Fischer on 2013-07-18.
//  Copyright (c) 2013 Jonathan Fischer. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SXTMXMap.h"

#pragma mark Tilesets

@interface SXTMXTileset : NSObject

@property (copy, nonatomic) NSString *name;

@property (assign, nonatomic) NSUInteger tileWidth;
@property (assign, nonatomic) NSUInteger tileHeight;
@property (assign, nonatomic) NSUInteger imageWidth;
@property (assign, nonatomic) NSUInteger imageHeight;

@property (assign, nonatomic) NSUInteger tilesWide;
@property (assign, nonatomic) NSUInteger tilesHigh;
@property (assign, nonatomic) float du;
@property (assign, nonatomic) float dv;

@property (assign, nonatomic) NSUInteger firstTileIndex;
@property (assign, nonatomic) NSUInteger lastTileIndex;
@property (strong, nonatomic) SPTexture *texture;

- (void)finishTileset;

@end

@implementation SXTMXTileset

- (void)dealloc
{
    self.name = nil;
    self.texture = nil;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"SXTMXTileset %@: image size %d x %d, tile size %d x %d\n",
            self.name, self.imageWidth, self.imageHeight, self.tileWidth, self.tileHeight];
}

- (void)finishTileset
{    
    const int imageWidth = self.texture.width;
    const int imageHeight = self.texture.height;
    const int numTilesWide = imageWidth / self.tileWidth;
    const int numTilesHigh = imageHeight / self.tileHeight;
    const int numTiles = numTilesWide * numTilesHigh;
    
    const float du = (float)self.tileWidth / (float)imageWidth;
    const float dv = (float)self.tileHeight / (float)imageHeight;
    
    self.tilesWide = numTilesWide;
    self.tilesHigh = numTilesHigh;
    self.lastTileIndex = self.firstTileIndex + numTiles;
    self.du = du;
    self.dv = dv;
    self.texture.smoothing = SPTextureSmoothingNone;
}
@end

#pragma mark Layers

@interface SXTMXLayer ()
{
    CGPoint _drawOffset;
    BOOL _readyToDraw;
}

// Override the readonly parentMap property
@property (weak, nonatomic) SXTMXMap *parentMap;

@property (assign, nonatomic) NSUInteger tilesWide;
@property (assign, nonatomic) NSUInteger tilesHigh;
@property (assign, nonatomic) NSUInteger tileWidth;
@property (assign, nonatomic) NSUInteger tileHeight;

@property (assign, nonatomic) int *tileIndices;

@property (strong, nonatomic) NSArray *tilesets;
@property (strong, nonatomic) NSMutableArray *quadBatches;

- (void)finishLayer;

@end

@implementation SXTMXLayer

- (void)dealloc
{
    self.name = nil;
    self.tilesets = nil;
    self.quadBatches = nil;
    free(self.tileIndices);
}

- (int)indexForTileAtX:(int)x y:(int)y
{
    if (x < 0 || x >= _tilesWide) {
        return -1;
    }
    
    if (y < 0 || y >= _tilesHigh) {
        return -1;
    }
    
    return _tileIndices[x + y * _tilesWide];
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"SXTMXLayer %@: %d x %d tiles\n", self.name, self.tilesWide, self.tilesHigh];
}

- (void)render:(SPRenderSupport *)support
{
    if (self.visible && !_readyToDraw) {
        [self finishLayer];
        _readyToDraw = YES;
    }
    [super render:support];
}

- (void)finishLayer
{
    const int numTilesets = self.tilesets.count;
    
    self.quadBatches = [NSMutableArray arrayWithCapacity:numTilesets];
    for (int i = 0; i < numTilesets; i++) {
        SPQuadBatch *batch = [SPQuadBatch quadBatch];
        [self addChild:batch];
        [self.quadBatches setObject:batch atIndexedSubscript:i];
    }
    
    const int tilesWide = self.tilesWide;
    const int tilesHigh = self.tilesHigh;
    const float tileWidth = self.tileWidth;
    const float tileHeight = self.tileHeight;
    
    SXTMXTileset *tempTileset = self.tilesets[0];
    const float textureWidth = tempTileset.texture.width;
    const float textureHeight = tempTileset.texture.height;

    SPImage *image = [[SPImage alloc] initWithTexture:tempTileset.texture];
    image.width = tileWidth;
    image.height = tileHeight;
    
    for (int y = 0; y < tilesHigh; y++) {
        for (int x = 0; x < tilesWide; x++) {
            // Figure out which tileset this tile index refers to.
            const int tileIndex = self.tileIndices[x + y * tilesWide];
            
            int tilesetIndex = -1;
            for (int i = 0; i < numTilesets; i++) {
                SXTMXTileset *tileset = self.tilesets[i];
                if (tileIndex >= tileset.firstTileIndex && tileIndex < tileset.lastTileIndex) {
                    tilesetIndex = i;
                    break;
                }
            }
            
            if (tilesetIndex == -1) {
                continue;
            }
            
            SXTMXTileset *realTileset = self.tilesets[tilesetIndex];
            const int realTileIndex = tileIndex - realTileset.firstTileIndex;
            const int tileX = realTileIndex % realTileset.tilesWide;
            const int tileY = realTileIndex / realTileset.tilesWide;
            
            float u1 = tileWidth * tileX + 0.5f;
            float u2 = u1 + tileWidth - 1.0f;
            float v1 = tileHeight * tileY + 0.5f;
            float v2 = v1 + tileHeight - 1.0f;
            
            u1 /= textureWidth;
            u2 /= textureWidth;
            v1 /= textureHeight;
            v2 /= textureHeight;
            
            image.x = x * tileWidth;
            image.y = y * tileHeight;
            [image setTexCoordsWithX:u1 y:v1 ofVertex:0];
            [image setTexCoordsWithX:u2 y:v1 ofVertex:1];
            [image setTexCoordsWithX:u1 y:v2 ofVertex:2];
            [image setTexCoordsWithX:u2 y:v2 ofVertex:3];
            image.texture = realTileset.texture;
            
            SPQuadBatch *batch = self.quadBatches[tilesetIndex];
            [batch addQuad:image];
        }
    }
}

// Sparrow's SPVertexData class does not cache bounds calculations, and the default SPSprite
// implementation is going to call out to that eventually via the SPQuadBatches used to store
// the tilemaps. Overriding that here to avoid a really bad performance hit.

- (float)width
{
    return _tilesWide * _tileWidth;
}

- (float)height
{
    return _tilesHigh * _tileHeight;
}

@end

#pragma mark Object Groups

@implementation SXTMXObject

- (NSString*)description
{
    return [NSString stringWithFormat:@"SXTMXObject named %@, type %@, x: %.2f, y: %.2f, width: %.2f, height: %.2f", self.name, self.type, self.x, self.y, self.width, self.height];
}

@end

@implementation SXTMXObjectGroup

- (id)init
{
    self = [super init];
    if (self) {
        self.objects = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    self.objects = nil;
}

- (NSString*)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"SXTMXObjectGroup %@ (%d objects)\n", self.name, self.objects.count];
    for (id key in self.objects) {
        [description appendFormat:@"%@\n", self.objects[key]];
    }
    return description;
}

@end

#pragma mark Maps

@interface SXTMXMap ()
{
    BOOL _inDataTag;
}

// Override some property definitions from the header.
@property (assign, nonatomic) NSUInteger tileWidth;
@property (assign, nonatomic) NSUInteger tileHeight;
@property (assign, nonatomic) NSUInteger tilesWide;
@property (assign, nonatomic) NSUInteger tilesHigh;

@property (copy, nonatomic) NSString *path;

// These are arrays rather than dictionaries so that I can be sure they end up ordered
// the same as they were in the .SXTMX file.
@property (strong, nonatomic) NSMutableArray *tilesets;
@property (strong, nonatomic) NSMutableArray *layers;
@property (strong, nonatomic) NSMutableArray *objectGroups;

@property (weak, nonatomic) SXTMXTileset *currentTileset;
@property (weak, nonatomic) SXTMXLayer *currentLayer;
@property (weak, nonatomic) SXTMXObjectGroup *currentObjectGroup;

- (void)parseTmx:(NSString*)path;
- (int*)decodeBase64Tiles:(NSString*)encodedTiles;

@end

@implementation SXTMXMap

+ (SXTMXMap*)tmxMapWithContentsOfFile:(NSString *)path
{
    return [[SXTMXMap alloc] initWithContentsOfFile:path];
}

- (id)initWithContentsOfFile:(NSString*)path
{
    self = [super init];
    if (self) {
        self.tilesets = [NSMutableArray array];
        self.layers = [NSMutableArray array];
        self.objectGroups = [NSMutableArray array];
        _inDataTag = NO;
        [self parseTmx:path];
    }
    return self;
}

- (void)dealloc
{
    self.path = nil;
    self.tilesets = nil;
    self.layers = nil;
    self.objectGroups = nil;
}

- (void)parseTmx:(NSString *)path
{
    if (!path) return;
    
    self.path = [SPUtils absolutePathToFile:path];
    if (!self.path) [NSException raise:SP_EXC_FILE_NOT_FOUND format:@"file not found: %@", path];
    
    NSData *xmlData = [NSData dataWithContentsOfFile:self.path options:NSDataReadingMappedIfSafe error:NULL];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
    
    parser.delegate = self;
    BOOL success = [parser parse];
    
    if (!success) {
        [NSException raise:SP_EXC_FILE_INVALID format:@"could not parse SXTMX file %@. Error: %@",
             path, parser.parserError.localizedDescription];
    }
    
    for (SXTMXLayer *layer in self.layers) {
        layer.tilesets = self.tilesets;
    }
}

- (NSString*)description
{
    NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"SXTMX Map %@\n", self.path];
    [descriptionString appendFormat:@"%d tilesets:\n", self.tilesets.count];
    for (SXTMXTileset *tileset in self.tilesets) {
        [descriptionString appendString:tileset.description];
    }
    
    for (SXTMXLayer *layer in self.layers) {
        [descriptionString appendString:layer.description];
    }
    
    return descriptionString;
}

- (SXTMXLayer*)layerNamed:(NSString *)name
{
    for (SXTMXLayer *layer in self.layers) {
        if ([name isEqualToString:layer.name]) {
            return layer;
        }
    }
    
    return nil;
}

- (SXTMXObjectGroup*)objectGroupNamed:(NSString *)name
{
    for (SXTMXObjectGroup *group in self.objectGroups) {
        if ([name isEqualToString:group.name]) {
            return group;
        }
    }
    
    return nil;
}

// Sparrow's SPVertexData class does not cache bounds calculations, and the default SPSprite
// implementation is going to call out to that eventually via the SPQuadBatches used to store
// the tilemaps. Overriding that here to avoid a really bad performance hit.

- (float)width
{
    return _tileWidth * _tilesWide;
}

- (float)height
{
    return _tileHeight * _tilesHigh;
}

#pragma mark Private methods

- (int*)decodeBase64Tiles:(NSString *)encodedTiles
{
    NSData *data = [NSData dataWithBase64EncodedString:encodedTiles];
    
    const int expectedNumTiles = self.currentLayer.tilesWide * self.currentLayer.tilesHigh;
    const int expectedNumBytes = expectedNumTiles * sizeof(int);
    
    if (data.length != expectedNumBytes) {
        [NSException raise:@"SXTMXParseError" format:@"Base 64 decoded data layer is %d bytes long; expected %d bytes", data.length, expectedNumBytes];
    }
    
    const uint8_t *bytes = data.bytes;
    int *tileData = malloc(data.length);
    memcpy(tileData, bytes, expectedNumBytes);
    return tileData;
}

#pragma mark NSXMLParser delegate stuff

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributes
{
    if ([elementName caseInsensitiveCompare:@"map"] == NSOrderedSame) {
        // This is the topmost element.
        NSString *orientation = attributes[@"orientation"];
        if ([orientation caseInsensitiveCompare:@"orthogonal"] != NSOrderedSame) {
            [NSException raise:@"UnhandledTmxFormat" format:@"I don't know how to handle SXTMX files with orientation = %@", orientation];
        }
        
        self.tileWidth = [attributes[@"tilewidth"] integerValue];
        self.tileHeight = [attributes[@"tileheight"] integerValue];
        self.tilesWide = [attributes[@"width"] integerValue];
        self.tilesHigh = [attributes[@"height"] integerValue];
    } else if ([elementName caseInsensitiveCompare:@"tileset"] == NSOrderedSame) {
        NSString *name = attributes[@"name"];
        
        SXTMXTileset *tileset = [[SXTMXTileset alloc] init];
        self.currentTileset = tileset;
        
        tileset.name = name;
        
        tileset.tileWidth = [attributes[@"tilewidth"] integerValue];
        tileset.tileHeight = [attributes[@"tileheight"] integerValue];
        tileset.firstTileIndex = [attributes[@"firstgid"] integerValue];
        
        [self.tilesets addObject:tileset];
    } else if ([elementName caseInsensitiveCompare:@"image"] == NSOrderedSame) {
        if (self.currentTileset == nil) {
            [NSException raise:@"MissingTilesetTag" format:@"I encountered an <image> tag outside of a <tileset> one."];
        }

        self.currentTileset.texture = [SPTexture textureWithContentsOfFile:attributes[@"source"]];
        self.currentTileset.imageWidth = [attributes[@"width"] integerValue];
        self.currentTileset.imageHeight = [attributes[@"height"] integerValue];
        
        [self.currentTileset finishTileset];        
    } else if ([elementName caseInsensitiveCompare:@"layer"] == NSOrderedSame) {
        NSString *name = attributes[@"name"];
        
        SXTMXLayer *layer = [[SXTMXLayer alloc] init];
        layer.name = name;
        layer.parentMap = self;
        layer.tilesWide = [attributes[@"width"] integerValue];
        layer.tilesHigh = [attributes[@"height"] integerValue];
        layer.tileWidth = self.tileWidth;
        layer.tileHeight = self.tileHeight;
        
        [self.layers addObject:layer];
        [self addChild:layer];
        self.currentLayer = layer;
    } else if ([elementName caseInsensitiveCompare:@"data"] == NSOrderedSame) {
        if (self.currentLayer == nil) {
            [NSException raise:@"MissingLayerTag" format:@"I encountered a <data> tag outside of a <layer> one."];
        }
        _inDataTag = YES;
        
    } else if ([elementName caseInsensitiveCompare:@"objectgroup"] == NSOrderedSame) {
        NSString *name = attributes[@"name"];
        
        SXTMXObjectGroup *group = [[SXTMXObjectGroup alloc] init];
        group.name = name;
        
        [self.objectGroups addObject:group];
        [self addChild:group];
        self.currentObjectGroup = group;
    } else if ([elementName caseInsensitiveCompare:@"object"] == NSOrderedSame) {
        NSString *name = attributes[@"name"];
        NSString *type = attributes[@"type"];
        float x = [attributes[@"x"] floatValue];
        float y = [attributes[@"y"] floatValue];
        float width = [attributes[@"width"] floatValue];
        float height = [attributes[@"height"] floatValue];
        
        SXTMXObject *obj = [[SXTMXObject alloc] init];
        obj.name = name;
        obj.type = type;
        obj.x = x;
        obj.y = y;
        obj.width = width;
        obj.height = height;
        
        self.currentObjectGroup.objects[name] = obj;
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    if ([elementName caseInsensitiveCompare:@"layer"]) {
        self.currentLayer = nil;
    } else if ([elementName caseInsensitiveCompare:@"tileset"]) {
        self.currentTileset = nil;
    } else if ([elementName caseInsensitiveCompare:@"data"]) {
        _inDataTag = NO;
    } else if ([elementName caseInsensitiveCompare:@"objectgroup"]) {
        self.currentObjectGroup = nil;
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if (!_inDataTag) {
        // The only useful character data in a SXTMX file comes within the <data> tag
        return;
    }
    
    NSString *encodedData = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (encodedData.length == 0) {
        return;
    }
    
    self.currentLayer.tileIndices = [self decodeBase64Tiles:encodedData];
}

@end
