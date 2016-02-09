//
//  Created by Dima Vartanian on 10/29/15.
//

import Foundation
import Crashlytics


// this method gives us pretty much the same functionality as the CLS_LOG macro, but written as a Swift function, the only differences are that we have to use array syntax for the argument list and that we don't get see if the method being called is a class method or an instance method. We also have to define the DEBUG compiler flag with -D SWIFT_DEBUG.
// usage:
// CLS_LOG_SWIFT()
// CLS_LOG_SWIFT("message!")
// CLS_LOG_SWIFT("message with parameter 1: %@ and 2: %@", ["First", "Second"])
func CLS_LOG_SWIFT(format: String = "",
    _ args:[CVarArgType] = [],
    file: String = __FILE__,
    function: String = __FUNCTION__,
    line: Int = __LINE__)
{
    let filename = NSURL(string:file)?.lastPathComponent?.componentsSeparatedByString(".").first
    
    #if SWIFT_DEBUG
        CLSNSLogv("\(filename).\(function) line \(line) $ \(format)", getVaList(args))
    #else
        CLSLogv("\(filename).\(function) line \(line) $ \(format)", getVaList(args))
    #endif
    
}

// CLS_LOG() output: -[ClassName methodName:] line 10 $
// CLS_LOG_SWIFT() output: ClassName.methodName line 10 $