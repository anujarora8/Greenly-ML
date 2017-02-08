//
//  Datasets.swift
//  CustomCamera
//
//  Created by Enoch Tam on 2017-01-28.
//  Copyright © 2017 FAYA Corporation. All rights reserved.
//

import Foundation

enum Bin : String{
    case blue = "blue_box"
    case grey = "grey_box"
    case green = "green_bin"
    case empty
}

class Datasets {
    
    var grey_box = Set<String>()
    var blue_box = Set<String>()
    var green_bin = Set<String>()
    
    init () {

    }
    
    func addToSet (bin: Bin, str: String) {
        if bin == .grey {
            self.grey_box.insert(str.lowercased())
        } else if bin == .blue {
            self.blue_box.insert(str.lowercased())
        } else if bin == .green {
            self.green_bin.insert(str.lowercased())
        }
    
    }
    
    func whichBin (str: String) -> (Bool, Bin) {
        if (self.grey_box.contains(str)) {
            print(str+":"+Bin.grey.rawValue)
            return (true, Bin.grey)
        } else if (self.blue_box.contains(str)) {
            print(str+":"+Bin.blue.rawValue)
            return (true, Bin.blue)
        } else if (self.green_bin.contains(str)) {
            print(str+":"+Bin.green.rawValue)
            return (true, Bin.green)
        }
        return (false, Bin.empty)
    }

    
}
