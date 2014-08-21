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
    // Insert code here to initialize your application
    [self loadInputImage];

    _spread.delegate = self;
    _width.delegate = self;
    _height.delegate = self;

}

- (void)loadInputImage
{
    _inputImage = [NSImage imageNamed:@"hirez"];
    
    [_inputImageView setImage:_inputImage];
}

#pragma mark Image helpers

- (NSImage *)imageResize:(NSImage*)image newSize:(NSSize)newSize
{
    [image setScalesWhenResized:YES];

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
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [paths objectAtIndex:0];
    NSString* path = [NSString stringWithFormat:@"%@/%@", documentsPath, name];
    
    NSData* imageData = [image TIFFRepresentation];
    NSBitmapImageRep *rep = [[NSBitmapImageRep imageRepsWithData:imageData] objectAtIndex:0];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor];
    imageData = [rep representationUsingType:NSJPEGFileType properties:imageProps];
    if([imageData writeToFile:path atomically: NO] == NO)
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
    NSString* curtxt = fieldEditor.string;
    
    NSCharacterSet* decimals = [NSCharacterSet decimalDigitCharacterSet];
    
    NSRange wtf = [curtxt rangeOfCharacterFromSet:decimals];

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
    NSBitmapImageRep* inputBitmapRep = [[_inputImage representations] objectAtIndex:0];
    
    if(inputBitmapRep == nil)
        return;
    
    // create dst image with adjusted size
    // create 2 grid representation for each input/output image
    // fill out distance fields
    // generate distancefield by subtract the grids
    // normalize distance field
    
    // create dst image with adjusted size
    float spread = [_spread.stringValue floatValue];
    
    NSRect offscreenRect = NSMakeRect(0.0, 0.0, _inputImage.size.width + spread * 2,
                                      _inputImage.size.height + spread * 2);
    
    s_width = (int)offscreenRect.size.width;
    s_height = (int)offscreenRect.size.width;
    
    // create grid1
    CGPoint** grid1;
    grid1 = (CGPoint**) malloc(s_height*sizeof(CGPoint*));
    for(int i = 0; i < s_height; i++)
    {
        grid1[i] = (CGPoint*)malloc(s_width*sizeof(CGPoint));
    }
    
    CGPoint** grid2;
    grid2 = (CGPoint**) malloc(s_height*sizeof(CGPoint*));
    for(int i = 0; i < s_height; i++)
    {
        grid2[i] = (CGPoint*)malloc(s_width*sizeof(CGPoint));
    }
    

    // fill out the grids
    for(int y = 0; y < s_height; y++)
    {
        for(int x = 0; x < s_width; x++)
        {
            NSColor* inputColor = [inputBitmapRep colorAtX:x y:y];
            int pixel = (int)(inputColor.redComponent * 255.0f);
            grid1[y][x] = cell(pixel);
            grid2[y][x] = cell(invertCell(pixel));
        }
    }
    
    fillDistance(grid1, s_width, s_height);
    fillDistance(grid2, s_width, s_height);
    
    // create distance field
    float** distanceField;
    distanceField = (float**) malloc(s_height*sizeof(float*));
    for(int i = 0; i < s_height; i++)
    {
        distanceField[i] = (float*) malloc(s_width*sizeof(float));
    }
    
    // fill out the grids
    for(int y = 0; y < s_height; y++)
    {
        for(int x = 0; x < s_width; x++)
        {
            float dist1 = sqrtf(distSquared(grid1[y][x]));
            float dist2 = sqrtf(distSquared(grid2[y][x]));
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
            
            float colorComponent = dist / 255.0f;
            
            NSColor* outputColor = [NSColor colorWithCalibratedRed:colorComponent green:colorComponent blue:colorComponent alpha:1.0];
            [offscreenRep setColor:outputColor atX:x y:y];
        }
    }
    
    free(grid1);
    free(grid2);
    free(distanceField);
    
    _outputImage = [[NSImage alloc] initWithCGImage:[offscreenRep CGImage] size:offscreenRect.size];
    int outputWidth = _width.intValue;
    int outputHeight = _height.intValue;
    _outputImage = [self imageResize:_outputImage newSize:CGSizeMake(npot(outputWidth),
                                                                     npot(outputHeight))];
    
    [_outputImageView setImage:_outputImage];
    
    [self saveImageToFile:_outputImage name:@"output.png"];

}

@end


