//
//  AppDelegate.m
//  SDFGen
//
//  Created by Oleg Osin on 8/14/14.
//  Copyright (c) 2014 apportable. All rights reserved.
//

#import "AppDelegate.h"


static int s_width = 0;
static int s_height = 0;
static CGPoint s_inside = {0, 0};
static CGPoint s_outside = {9999, 9999};

@implementation AppDelegate {
    NSImage* _inputImage;
    NSImage* _outputImage;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _spread.delegate = self;
    _width.delegate = self;
    _height.delegate = self;

}

- (void)openDocument:(id)sender
{
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setCanChooseFiles:YES];
    [openDlg setAllowedFileTypes:[NSArray arrayWithObject:@"png"]];
    
    [openDlg beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSOKButton)
        {
            NSArray* files = [openDlg URLs];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0),
                           dispatch_get_current_queue(), ^{
                               for (int i = 0; i < [files count]; i++)
                               {
                                   NSString* fileName = [[files objectAtIndex:i] path];
                                   [self loadInputImage:fileName];
                               }
                           });
        }
    }];
}

- (void)saveDocumentAs:(id)sender
{
    if(!_outputImage)
        return;
    
    NSWindow* window = [self window];
    NSSavePanel* panel = [NSSavePanel savePanel];
    [panel setNameFieldStringValue:@"output.png"];
    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSString* path = [panel URL].path;
            
            [self saveImageToFile:_outputImage name:path];
        }
    }];
}

- (void)loadInputImage:(NSString*)fileName
{
    // Add to recent list of opened documents
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];
    
    _inputImage = [[NSImage alloc] initWithContentsOfFile:fileName];
    
    [_inputImageView setImage:_inputImage];
}

#pragma mark Image helpers

- (NSImage *)imageResize:(NSImage*)image newSize:(NSSize)newSize
{
   // [image setScalesWhenResized:NO];

    NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
    [smallImage lockFocus];
    [image setSize: newSize];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    
    [image drawAtPoint:CGPointMake(0, 0) fromRect:CGRectMake(0, 0, newSize.width, newSize.height)
             operation:NSCompositeCopy fraction:1.0];
    
    [smallImage unlockFocus];
    return smallImage;
}

- (void)saveImageToFile:(NSImage*)image name:(NSString*)name
{
    NSData* imageData = [image TIFFRepresentation];
    NSBitmapImageRep *rep = [[NSBitmapImageRep imageRepsWithData:imageData] objectAtIndex:0];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    imageData = [rep representationUsingType:NSJPEGFileType properties:imageProps];
   
    if([imageData writeToFile:name atomically: NO] == NO)
    {
        NSLog(@"Warning: Failed to save %@", name);
    }
}

#pragma mark DistanceField helpers

CGPoint cell(int pixel)
{
    return (pixel == 0) ? s_inside : s_outside;
}

static int invertCell(int pixel)
{
    return 255 - pixel;
}

static CGPoint getCell(CGPoint** grid, int x, int y)
{
    // check bounds
    if(y < 0 || y >= s_height) return s_outside;
    if(x < 0 || x >= s_width) return s_outside;
    
    return grid[y][x];
}

static int distSquared(CGPoint cell)
{
    return cell.x * cell.x + cell.y * cell.y;
}

static CGPoint compare(CGPoint** grid, CGPoint cell, int x, int y, int x2, int y2)
{
    CGPoint other = getCell(grid, x + x2, y + y2);
    other = CGPointMake(other.x + x2, other.y + y2);
    
    if(distSquared(other) < distSquared(cell))
        return other;
    
    return cell;
}

static void fillDistance(CGPoint** grid, int width, int height)
{
    CGPoint point;
    for(int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            point = grid[y][x];
            point = compare(grid, point, x, y, -1, 0);
            point = compare(grid, point, x, y, 0, -1);
            point = compare(grid, point, x, y, -1, -1);
            point = compare(grid, point, x, y, 1, -1);
            grid[y][x] = point;
        }
        
        for(int x = width - 1; x >= 0; x--)
        {
            point = grid[y][x];
            point = compare(grid, point, x, y, 1, 0);
            grid[y][x] = point;
        }
    }
    
    for (int y = height - 1; y >= 0; y--)
    {
        for (int x = width - 1; x >= 0; x--)
        {
            point = grid[y][x];
            point = compare(grid, point, x, y, 1, 0);
            point = compare(grid, point, x, y, 0, 1);
            point = compare(grid, point, x, y, -1, 1);
            point = compare(grid, point, x, y, 1, 1);
            grid[y][x] = point;
        }
        
        for (int x = 0; x < width; x++)
        {
            point = grid[y][x];
            point = compare(grid, point, x, y, -1, 0);
            grid[y][x] = point;
        }
    }
}

static int npot(int n)
{
    n = n - 1;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n = n + 1;
    return n;
}

#pragma mark Textfield Delegates

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor
{
    return YES;
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if(control == _width)
    {
        NSLog(@"WIDTH: %li", [fieldEditor.string integerValue]);
    }
    
    if(control == _height)
    {
        NSLog(@"HEIGHT: %li", [_height.stringValue integerValue]);
    }

    if(control == _spread)
    {
        NSLog(@"SPREAD: %li", [_spread.stringValue integerValue]);
    }

    return YES;
}

#pragma mark Actions

