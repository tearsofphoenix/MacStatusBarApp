#import "StatusItemView.h"

@interface StatusItemView ()

@property (nonatomic) BOOL updating;
@property (nonatomic, retain) NSString *dataString;
@property (nonatomic, assign) NSTimer *timer;
@end

@implementation StatusItemView

@synthesize statusItem = _statusItem;
@synthesize image = _image;
@synthesize alternateImage = _alternateImage;
@synthesize isHighlighted = _isHighlighted;
@synthesize action = _action;
@synthesize target = _target;

#pragma mark -

- (id)initWithStatusItem: (NSStatusItem *)statusItem
{
    CGFloat itemWidth = [statusItem length];
    CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
    NSRect itemRect = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
    self = [super initWithFrame:itemRect];
    
    if (self != nil)
    {
        _statusItem = statusItem;
        _statusItem.view = self;
        
        _timer = [NSTimer scheduledTimerWithTimeInterval: 5 * 60
                                                  target: self
                                                selector: @selector(_tryToUpdateByTimer:)
                                                userInfo: nil
                                                 repeats: YES];
        [_timer fire];
    }
    return self;
}


#pragma mark -

- (void)drawRect: (NSRect)dirtyRect
{
	[self.statusItem drawStatusBarBackgroundInRect: dirtyRect
                                     withHighlight: self.isHighlighted];
    
    NSImage *icon = self.isHighlighted ? self.alternateImage : self.image;
    NSSize iconSize = [icon size];
    NSRect bounds = self.bounds;
    CGFloat iconX = 0;// roundf((NSWidth(bounds) - iconSize.width) / 2);
    CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
    NSPoint iconPoint = NSMakePoint(iconX, iconY);
    
	[icon drawAtPoint: iconPoint
             fromRect: NSZeroRect
            operation: NSCompositeSourceOver
             fraction: 1.0];
    
    CGFloat tx = iconX + iconSize.width;
    [_dataString drawInRect: NSMakeRect(tx, iconY - 5, bounds.size.width - tx, bounds.size.height)
             withAttributes: nil];
}

#pragma mark -
#pragma mark Mouse tracking

- (void)mouseDown:(NSEvent *)theEvent
{
    [NSApp sendAction:self.action to:self.target from:self];
}

#pragma mark -
#pragma mark Accessors

- (void)setHighlighted:(BOOL)newFlag
{
    if (_isHighlighted == newFlag) return;
    _isHighlighted = newFlag;
    [self setNeedsDisplay:YES];
}

#pragma mark -

- (void)setImage:(NSImage *)newImage
{
    if (_image != newImage) {
        _image = newImage;
        [self setNeedsDisplay:YES];
    }
}

- (void)setAlternateImage:(NSImage *)newImage
{
    if (_alternateImage != newImage) {
        _alternateImage = newImage;
        if (self.isHighlighted) {
            [self setNeedsDisplay:YES];
        }
    }
}

#pragma mark -

- (NSRect)globalRect
{
    NSRect frame = [self frame];
    frame.origin = [self.window convertBaseToScreen:frame.origin];
    return frame;
}

#define Prefix @"Bank has collected "

- (void)_tryToUpdateByTimer: (NSTimer *)timer
{
    if (_updating)
    {
        return;
    }
    
    _updating = YES;
    
    [NSURLConnection sendAsynchronousRequest: [NSURLRequest requestWithURL: [NSURL URLWithString: @"http://makebtc.org/"]]
                                       queue: [NSOperationQueue mainQueue]
                           completionHandler: (^(NSURLResponse *response, NSData *data, NSError *connectionError)
                                               {
                                                   _updating = NO;
                                                   
                                                   if (!connectionError && data)
                                                   {
                                                       @autoreleasepool
                                                       {
                                                           NSString *string = [[NSString alloc] initWithData: data
                                                                                                    encoding: NSUTF8StringEncoding];
                                                           NSRange range = [string rangeOfString: Prefix "[-+]?([0-9]*\\.[0-9]+|[0-9]+) of [0-9]+ BTC"
                                                                                         options: NSRegularExpressionSearch];
                                                           if (range.location != NSNotFound)
                                                           {
                                                               string = [string substringWithRange: range];
                                                               string = [string substringFromIndex: [Prefix length]];
                                                               [self setDataString: string];
                                                               
                                                               dispatch_async(dispatch_get_main_queue(),
                                                                              (^
                                                                               {
                                                                                   [self setNeedsDisplay: YES];
                                                                               }));
                                                           }
                                                       }
                                                       
                                                   }
                                               })];
}

@end
