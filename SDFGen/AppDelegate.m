//
//  AppDelegate.m
//  SDFGen
//
//  Created by Oleg Osin on 8/14/14.
//  Copyright (c) 2014 apportable. All rights reserved.
//

#import "AppDelegate.h"

@implementation DistancePoint

- (id)initWithPoint:(CGPoint)point
{
    if((self = [super init]))
    {
        _point = point;
        return self;
    }
    
    return self;
}

- (float)distSqr
{
    return (_point.x * _point.x) + (_point.y * _point.y);
}

- (float)dist
{
    return sqrtf([self distSqr]);
}

@end


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



#pragma mark Actions

- (IBAction)generate:(id)sender
{
    NSRect offscreenRect = NSMakeRect(0.0, 0.0, _inputImageView.bounds.size.width, _inputImageView.bounds.size.height);
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
    
    
    for(int y = 0; y < offscreenRect.size.height; y++)
    {
        for (int x = 0; x < offscreenRect.size.width; x++)
        {
            
//            DistancePoint* p = [[DistancePoint alloc] initWithPoint:CGPointMake(x, y)];
            
            NSUInteger zColourAry[3];
            
            [inputBitmapRep getPixel:zColourAry atX:x y:y];
            
            [offscreenRep setPixel:zColourAry atX:x y:y];
        }
    }

    
    _outputImage = [[NSImage alloc] initWithCGImage:[offscreenRep CGImage] size:offscreenRect.size];
    
    [_outputImageView setImage:_outputImage];
}

@end


