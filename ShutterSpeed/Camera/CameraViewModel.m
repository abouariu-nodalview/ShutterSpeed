//
//  CameraViewModel.m
//  ShutterSpeed
//
//  Created by Andrei Bouariu on 18/01/2021.
//

#import "CameraViewModel.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>

@interface CameraViewModel () <AVCapturePhotoCaptureDelegate>

@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;

@property (nonatomic) NSArray<NSNumber *> *shutterSpeedDenominators;
@property (nonatomic) NSInteger index;

@end

@implementation CameraViewModel

- (instancetype)init {
    if (self = [super init]) {
        self.session = [[AVCaptureSession alloc] init];
        self.sessionQueue = dispatch_queue_create("CameraSessionQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)configure {
    [self configureCameraAuthorization];
    [self configureCameraSession];
    [self configureShutterSpeeds];
}

- (void)configureCameraAuthorization {
    self.setupResult = AVCamSetupResultSuccess;
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized: {
            break;
        }
            
        case AVAuthorizationStatusNotDetermined: {
            dispatch_suspend(self.sessionQueue);
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (!granted) {
                    self.setupResult = AVCamSetupResultCameraNotAuthorized;
                }
                dispatch_resume(self.sessionQueue);
            }];
            break;
        }
        default: {
            self.setupResult = AVCamSetupResultCameraNotAuthorized;
            break;
        }
    }
}

- (void)configureCameraSession {
    dispatch_async(self.sessionQueue, ^{
        if (self.setupResult != AVCamSetupResultSuccess) {
            return;
        }
        [self setCaptureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
    });
}

- (void)configureShutterSpeeds {
    self.shutterSpeedDenominators = @[@7200, @1600, @400, @100, @24, @12, @6, @3, @2];
}

- (void)setCaptureDeviceType:(AVCaptureDeviceType)captureDeviceType {
    // begin configuration
    [self.session beginConfiguration];
    
    // remove previous input & output
    if (self.deviceInput) {
        [self.session removeInput:self.deviceInput];
    }
    if (self.photoOutput) {
        [self.session removeOutput:self.photoOutput];
    }
    
    // set session
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    // set video input
    NSError *error = nil;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:captureDeviceType
                                                                 mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionBack];
    NSAssert(device != nil, @"Unsupported device");
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    NSAssert(deviceInput != nil, @"Unsupported device input");
    
    if (![self.session canAddInput:deviceInput]) {
        [self.session commitConfiguration];
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        return;
    }
    
    [self.session addInput:deviceInput];
    self.deviceInput = deviceInput;
    
    AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
    if (self.onVideoOrientationChanged) {
        // TODO: set initial orientation
        self.onVideoOrientationChanged(initialVideoOrientation);
    }
    
    // set photo output
    AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
    if (![self.session canAddOutput:photoOutput]) {
        [self.session commitConfiguration];
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        return;
    }
    
    [self.session addOutput:photoOutput];
    self.photoOutput = photoOutput;
    self.photoOutput.highResolutionCaptureEnabled = YES;
    if (@available(iOS 14.1, *)) {
        self.photoOutput.contentAwareDistortionCorrectionEnabled = self.photoOutput.contentAwareDistortionCorrectionSupported;
    } else {
        // Fallback on earlier versions
    }
    if (@available(iOS 13.0, *)) {
        self.photoOutput.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
    }
    
    // finish configuration
    self.session.automaticallyConfiguresCaptureDeviceForWideColor = NO;
    [self.session commitConfiguration];
    
    [device lockForConfiguration:nil];
    [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    [device unlockForConfiguration];
}

- (void)startSession {
    dispatch_async(self.sessionQueue, ^{
        switch (self.setupResult) {
            case AVCamSetupResultSuccess: {
                [self addObservers];
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
                break;
            }
            case AVCamSetupResultCameraNotAuthorized:
            case AVCamSetupResultSessionConfigurationFailed: {
                if (self.onAuthorizationStatusEvent) {
                    self.onAuthorizationStatusEvent(self.setupResult);
                }
                break;
            }
        }
    });
}

- (void)stopSession {
    if (self.setupResult == AVCamSetupResultSuccess) {
        [self.session stopRunning];
        [self removeObservers];
    }
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode
        exposeWithMode:(AVCaptureExposureMode)exposureMode
         atDevicePoint:(CGPoint)point
monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice* device = self.deviceInput.device;
        NSError* error = nil;
        if ([device lockForConfiguration:&error]) {
            /*
             Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
             Call set(Focus/Exposure)Mode() to apply the new point of interest.
            */
            if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode]) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            
            if (device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode]) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog(@"Could not lock device for configuration: %@", error);
        }
    });
}

- (void)capturePhotoWithOrientation:(AVCaptureVideoOrientation)orientation {
    if (self.onStartedShooting) {
        self.onStartedShooting();
    }
    [self resetCamera];
    [self shoot];
}

- (void)resetCamera {
    [self.deviceInput.device lockForConfiguration:nil];
    [self.deviceInput.device setExposureMode:AVCaptureExposureModeAutoExpose];
    [self.deviceInput.device unlockForConfiguration];
    self.index = 0;
}

- (void)shoot {
    
    dispatch_async(self.sessionQueue, ^{
        
        // set exposure & ISO
        CMTime shutterSpeed = CMTimeMake(1, [self.shutterSpeedDenominators objectAtIndex:self.index].intValue);
        NSArray *manualSettings = @[[AVCaptureManualExposureBracketedStillImageSettings manualExposureSettingsWithExposureDuration:shutterSpeed ISO:100]];
        
        AVCapturePhotoBracketSettings *photoSettings;
        if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeJPEG]) {
            photoSettings = [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0
                                                                                      processedFormat:nil
                                                                                    bracketedSettings:manualSettings];
        } else {
            photoSettings = [AVCapturePhotoBracketSettings photoSettings];
        }
        photoSettings.highResolutionPhotoEnabled = YES;
        if (@available(iOS 13.0, *)) {
            photoSettings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed;
        }

        [self.photoOutput capturePhotoWithSettings:photoSettings delegate:self];
    });
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    
    self.index++;
    
    // add image to results
    NSData *data = photo.fileDataRepresentation;
    UIImage *image = [[UIImage alloc] initWithData:data];
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    
    // show image on UI
    if (self.onBrackedProcessed) {
        self.onBrackedProcessed(image);
    }
    
    // shoot more pictures or finish shooting
    if (self.index == self.shutterSpeedDenominators.count) {
        if (self.onFinishedShooting) {
            self.onFinishedShooting();
        }
    } else {
        [self shoot];
    }
}

#pragma mark KVO and Notifications

- (void)addObservers {
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.deviceInput.device];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                       ofObject:(id)object
                         change:(NSDictionary*)change
                        context:(void*)context {
    if (context == SessionRunningContext) {
        BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        if (self.onSessionStateChanged) {
            self.onSessionStateChanged(isSessionRunning);
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification*)notification {
    CGPoint devicePoint = CGPointMake(0.5, 0.5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

@end
