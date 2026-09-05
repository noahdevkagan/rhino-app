//  ObjCExceptionCatcher.m
//  Rhino

#import "ObjCExceptionCatcher.h"

NSErrorDomain const RhinoObjCExceptionErrorDomain = @"RhinoObjCExceptionErrorDomain";

NSError * _Nullable RhinoCatchObjCException(void (NS_NOESCAPE ^block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        NSString *reason = exception.reason ?: @"";
        NSString *description = [NSString stringWithFormat:@"%@: %@", exception.name, reason];
        return [NSError errorWithDomain:RhinoObjCExceptionErrorDomain
                                   code:1
                               userInfo:@{
                                   NSLocalizedDescriptionKey: description,
                                   @"RhinoExceptionName": exception.name,
                                   @"RhinoExceptionReason": reason,
                               }];
    }
}
