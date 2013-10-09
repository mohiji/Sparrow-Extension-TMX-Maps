//
//  SimpleTMXDemo.m
//

#import "SimpleTMXDemo.h"
#import "SXTMXMap.h"

@interface SimpleTMXDemo ()

@property (strong, nonatomic) SPPoint *lastTouchPosition;
@property (strong, nonatomic) SXTMXMap *tmxMap;

- (void)handleTouch:(SPTouchEvent*)touchEvent;

@end

@implementation SimpleTMXDemo

- (id)init
{
    self = [super init];
    if (self) {
        // Really obvious background color so we'll notice if anything's not drawing.
        Sparrow.stage.color = SP_AQUA;

        // Easiest way to display a map: create one from a file and add it as a child.
        _tmxMap = [[SXTMXMap alloc] initWithContentsOfFile:@"demo.tmx"];
        [self addChild:_tmxMap];

        [self addEventListener:@selector(handleTouch:) atObject:self forType:SP_EVENT_TYPE_TOUCH];
    }
    return self;
}

- (void)dealloc
{
    [self removeAllChildren];
    self.tmxMap = nil;
}

- (void)handleTouch:(SPTouchEvent *)touchEvent
{
    SPTouch *touch = [touchEvent.touches anyObject];

    if (touch.phase == SPTouchPhaseBegan) {
        self.lastTouchPosition = [touch locationInSpace:self];
    } else if(touch.phase == SPTouchPhaseMoved) {
        SPPoint *currentPosition = [touch locationInSpace:self];

        const float dx = currentPosition.x - _lastTouchPosition.x;
        const float dy = currentPosition.y - _lastTouchPosition.y;

        float newMapX = _tmxMap.x + dx;
        float newMapY = _tmxMap.y + dy;

        // Make sure not to scroll the map so far that we see the background beneath it.
        const float minimumX = -(_tmxMap.width - Sparrow.stage.width);
        const float minimumY = -(_tmxMap.height - Sparrow.stage.height);

        newMapX = MIN(newMapX, 0);
        newMapX = MAX(newMapX, minimumX);
        newMapY = MIN(newMapY, 0);
        newMapY = MAX(newMapY, minimumY);

        _tmxMap.x = newMapX;
        _tmxMap.y = newMapY;
        
        self.lastTouchPosition = currentPosition;
    } else if (touch.phase == SPTouchPhaseEnded || touch.phase == SPTouchPhaseCancelled) {
        self.lastTouchPosition = nil;
    }
}

@end
