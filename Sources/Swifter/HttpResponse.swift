//
//  HttpResponse.swift
//  Swifter
//
//  Copyright (c) 2014-2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public enum SerializationError: Error {
    case invalidObject
    case notSupported
}

public protocol HttpResponseBodyWriter {
    func write(_ file: String.File) throws
    func write(_ data: [UInt8]) throws
    func write(_ data: ArraySlice<UInt8>) throws
}

public enum HttpResponseBody {
    
    case json(Any?)
    case html(String)
    case text(String)
    case data([UInt8])
    case custom(Any, (Any) throws -> String)
    
    func content() -> (Int, ((HttpResponseBodyWriter) throws -> Void)?) {
        do {
            switch self {
            case .json(let object):
                switch object {

                case let array as Array<Any?>:
                    let data = [UInt8](array.asJson().utf8)
                    return (data.count, {
                        try $0.write(data)
                    })

              //case let dict as Dictionary<String, Any?>:  // did this one ever work???
                case let dict as Dictionary<String, Any>:
                    let data = [UInt8](dict.asJson().utf8)
                    return (data.count, {
                        try $0.write(data)
                    })

                default:
                    let data = [UInt8]("Serialisation error: Can't convert \(object) to JSON.".utf8)
                    return (data.count, {
                        try $0.write(data)
                    })
                }
            case .text(let body):
                let data = [UInt8](body.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            case .html(let body):
                let serialised = "<html><meta charset=\"UTF-8\"><body>\(body)</body></html>"
                let data = [UInt8](serialised.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            case .data(let body):
                return (body.count, {
                    try $0.write(body)
                })
            case .custom(let object, let closure):
                let serialised = try closure(object)
                let data = [UInt8](serialised.utf8)
                return (data.count, {
                    try $0.write(data)
                })
            }
        } catch {
            let data = [UInt8]("Serialisation error: \(error)".utf8)
            return (data.count, {
                try $0.write(data)
            })
        }
    }
}

public enum HttpResponse {
    case switchProtocols([String: String], (Socket) -> Void)
    case ok(HttpResponseBody,String?)
    case created(HttpResponseBody), accepted
    case notModified
    case movedPermanently(String)
    case badRequest(HttpResponseBody?), unauthorized, forbidden, notFound
    case internalServerError
    case raw(Int, String, [String:String]?, ((HttpResponseBodyWriter) -> Void)? )
    
    func statusCode() -> Int {
        switch self {
        case .switchProtocols(_, _)   : return 101
        case .ok(_, _)                : return 200
        case .created                 : return 201
        case .accepted                : return 202
        case .movedPermanently        : return 301
        case .notModified             : return 304
        case .badRequest(_)           : return 400
        case .unauthorized            : return 401
        case .forbidden               : return 403
        case .notFound                : return 404
        case .internalServerError     : return 500
        case .raw(let code, _ , _, _) : return code
        }
    }
    
    func reasonPhrase() -> String {
        switch self {
        case .switchProtocols(_, _)    : return "Switching Protocols"
        case .ok(_, _)                 : return "OK"
        case .created                  : return "Created"
        case .accepted                 : return "Accepted"
        case .movedPermanently         : return "Moved Permanently"
        case .notModified              : return "Not Modified"
        case .badRequest(_)            : return "Bad Request"
        case .unauthorized             : return "Unauthorized"
        case .forbidden                : return "Forbidden"
        case .notFound                 : return "Not Found"
        case .internalServerError      : return "Internal Server Error"
        case .raw(_, let phrase, _, _) : return phrase
        }
    }
    
    func headers() -> [String: String] {
        var headers = ["Server" : "Swifter \(HttpServer.VERSION)"]
        switch self {
        case .switchProtocols(let switchHeaders, _):
            for (key, value) in switchHeaders {
                headers[key] = value
            }
        case .ok(let body, let hasEtag):
            if (hasEtag != nil)
            {
                headers["E-Tag"] = hasEtag!;
            }
            switch body {
            case .text(_)   : headers["Content-Type"] = "text/plain"
            case .json(_)   : headers["Content-Type"] = "application/json"
            case .html(_)   : headers["Content-Type"] = "text/html"
            case .data(_)   : headers["Content-Type"] = "application/octet-stream"
            default:break
            }
        case .movedPermanently(let location):
            headers["Location"] = location
        case .raw(_, _, let rawHeaders, _):
            if let rawHeaders = rawHeaders {
                for (k, v) in rawHeaders {
                    headers.updateValue(v, forKey: k)
                }
            }
        default:break
        }
        return headers
    }
    
    func content() -> (length: Int, write: ((HttpResponseBodyWriter) throws -> Void)?) {
        switch self {
        case .ok(let body, _) : return body.content()
        case .badRequest(let body)     : return body?.content() ?? (-1, nil)
        case .raw(_, _, _, let writer) : return (-1, writer)
        default                        : return (-1, nil)
        }
    }
    
    func socketSession() -> ((Socket) -> Void)?  {
        switch self {
        case .switchProtocols(_, let handler) : return handler
        default: return nil
        }
    }
}

/**
    Makes it possible to compare handler responses with '==', but
	ignores any associated values. This should generally be what
	you want. E.g.:
	
    let resp = handler(updatedRequest)
        if resp == .NotFound {
        print("Client requested not found: \(request.url)")
    }
*/

func ==(inLeft: HttpResponse, inRight: HttpResponse) -> Bool {
    return inLeft.statusCode() == inRight.statusCode()
}

