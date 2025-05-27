//
//  SnappySlider.m
//  snappyslider
//
//  Created by Aaron Brethorst on 3/13/11.
//  Copyright (c) 2011 Aaron Brethorst
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------ ^^ Original license message ------------------------
//
// This version of SnappySlider is modified to allow for full range of motion, but
// to just "stick" for a second at the detents.
//
// Modified and ported to Swift by Ben Baron, original license applies.
//

import UIKit

final class SnappySlider: UISlider {
    var snapDistance: Float = 0
    var detents = [Float]() {
        didSet { detents = detents.sorted() }
    }
    
    override func setValue(_ value: Float, animated: Bool) {
        var bestDistance = Float.greatestFiniteMagnitude
        var bestFit = Float.greatestFiniteMagnitude
        
        for detent in detents {
            let distance = abs(detent - value)
            if distance < bestDistance {
                bestFit = detent
                bestDistance = distance
            }
        }
        
        let finalValue = bestDistance <= snapDistance ? bestFit : value
        super.setValue(finalValue, animated: animated)
    }
}

