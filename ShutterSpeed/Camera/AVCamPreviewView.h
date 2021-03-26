//
//  AVCamPreviewView.h
//  ShutterSpeed
//
//  Created by Andrei Bouariu on 18/01/2021.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVCamPreviewView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic) AVCaptureSession *session;

@end

NS_ASSUME_NONNULL_END
