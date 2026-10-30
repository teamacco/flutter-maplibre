import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:maplibre_platform_interface/src/widget/inherited_model.dart';

/// The [MapController] can be used to control, update and manipulate a
/// rendered [MapLibreMap].
///
/// {@category Basic}
abstract interface class MapController {
  /// Find the [MapController] of the closest [MapLibreMap] in the widget tree.
  /// Returns null if called outside of the [MapLibreMap.children].
  static MapController? maybeOf(BuildContext context) =>
      MapLibreInheritedModel.maybeMapControllerOf(context);

  /// Find the [MapController] of the closest [MapLibreMap] in the widget tree.
  /// Throws an [StateError] if called outside of the [MapLibreMap.children].
  static MapController of(BuildContext context) =>
      maybeOf(context) ??
      (throw StateError('Unable to find an instance of MapController'));

  /// Get the [MapOptions] from [MapLibreMap.options].
  MapOptions get options;

  /// Get the [StyleController] for the map. It returns null null if
  /// accessed before [MapLibreMap.onStyleLoaded] has been called.
  StyleController? get style;

  /// Convert a latitude/longitude coordinate to a screen location in logical
  /// pixels.
  Offset toScreenLocation(Geographic lngLat);

  /// Get the latitude/longitude coordinate for a screen location in logical
  /// pixels.
  Geographic toLngLat(Offset screenLocation);

  /// Convert a latitude/longitude coordinate to a screen location in logical
  /// pixels.
  List<Offset> toScreenLocations(List<Geographic> lngLats);

  /// Get the latitude/longitude coordinate for a screen location in logical
  /// pixels.
  List<Geographic> toLngLats(List<Offset> screenLocations);

  /// Instantly move the map camera to a new location.
  Future<void> moveCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  });

  /// Animate the map camera to a new location.
  Future<void> animateCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 2),
    double webSpeed = 1.2,
    Duration? webMaxDuration,
    EdgeInsets padding = EdgeInsets.zero,
  });

  /// Move the map camera to a new location at a constant speed.
  ///
  /// Unlike [animateCamera], which flies along an arc and adjusts the zoom
  /// level on the way, the camera moves straight to its destination.
  Future<void> easeCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration duration = const Duration(seconds: 2),
    EdgeInsets padding = EdgeInsets.zero,
  });

  /// Animate the map camera to a new location.
  Future<void> fitBounds({
    required GeoBox bounds,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 2),
    double webSpeed = 1.2,
    Duration? webMaxDuration,
    Offset offset = Offset.zero,
    double webMaxZoom = double.maxFinite,
    bool webLinear = false,
    EdgeInsets padding = EdgeInsets.zero,
  });

  /// Get the current camera position on the map.
  MapCamera getCamera();

  /// Get the current camera position on the map.
  MapCamera? get camera;

  /// Whether the map stopped rendering, because [MapLibreMap.paused] is set
  /// or the map is hidden. See [MapLibreMap.paused].
  bool get isRenderingPaused;

  /// Returns the distance spanned by one logical pixel at the specified
  /// latitude and current zoom level.
  ///
  /// The distance between pixels decreases as the latitude approaches the
  /// poles. This relationship parallels the relationship between longitudinal
  /// coordinates at different latitudes.
  double getMetersPerPixelAtLatitude(double latitude);

  /// The smallest bounding box that includes the visible region.
  GeoBox getVisibleRegion();

  /// Returns an array of rendered map features that intersect with a given
  /// screen location measured in logical pixels.
  ///
  /// If [layerIds] is non-null, only features from those layers will be
  /// returned.
  ///
  /// NOTE: features may appear multiple times in query results, for example if
  /// they cross tile boundaries.
  ///
  /// Returns an empty list if either the map or underlying render surface has
  /// been destroyed.
  // TODO(mhernz): add filter parameter
  //
  // [filter] is an array of filter expressions. If provided, only features
  // that match all of the filters will be returned.
  Future<List<RenderedFeature>> featuresAtPoint(
    Offset point, {
    List<String>? layerIds,
  });

  /// Returns an array of rendered map features that intersect with a given
  /// on-screen rectangle measured in logical pixels.
  ///
  /// If [layerIds] is non-null, only features from those layers will be
  /// returned.
  ///
  /// NOTE: features may appear multiple times in query results, for example if
  /// they cross tile boundaries.
  ///
  /// Returns an empty list if either the map or underlying render surface has
  /// been destroyed.
  // TODO(mhernz): add filter parameter
  //
  // [filter] is an array of filter expressions. If provided, only features
  // that match all of the filters will be returned.
  Future<List<RenderedFeature>> featuresInRect(
    Rect rect, {
    List<String>? layerIds,
  });

  /// Captures the map as it is shown, encoded as a PNG image.
  ///
  /// The image covers the map itself. The widgets of
  /// [MapLibreMap.children] are drawn over it and are not part of it. It is
  /// the size of the map in logical pixels multiplied by [pixelRatio], which
  /// defaults to the device pixel ratio, so the capture has the resolution
  /// of the screen.
  ///
  /// Use it where a capture of the Flutter tree would not show the map, such
  /// as a bug report that captures the screen: the map draws in a texture of
  /// its own, which such a capture leaves out.
  ///
  /// Returns null before the map has drawn its first frame.
  ///
  /// The web shows the map in an HTML element rather than in a texture, and
  /// MapLibre GL JS clears its drawing buffer after each frame, so this
  /// throws an [UnsupportedError] there.
  Future<Uint8List?> takeSnapshot({double? pixelRatio});
}
