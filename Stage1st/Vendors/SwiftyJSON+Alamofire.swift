import SwiftyJSON
import Alamofire

extension Alamofire.DataRequest {
    public static func swiftyJSONResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments) -> DataResponseSerializer<SwiftyJSON.JSON> {
        return DataResponseSerializer { _, response, data, error in
            let jsonObjectResult = Request.serializeResponseJSON(options: options, response: response, data: data, error: error)
            switch jsonObjectResult {
            case let .success(jsonObject):
                return .success(JSON(jsonObject: jsonObject))
            case let .failure(error):
                return .failure(error)
            }
        }
    }

    @discardableResult
    public func responseSwiftyJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: @escaping (DataResponse<SwiftyJSON.JSON>) -> Void
    ) -> Self {
        return response(
            queue: queue,
            responseSerializer: DataRequest.swiftyJSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}
