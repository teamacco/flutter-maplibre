import Foundation
import MapLibre
import UIKit

// Update the header file for this class like this:
// cd maplibre_ios/ios/maplibre_ios/Sources/maplibre_ios/
// ./gen_swift_headers.sh

@objc(Helpers)
public class Helpers: NSObject {
    @objc public static func setValue(
        target: NSObject, field: String, value: NSObject
    ) {
        // https://developer.apple.com/documentation/objectivec/nsobject/1418139-setvalue
        target.setValue(value, forKey: field)
    }

    @objc public static func parsePredicate(raw: String) -> NSPredicate? {
        if let data = raw.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                return NSPredicate(mglJSONObject: json)
            } catch let e {
                print("Couldn't parse NSPredicate from JSON: \(e)")
                return nil
            }
        } else {
            return nil
        }
    }

    @objc public static func parseExpression(
        propertyName: String, expression: String
    ) -> NSExpression? {
        print("\(propertyName): \(expression)")
        do {
            // can't create an Expression using the default method if the data is a hex string
            if propertyName.contains("color"), expression.first == "#" {
                let color = UIColor(hexString: expression)
                return NSExpression(forConstantValue: color)
            }
            if expression.starts(with: "[") {
                // can't create an Expression if the data of a literal is an array
                let json = try JSONSerialization.jsonObject(
                    with: expression.data(using: .utf8)!,
                    options: .fragmentsAllowed
                )
                // print("json: \(json)")
                if let offset = json as? [Any] {
                    if offset.count == 2, offset.first as? String == "literal" {
                        if let vector = offset.last as? [Any] {
                            if vector.count == 2 {
                                if let x = vector.first as? Double,
                                   let y = vector.last as? Double
                                {
                                    return NSExpression(
                                        forConstantValue: NSValue(
                                            cgVector: CGVector(dx: x, dy: y)
                                        )
                                    )
                                }
                            }
                        }
                    } else if let first = offset.first, !(first is String) {
                        return NSExpression(forConstantValue: offset)
                    }
                }
                return NSExpression(mglJSONObject: json)
            }
            // parse as a constant value
            return NSExpression(forConstantValue: expression)

        } catch {
            print("Couldn't parse Expression: " + expression)
        }
        return nil
    }

    @objc public static func createOfflinePackProgressListener(
        callbacks: OfflinePackProgressCallbacks
    ) {
        NotificationCenter.default.addObserver(
            callbacks,
            selector: #selector(OfflinePackProgressCallbacks.onProgressChanged(notification:)),
            name: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            callbacks,
            selector: #selector(OfflinePackProgressCallbacks.onError(notification:)),
            name: NSNotification.Name.MLNOfflinePackError,
            object: nil
        )

        NotificationCenter.default.addObserver(
            callbacks,
            selector: #selector(OfflinePackProgressCallbacks.onMaximumAllowedTiles(notification:)),
            name: NSNotification.Name.MLNOfflinePackMaximumMapboxTilesReached,
            object: nil
        )
    }

    @objc public static func removeOfflinePackProgressListener(
        callbacks: OfflinePackProgressCallbacks
    ) {
        NotificationCenter.default.removeObserver(callbacks)
    }

    @objc public static func createTilePyramidOfflineRegion(styleURL: URL?, south: Double, west: Double, east: Double, north: Double, fromZoomLevel minZoom: Double, toZoomLevel maxZoom: Double) -> MLNTilePyramidOfflineRegion {
        MLNTilePyramidOfflineRegion(styleURL: styleURL, bounds: MLNCoordinateBounds(sw: CLLocationCoordinate2D(latitude: south, longitude: west), ne: CLLocationCoordinate2D(latitude: north, longitude: east)), fromZoomLevel: minZoom, toZoomLevel: maxZoom)
    }

    @objc public static func zoomLevelToAltitude(zoomLevel: Double, pitch: CGFloat, latitude: Double, size: CGSize) -> Double {
        MLNAltitudeForZoomLevel(zoomLevel, pitch, latitude, size)
    }

    /// Draws the map view into premultiplied RGBA pixels, rows of width * 4
    /// bytes, width and height being the bounds size multiplied by scale and
    /// rounded. The PNG encoding is left to the caller, off the main thread.
    @objc public static func takeSnapshot(mapView: MLNMapView, scale: Double) -> Data? {
        let bounds = mapView.bounds
        let width = Int((Double(bounds.width) * scale).rounded())
        let height = Int((Double(bounds.height) * scale).rounded())
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(
                x: CGFloat(width) / bounds.width,
                y: -CGFloat(height) / bounds.height
            )
            UIGraphicsPushContext(context)
            defer { UIGraphicsPopContext() }
            return mapView.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
        return drawn ? pixels : nil
    }
}

@objc(OfflinePackProgressCallbacks)
public protocol OfflinePackProgressCallbacks: AnyObject {
    @objc func onProgressChanged(notification: NSNotification)
    @objc func onError(notification: NSNotification)
    @objc func onMaximumAllowedTiles(notification: NSNotification)
}