- (IBAction)generate:(id)sender
{
    [[self.width window] makeFirstResponder:nil];
    [[self.height window] makeFirstResponder:nil];
    [[self.spread window] makeFirstResponder:nil];
    
    NSBitmapImageRep* inputBitmapRep = [[_inputImage representations] objectAtIndex:0];
    
    if(inputBitmapRep == nil)
        return;

    _generateButton.enabled = NO;
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // create dst image with adjusted size
    // create 2 grid representation for each input/output image
    // fill out distance fields
    // generate distancefield by subtracting the grids
    // normalize distance field
    
    // create dst image with adjusted size
    float spread = [_spread.stringValue floatValue];
    
    NSRect offscreenRect = NSMakeRect(0.0, 0.0, _inputImage.size.width,
                                      _inputImage.size.height);
    
    s_width = (int)offscreenRect.size.width;
    s_height = (int)offscreenRect.size.width;

    // create grid1
    __block CGPoint** grid1;
    grid1 = (CGPoint**) malloc(s_height*sizeof(CGPoint*));
    __block CGPoint** grid2;
    grid2 = (CGPoint**) malloc(s_height*sizeof(CGPoint*));
    
    void (^finalize)(void) = ^{
        static int s_distancesFilled = 0;
        s_distancesFilled++;
        
        if(s_distancesFilled >= 2)
        {
            s_distancesFilled = 0;
            NSLog(@"distances generated, normalize and save output");
            // create distance field
            float** distanceField;
            distanceField = (float**) malloc(s_height*sizeof(float*));
            for(int i = 0; i < s_height; i++)
            {
                distanceField[i] = (float*) malloc(s_width*sizeof(float));
            }
            
            float dist1;
            float dist2;
            // fill out the grids
            for(int y = 0; y < s_height; y++)
            {
                for(int x = 0; x < s_width; x++)
                {
                    dist1 = sqrtf(distSquared(grid1[y][x]));
                    dist2 = sqrtf(distSquared(grid2[y][x]));
                    distanceField[y][x] = dist1 - dist2;
                }
            }
            
            // create output image
            NSBitmapImageRep* offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
                                                                                     pixelsWide:offscreenRect.size.width
                                                                                     pixelsHigh:offscreenRect.size.height
                                                                                  bitsPerSample:8
                                                                                samplesPerPixel:4
                                                                                       hasAlpha:YES
                                                                                       isPlanar:NO
                                                                                 colorSpaceName:NSCalibratedRGBColorSpace
                                                                                   bitmapFormat:0
                                                                                    bytesPerRow:(4 * offscreenRect.size.width)
                                                                                   bitsPerPixel:32];
            
            // normalize
            float dist = 0.0f;
            float maxDist = spread;
            float minDist = spread * -1;
            float colorComponent;
            
            for(int y = 0; y < s_height; y++)
            {
                for(int x = 0; x < s_width; x++)
                {
                    dist = distanceField[y][x];
                    
                    if(dist < 0)
                    {
                        dist = -128 * (dist - minDist) / minDist;
                    }
                    else
                    {
                        dist = 128 + 128 * dist / maxDist;
                    }
                    
                    if(dist < 0)
                    {
                        dist = 0;
                    }
                    else if(dist > 255)
                    {
                        dist = 255;
                    }
                    
                    colorComponent = dist / 255.0f;
                    
                    NSColor* outputColor = [NSColor colorWithCalibratedRed:colorComponent green:colorComponent blue:colorComponent alpha:1.0];
                    [offscreenRep setColor:outputColor atX:x y:y];
                }
            }
            
            free(grid1);
            free(grid2);
            free(distanceField);
            
            _outputImage = [[NSImage alloc] initWithCGImage:[offscreenRep CGImage] size:offscreenRect.size];
//            int outputWidth = (_width.intValue % 2) ? npot(_width.intValue) : _width.intValue;
//            int outputHeight = (_height.intValue % 2) ? npot(_height.intValue) : _height.intValue;

            int outputWidth = _width.intValue;
            int outputHeight = _height.intValue;

            CGFloat screenScale = [[NSScreen mainScreen] backingScaleFactor];
            outputWidth /= screenScale;
            outputHeight /= screenScale;
            _outputImage = [self imageResize:_outputImage newSize:CGSizeMake(outputWidth, outputHeight)];
            
            [_outputImageView setImage:_outputImage];
            
            //[self saveImageToFile:_outputImage name:@"output.png"];
            _generateButton.enabled = YES;
        }
        
    };
    
    void (^fillGrids)(void) = ^{
        static int s_gencnt = 0;
        s_gencnt++;
        if(s_gencnt >= 2)
        {
            NSLog(@"filling grids");
            NSColor* inputColor;
            int pixel;
            // fill out the grids
            for(int y = 0; y < s_height; y++)
            {
                for(int x = 0; x < s_width; x++)
                {
                    inputColor = [inputBitmapRep colorAtX:x y:y];
                    pixel = (int)(inputColor.redComponent * 255.0f);
                    grid1[y][x] = cell(pixel);
                    grid2[y][x] = cell(invertCell(pixel));
                }
            }
            
            NSLog(@"done filling grid");
            // start distance generation
            dispatch_async(globalQueue, ^{
                NSLog(@"start distance 1");
                fillDistance(grid1, s_width, s_height);
                finalize();
            });
            
            dispatch_async(globalQueue, ^{
                NSLog(@"start distance 2");
                fillDistance(grid2, s_width, s_height);
                finalize();
            });
            
            s_gencnt = 0;
        }
    };
    
    dispatch_async(globalQueue, ^{
        for(int i = 0; i < s_height; i++)
        {
            grid1[i] = (CGPoint*)malloc(s_width*sizeof(CGPoint));
        }
        NSLog(@"done grid 1");
        fillGrids();
    });
    
    dispatch_async(globalQueue, ^{
        for(int i = 0; i < s_height; i++)
        {
            grid2[i] = (CGPoint*)malloc(s_width*sizeof(CGPoint));
        }
        NSLog(@"done grid 2");
        fillGrids();
    });
}

@end


