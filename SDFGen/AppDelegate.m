//
//  AppDelegate.m
//  SDFGen
//
//  Created by Oleg Osin on 8/14/14.
//  Copyright (c) 2014 apportable. All rights reserved.
//

#import "AppDelegate.h"

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
    _inputImage = [NSImage imageNamed:@"tinydist"];
    
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

- (IBAction)generate:(id)sender
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


