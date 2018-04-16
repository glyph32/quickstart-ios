//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import CoreGraphics
import UIKit

/// A `UIImage` category for scaling images.
extension UIImage {

  /// Returns scaled image data from the given values.
  ///
  /// - Parameters
  ///   - size: Size to scale the image to (i.e. expected size of the image in the trained model).
  ///   - componentsCount: Number of color components for the image.
  ///   - batchSize: Batch size for the image.
  /// - Returns: The scaled image data or `nil` if the image could not be scaled.
  func scaledImageData(
    with size: CGSize,
    componentsCount newComponentsCount: Int,
    batchSize: Int
    ) -> Data? {
    guard let cgImage = self.cgImage, cgImage.width > 0 else { return nil }
    let oldComponentsCount = cgImage.bytesPerRow / cgImage.width
    guard newComponentsCount <= oldComponentsCount else { return nil }

    let newWidth = Int(size.width)
    let newHeight = Int(size.height)
    let dataSize = newWidth * newHeight * oldComponentsCount
    var imageData = [UInt8](repeating: 0, count: dataSize)
    guard let context = CGContext(
      data: &imageData,
      width: newWidth,
      height: newHeight,
      bitsPerComponent: cgImage.bitsPerComponent,
      bytesPerRow: oldComponentsCount * newWidth,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
        return nil
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    let count = newWidth * newHeight * newComponentsCount * batchSize
    var scaledImageDataArray = [UInt8](repeating: 0, count: count)
    var pixelIndex = 0
    for _ in 0..<newWidth {
      for _ in 0..<newHeight {
        let pixel = imageData[pixelIndex]
        pixelIndex += 1

        // Ignore the alpha component.
        let red = (pixel >> 16) & 0xFF
        let green = (pixel >> 8) & 0xFF
        let blue = (pixel >> 0) & 0xFF
        scaledImageDataArray[pixelIndex] = red
        scaledImageDataArray[pixelIndex + 1] = green
        scaledImageDataArray[pixelIndex + 2] = blue
      }
    }
    let scaledImageData = Data(bytes: scaledImageDataArray)
    return scaledImageData
  }

  /// Returns a scaled image data array from the given values.
  ///
  /// - Parameters
  ///   - size: Size to scale the image to (i.e. expected size of the image in the trained model).
  ///   - componentsCount: Number of color components for the image.
  ///   - batchSize: Batch size for the image.
  ///   - isQuantized: Indicates whether the model uses quantization. If `true`, apply
  ///     `(value - mean) / std` to each pixel to convert the data from Int(0, 255) scale to
  ///     Float(-1, 1).
  /// - Returns: The scaled image data array or `nil` if the image could not be scaled.
  func scaledImageData(
    with size: CGSize,
    componentsCount newComponentsCount: Int,
    batchSize: Int,
    isQuantized: Bool
    ) -> [Any]? {
    guard let cgImage = self.cgImage, cgImage.width > 0 else { return nil }
    let oldComponentsCount = cgImage.bytesPerRow / cgImage.width
    guard newComponentsCount <= oldComponentsCount else { return nil }

    let newWidth = Int(size.width)
    let newHeight = Int(size.height)
    let dataSize = newWidth * newHeight * oldComponentsCount * batchSize
    var imageData = [UInt8](repeating: 0, count: dataSize)
    guard let context = CGContext(
      data: &imageData,
      width: newWidth,
      height: newHeight,
      bitsPerComponent: cgImage.bitsPerComponent,
      bytesPerRow: oldComponentsCount * newWidth,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: cgImage.bitmapInfo.rawValue
      ) else {
        return nil
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

    var scaledImageData = [Any]()
    for yCoordinate in 0..<newHeight {
      var rowArray = [Any]()
      for xCoordinate in 0..<newWidth {
        var pixelArray = [Any]()
        for component in 0..<newComponentsCount {
          let inputIndex =
            (yCoordinate * newWidth * oldComponentsCount) +
              (xCoordinate * oldComponentsCount + component)
          let pixel = imageData[inputIndex]
          if isQuantized {
            pixelArray.append(pixel)
          } else {
            // Convert pixel values from [0, 255] to [-1, 1].
            let pixel = (Float32(pixel) - Constants.meanRGBValue) / Constants.stdRGBValue
            pixelArray.append(pixel)
          }
        }
        rowArray.append(pixelArray)
      }
      scaledImageData.append(rowArray)
    }
    return [scaledImageData]
  }
}

// MARK: - Fileprivate

fileprivate enum Constants {
  static let maxRGBValue: Float32 = 255.0
  static let meanRGBValue: Float32 = maxRGBValue / 2.0
  static let stdRGBValue: Float32 = maxRGBValue / 2.0
}
