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
}

- (void)loadInputImage
{
    _inputImage = [NSImage imageNamed:@"inputImage"];
    
    [_inputImageView setImage:_inputImage];
}

- (void)loadOutputImage
{
    
}

#pragma mark DistanceField helpers

- (int)dist:(CGPoint)a b:(CGPoint)b
{
    return sqrtf((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
}

#pragma mark Actions

- (void)v1
{
    NSRect offscreenRect = NSMakeRect(0.0, 0.0, _inputImage.size.width, _inputImage.size.height);
    NSBitmapImageRep* offscreenRep = nil;
    
    offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil
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
    
    
    NSBitmapImageRep* inputBitmapRep = [[_inputImage representations] objectAtIndex:0];
    
    if(inputBitmapRep == nil)
        return;
    
    
    float spread = MIN(offscreenRect.size.width, offscreenRect.size.height);// (1 << scale);
    float min = -spread;
    float max = spread;
    
    for(int y = 0; y < offscreenRect.size.height; y++)
    {
        for (int x = 0; x < offscreenRect.size.width; x++)
        {
            NSColor* inputColor = [inputBitmapRep colorAtX:x y:y];
            
            int dist = -10;
            
            if([self isBlack:inputColor])
            {
                CGPoint currentLoc = CGPointMake(x, y);
                
                dist = [self search:inputBitmapRep loc:currentLoc];
                
                //NSLog(@"dist %i at %i, %i", dist, x, y);
            }
            
            // normalize distance 0 == 0.5 (edge), dist < 0 inside, dist > 0.5 outside
            float colorComponent = (255.0f / 2.0f) - (float)dist;
            colorComponent /= 255.0f;
            
            NSColor* outputColor = [NSColor colorWithCalibratedRed:colorComponent green:colorComponent blue:colorComponent alpha:1.0];
            [offscreenRep setColor:outputColor atX:x y:y];
        }
    }
    
    _outputImage = [[NSImage alloc] initWithCGImage:[offscreenRep CGImage] size:offscreenRect.size];
    
    [_outputImageView setImage:_outputImage];

}

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
    float spread = 25.0;
    float scale = 0.25;
    
    NSRect offscreenRect = NSMakeRect(0.0, 0.0, _inputImage.size.width + spread * 2,
                                      _inputImage.size.height + spread * 2);
    
    int width = (int)offscreenRect.size.width;
    int height = (int)offscreenRect.size.width;
    s_width = width;
    s_height = height;
    
    // create grid1
    CGPoint** grid1;
    grid1 = (CGPoint**) malloc(height*sizeof(CGPoint*));
    for(int i = 0; i < height; i++)
    {
        grid1[i] = (CGPoint*) malloc(width*sizeof(CGPoint));
    }
    
    CGPoint** grid2;
    grid2 = (CGPoint**) malloc(height*sizeof(CGPoint*));
    for(int i = 0; i < height; i++)
    {
        grid2[i] = (CGPoint*) malloc(width*sizeof(CGPoint));
    }
    

    // fill out the grids
    for(int y = 0; y < height; y++)
    {
        for(int x = 0; x < width; x++)
        {
            NSColor* inputColor = [inputBitmapRep colorAtX:x y:y];
            int pixel = (int)(inputColor.redComponent * 255.0f);
            grid1[y][x] = cell(pixel);
            grid2[y][x] = cell(invertCell(pixel));
        }
    }
    
    
    fillDistance(grid1, width, height);
//    for(int y = 0; y < height; y++)
//    {
//        for(int x = 0; x < width; x++)
//        {
//            if(grid1[y][x].x != 0.0 && grid1[y][x].y != 0.0)
//                NSLog(@"%f, %f", grid1[y][x].x, grid1[y][x].y);
//        }
//    }
    
    fillDistance(grid2, width, height);
    
    // create distance field
    float** distanceField;
    distanceField = (float**) malloc(height*sizeof(float*));
    for(int i = 0; i < height; i++)
    {
        distanceField[i] = (float*) malloc(width*sizeof(float));
    }
    
    // fill out the grids
    for(int y = 0; y < height; y++)
    {
        for(int x = 0; x < width; x++)
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
    
    for(int y = 0; y < height; y++)
    {
        for(int x = 0; x < width; x++)
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
            
            distanceField[y][x] = (int)dist;
//            NSLog(@"y %i, x: %i, %i", y, x, (int)dist);
            
            float colorComponent = dist / 255.0f;
            
            NSColor* outputColor = [NSColor colorWithCalibratedRed:colorComponent green:colorComponent blue:colorComponent alpha:1.0];
            [offscreenRep setColor:outputColor atX:x y:y];
        }
    }
    
    
    
    
    
    
    free(grid1);
    free(grid2);
    free(distanceField);
    
    _outputImage = [[NSImage alloc] initWithCGImage:[offscreenRep CGImage] size:offscreenRect.size];
    
    [_outputImageView setImage:_outputImage];

}

- (BOOL)isBlack:(NSColor*)color
{
    return  color.redComponent == 0.0 && color.greenComponent == 0.0 && color.blueComponent == 0.0;
}

- (int)search:(NSBitmapImageRep*)imageRep loc:(CGPoint)loc
{
    CGSize size = CGSizeMake(_inputImage.size.width, _inputImage.size.height);
    
    int dist = 1e6f;
    int tempDist = 0;
    
    // search current row and any row above the current row
    for(int y = loc.y; y >= 0; y--)
    {
        for(int x = 0; x < size.width; x++)
        {
            NSColor* color = [imageRep colorAtX:x y:y];
            if([self isBlack:color] == NO)
            {
                tempDist = [self dist:loc b:CGPointMake(x, y)];
                dist =  (dist < tempDist) ? dist : tempDist;
            }
        }
    }
    
    // search all rows below the current row
    for(int y = loc.y + 1; y < size.height; y++)
    {
        for(int x = 0; x < size.width; x++)
        {
            NSColor* color = [imageRep colorAtX:x y:y];
            if([self isBlack:color] == NO)
            {
                tempDist = [self dist:loc b:CGPointMake(x, y)];
                dist =  (dist < tempDist) ? dist : tempDist;
            }
        }
    }

    return dist;
}

@end


