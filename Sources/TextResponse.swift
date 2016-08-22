//
//  TextResponse.swift
//  Swifter
//
//  Created by Dawid Szymczak on 15/08/16.
//  Copyright © 2016 Damian Kołakowski. All rights reserved.
//

import Foundation

public class TextResponse: Response {
    public override func content() -> (contentLength: Int, contentString: String) {
        let contentString = String(self.contentObject)
        let data = [UInt8](contentString.utf8)
        return (data.count, contentString)
    }
}