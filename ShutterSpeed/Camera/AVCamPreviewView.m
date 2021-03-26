//
//  AVCamPreviewView.m
//  ShutterSpeed
//
//  Created by Andrei Bouariu on 18/01/2021.
//

#import "AVCamPreviewView.h"

@implementation AVCamPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer*)videoPreviewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession*)session {
    return self.videoPreviewLayer.session;
}

- (void)setSession:(AVCaptureSession*) session {
    self.videoPreviewLayer.session = session;
}

@end
