//  ObjCExceptionCatcher.h
//  Rhino
//
//  Swift cannot catch Objective-C exceptions. AVFoundation raises them from
//  installTap(onBus:) when the tap format disagrees with the hardware, and an
//  exception that unwinds through a Swift main-actor task leaves the main
//  dispatch queue wedged: the run loop keeps drawing, but no queued block ever
//  runs again (the 2026-09-05 AirPods "Connecting…" hang). Run such calls
//  through this so the exception becomes an NSError the caller can handle.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block`. Returns nil on success, or an NSError (domain
/// `RhinoObjCExceptionErrorDomain`) carrying the exception's name and reason
/// if the block raised an Objective-C exception.
NSError * _Nullable RhinoCatchObjCException(void (NS_NOESCAPE ^block)(void));

extern NSErrorDomain const RhinoObjCExceptionErrorDomain;

NS_ASSUME_NONNULL_END
