//
//  CameraViewModel.h
//  ShutterSpeed
//
//  Created by Andrei Bouariu on 18/01/2021.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraViewModel : NSObject

// Session management
@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) AVCaptureDeviceType captureDeviceType;

// Callbacks
@property (nonatomic, copy, nullable) void(^onVideoOrientationChanged)(AVCaptureVideoOrientation);
@property (nonatomic, copy, nullable) void(^onAuthorizationStatusEvent)(AVCamSetupResult);
@property (nonatomic, copy, nullable) void(^onSessionStateChanged)(BOOL);
@property (nonatomic, copy, nullable) void(^onBrackedProcessed)(UIImage* _Nullable);
@property (nonatomic, copy, nullable) void(^onStartedShooting)(void);
@property (nonatomic, copy, nullable) void(^onFinishedShooting)(void);
@property (nonatomic, copy, nullable) void(^onInfo)(NSString* _Nullable);

- (void)configure;
- (void)startSession;
- (void)stopSession;
- (void)focusWithMode:(AVCaptureFocusMode)focusMode
       exposeWithMode:(AVCaptureExposureMode)exposureMode
        atDevicePoint:(CGPoint)point
monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange;
- (void)capturePhotoWithOrientation:(AVCaptureVideoOrientation)orientation;

@end

NS_ASSUME_NONNULL_END
