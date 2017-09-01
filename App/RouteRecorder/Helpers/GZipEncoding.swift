import Alamofire
import Gzip

public struct GZipEncoding: ParameterEncoding {
    public static var `default`: GZipEncoding { return GZipEncoding() }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        
        guard let parameters = parameters else { return urlRequest }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
            let gzipedData = try data.gzipped()
            
            urlRequest.httpBody = gzipedData

            if urlRequest.httpBody != nil {
                urlRequest.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            }
            
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        
        return urlRequest
    }
}
