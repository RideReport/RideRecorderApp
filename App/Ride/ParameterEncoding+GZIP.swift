// Actual gizipping from https://github.com/1024jp/NSData-GZIP

// Example: ParameterEncoding.JSON.gzipped

import Alamofire

infix operator • { associativity left }
func • <A, B, C>(f: B -> C, g: A -> B) -> A -> C {
    return { x in f(g(x)) }
}

extension ParameterEncoding {
    
    var gzipped:ParameterEncoding {
    
        return gzip(self)
    }
    
    private func gzip(encoding:ParameterEncoding) -> ParameterEncoding {
        
        let gzipEncoding = self.gzipOrError • encoding.encode
        
        return ParameterEncoding.Custom(gzipEncoding)
    }
    
    private func gzipOrError(request:NSURLRequest, error:NSError?) -> (NSMutableURLRequest, NSError?) {
        
        let mutableRequest = request.mutableCopy() as! NSMutableURLRequest

        if error != nil {
            return (mutableRequest, error)
        }
        
        var gzipEncodingError: NSError? = nil
        
        do {
            let gzippedData = try mutableRequest.HTTPBody?.gzippedData()
            mutableRequest.HTTPBody = gzippedData
            
            if mutableRequest.HTTPBody != nil {
                mutableRequest.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            }
        } catch {
            gzipEncodingError = error as NSError
        }
        
        return (mutableRequest, gzipEncodingError)
    }
}