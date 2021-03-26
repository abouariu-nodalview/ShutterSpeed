//
//  CameraEnums.h
//  ShutterSpeed
//
//  Created by Andrei Bouariu on 18/01/2021.
//

#import <Foundation/Foundation.h>

#ifndef CameraEnums_h
#define CameraEnums_h

#endif /* CameraEnums_h */

static void* SessionRunningContext = &SessionRunningContext;
static void* SystemPressureContext = &SystemPressureContext;

typedef NS_ENUM(NSInteger, AVCamSetupResult) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

typedef NS_ENUM(NSInteger, AVCamShootingOption) {
    AVCamShootingOptionBracketing,
    AVCamShootingOptionSequential
};
