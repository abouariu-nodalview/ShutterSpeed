//
//  CameraController.m
//  ShutterSpeed
//
//  Created by Andrei Bouariu on 18/01/2021.
//

#import "CameraController.h"
#import "AVCamPreviewView.h"
#import "CameraViewModel.h"

@interface CameraController ()

// Outlets
@property (nonatomic, weak) IBOutlet AVCamPreviewView* previewView;
@property (nonatomic, weak) IBOutlet UIButton *shootButton;
@property (nonatomic, weak) IBOutlet UIImageView *previewImageView;

// View model
@property (nonatomic, strong) CameraViewModel *viewModel;

@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

@end

@implementation CameraController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureViewModel];
    [self configurePreview];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.viewModel startSession];
}

- (void)configureViewModel {
    self.viewModel = [[CameraViewModel alloc] init];
    [self.viewModel configure];
    __weak typeof (self) weakSelf = self;
    self.viewModel.onVideoOrientationChanged = ^(AVCaptureVideoOrientation orientation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.previewView.videoPreviewLayer.connection.videoOrientation = orientation;
        });
    };
    self.viewModel.onAuthorizationStatusEvent = ^(AVCamSetupResult setupResult) {
        switch (setupResult) {
            case AVCamSetupResultSuccess: {
                break;
            }
            case AVCamSetupResultCameraNotAuthorized: {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString* message = NSLocalizedString(@"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera");
                    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Alert OK button") style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    // Provide quick access to Settings.
                    UIAlertAction* settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", @"Alert button to open Settings") style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }];
                    [alertController addAction:settingsAction];
                    [weakSelf presentViewController:alertController animated:YES completion:nil];
                });
                break;
            }
            case AVCamSetupResultSessionConfigurationFailed: {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString* message = NSLocalizedString(@"Unable to capture media", @"Alert message when something goes wrong during capture session configuration");
                    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Alert OK button") style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [weakSelf presentViewController:alertController animated:YES completion:nil];
                });
                break;
            }
        }
    };
    self.viewModel.onSessionStateChanged = ^(BOOL sessionRunning) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.shootButton.enabled = sessionRunning;
        });
    };
    self.viewModel.onStartedShooting = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.shootButton.enabled = NO;
        });
    };
    self.viewModel.onFinishedShooting = ^() {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.previewImageView.image = nil;
            weakSelf.shootButton.enabled = YES;
        });
    };
    self.viewModel.onBrackedProcessed = ^(UIImage *image) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.previewImageView.image = image;
        });
    };
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.viewModel stopSession];
    [super viewDidDisappear:animated];
}

- (void)configurePreview {
    NSAssert(self.viewModel.session, @"Camera session not initialized");
    self.previewView.session = self.viewModel.session;
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
    [self.tapGestureRecognizer addTarget:self action:@selector(focusAndExposeTap:)];
    [self.previewView addGestureRecognizer:self.tapGestureRecognizer];
}

- (void)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint devicePoint = [self.previewView.videoPreviewLayer captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
    [self.viewModel focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (IBAction)shootButtonTouched:(id)sender {
    [self.viewModel capturePhotoWithOrientation:self.previewView.videoPreviewLayer.connection.videoOrientation];
}

@end
