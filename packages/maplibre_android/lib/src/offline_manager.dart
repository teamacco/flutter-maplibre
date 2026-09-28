import 'dart:async';
import 'dart:convert';

import 'package:jni/jni.dart';
import 'package:maplibre_android/src/extensions.dart';
import 'package:maplibre_android/src/functions.dart';
import 'package:maplibre_android/src/jni.g.dart' as jni;
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// MapLibre Android specific implementation of the [OfflineManager].
class OfflineManagerAndroid implements OfflineManager {
  const OfflineManagerAndroid._(this._jManager);

  final jni.OfflineManager _jManager;

  /// Create a new [OfflineManager].
  static Future<OfflineManager> createInstance() async => using((arena) async {
    final jContext = getJContext();
    jni.MapLibre.getInstance(jContext);
    final jManager = jni.OfflineManager.getInstance(jContext);
    return OfflineManagerAndroid._(jManager);
  });

  @override
  void dispose() {
    if (!_jManager.isReleased) _jManager.release();
  }

  @override
  Future<List<OfflineRegion>> mergeOfflineRegions({
    required String path,
  }) async => using((arena) async {
    final completer = Completer<List<OfflineRegion>>();
    _jManager.mergeOfflineRegions(
      path.toJString()..releasedBy(arena),
      jni.OfflineManager$MergeOfflineRegionsCallback.implement(
        _MergeOfflineRegionsCallback(completer),
      ),
    );
    return completer.future;
  });

  @override
  Future<OfflineRegion> getOfflineRegion({required int regionId}) async {
    final completer = Completer<OfflineRegion>();
    _jManager.getOfflineRegion(
      regionId,
      jni.OfflineManager$GetOfflineRegionCallback.implement(
        _GetOfflineRegionCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  void setOfflineTileCountLimit({required int amount}) =>
      _jManager.offlineMapboxTileCountLimit = amount;

  @override
  Future<void> setMaximumAmbientCacheSize({required int bytes}) async {
    final completer = Completer<void>();
    _jManager.setMaximumAmbientCacheSize(
      bytes,
      jni.OfflineManager$FileSourceCallback.implement(
        _FileSourceCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> clearAmbientCache() async {
    final completer = Completer<void>();
    _jManager.clearAmbientCache(
      jni.OfflineManager$FileSourceCallback.implement(
        _FileSourceCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> invalidateAmbientCache() async {
    final completer = Completer<void>();
    _jManager.invalidateAmbientCache(
      jni.OfflineManager$FileSourceCallback.implement(
        _FileSourceCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> packDatabase() async {
    final completer = Completer<void>();
    _jManager.packDatabase(
      jni.OfflineManager$FileSourceCallback.implement(
        _FileSourceCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> resetDatabase() async {
    final completer = Completer<void>();
    _jManager.resetDatabase(
      jni.OfflineManager$FileSourceCallback.implement(
        _FileSourceCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  void runPackDatabaseAutomatically({required bool enabled}) =>
      _jManager.runPackDatabaseAutomatically(enabled);

  @override
  Future<List<OfflineRegion>> listOfflineRegions() async {
    final completer = Completer<List<OfflineRegion>>();
    _jManager.listOfflineRegions(
      jni.OfflineManager$ListOfflineRegionsCallback.implement(
        _ListOfflineRegionsCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  Future<void> deleteRegion({required int regionId}) async {
    final completer = Completer<void>();
    _jManager.getOfflineRegion(
      regionId,
      jni.OfflineManager$GetOfflineRegionCallback.implement(
        _GetAndDeleteOfflineRegionCallback(completer),
      ),
    );
    return completer.future;
  }

  @override
  Stream<DownloadProgress> downloadRegion({
    required String mapStyleUrl,
    required LngLatBounds bounds,
    required double minZoom,
    required double maxZoom,
    required double pixelDensity,
    Map<String, Object?> metadata = const {},
  }) {
    // L'arène ne couvre que l'appel de création : les callbacks arrivent plus
    // tard, quand elle est déjà libérée. Ce qui doit leur survivre est tenu par
    // la session. Relâcher le proxy est sûr, le natif garde sa propre référence.
    final session = _DownloadSession();
    using((arena) {
      final jDefinition = jni.OfflineTilePyramidRegionDefinition(
        mapStyleUrl.toJString()..releasedBy(arena),
        bounds.toJLatLngBounds(arena: arena),
        minZoom,
        maxZoom,
        pixelDensity,
      );

      // convert the Map to a Java byte Array
      final metadataJson = jsonEncode(metadata);

      _jManager.createOfflineRegion(
        jDefinition.as(jni.OfflineRegionDefinition.type)..releasedBy(arena),
        JByteArray.of(utf8.encode(metadataJson))..releasedBy(arena),
        jni.OfflineManager$CreateOfflineRegionCallback.implement(
          _CreateOfflineRegionCallback(session),
        )..releasedBy(arena),
      );
    });
    return session.stream;
  }
}

/// Tient les objets natifs d'un téléchargement en cours : ils doivent survivre
/// à l'appel de création et être relâchés une seule fois, à la fin.
final class _DownloadSession {
  _DownloadSession() {
    _controller = StreamController<DownloadProgress>(onCancel: cancel);
  }

  late final StreamController<DownloadProgress> _controller;
  jni.OfflineRegion? _jRegion;
  jni.OfflineRegion$OfflineRegionObserver? _jObserver;
  OfflineRegion? _region;
  var _finished = false;

  Stream<DownloadProgress> get stream => _controller.stream;

  StreamController<DownloadProgress> get controller => _controller;

  /// La région convertie, calculée une seule fois à l'attachement.
  OfflineRegion? get region => _region;

  void attach(jni.OfflineRegion jRegion) {
    // Le flux peut avoir été annulé avant que la région ne soit créée.
    if (_finished) {
      jRegion.release();
      return;
    }
    _jRegion = jRegion;
    _region = jRegion.toOfflineRegion();
    final jObserver = jni.OfflineRegion$OfflineRegionObserver.implement(
      _OfflineRegionObserver(this),
    );
    _jObserver = jObserver;
    jRegion.observer = jObserver;
    jRegion.downloadState = jni.OfflineRegion.STATE_ACTIVE;
  }

  void finish() {
    if (_finished) return;
    _release();
    if (!_controller.isClosed) unawaited(_controller.close());
  }

  /// Appelé quand plus personne n'écoute : sans cela la région resterait active
  /// et continuerait de télécharger. Le flux se ferme de lui-même.
  void cancel() => _release();

  void _release() {
    if (_finished) return;
    _finished = true;
    if (_jRegion case final jRegion?) {
      _jRegion = null;
      if (!jRegion.isReleased) {
        jRegion.downloadState = jni.OfflineRegion.STATE_INACTIVE;
        jRegion.release();
      }
    }
    if (_jObserver case final jObserver?) {
      _jObserver = null;
      if (!jObserver.isReleased) jObserver.release();
    }
  }
}

final class _MergeOfflineRegionsCallback
    with jni.$OfflineManager$MergeOfflineRegionsCallback {
  const _MergeOfflineRegionsCallback(this.completer);

  final Completer<List<OfflineRegion>> completer;

  @override
  void onError(JString string) {
    completer.completeError(string.toDartString(releaseOriginal: true));
  }

  @override
  void onMerge(JArray<jni.OfflineRegion>? jRegions) => using((arena) {
    if (jRegions == null) {
      completer.complete([]);
      return;
    }
    jRegions.releasedBy(arena);
    final regions = List.generate(jRegions.length, (index) {
      final jRegion = jRegions[index]..releasedBy(arena);
      return jRegion.toOfflineRegion();
    });
    completer.complete(regions);
  });

  @override
  bool get onError$async => true;

  @override
  bool get onMerge$async => true;
}

final class _GetOfflineRegionCallback
    with jni.$OfflineManager$GetOfflineRegionCallback {
  const _GetOfflineRegionCallback(this.completer);

  final Completer<OfflineRegion> completer;

  @override
  void onError(JString error) {
    completer.completeError(
      Exception(error.toDartString(releaseOriginal: true)),
    );
  }

  @override
  void onRegion(jni.OfflineRegion jRegion) {
    completer.complete(jRegion.toOfflineRegion());
  }

  @override
  void onRegionNotFound() {
    completer.completeError(Exception('Region not found'));
  }

  @override
  bool get onError$async => true;

  @override
  bool get onRegion$async => true;

  @override
  bool get onRegionNotFound$async => true;
}

final class _GetAndDeleteOfflineRegionCallback
    with jni.$OfflineManager$GetOfflineRegionCallback {
  const _GetAndDeleteOfflineRegionCallback(this.completer);

  // Référence forte : un Completer dont seul le Future est attendu serait
  // ramassé au premier GC, et le Future ne se terminerait jamais.
  final Completer<void> completer;

  @override
  void onError(JString error) {
    if (completer.isCompleted) return;
    completer.completeError(
      Exception(error.toDartString(releaseOriginal: true)),
    );
  }

  @override
  void onRegion(jni.OfflineRegion jRegion) {
    try {
      jRegion.delete(
        jni.OfflineRegion$OfflineRegionDeleteCallback.implement(
          _DeleteOfflineRegionCallback(completer),
        ),
      );
    } on Object catch (error) {
      // jni avale les exceptions des callbacks asynchrones : sans ce rattrapage
      // l'appelant attendrait indéfiniment, sans trace.
      if (!completer.isCompleted) completer.completeError(error);
    } finally {
      if (!jRegion.isReleased) jRegion.release();
    }
  }

  @override
  void onRegionNotFound() {
    if (completer.isCompleted) return;
    completer.completeError(Exception('Region not found'));
  }

  @override
  bool get onError$async => true;

  @override
  bool get onRegion$async => true;

  @override
  bool get onRegionNotFound$async => true;
}

final class _DeleteOfflineRegionCallback
    with jni.$OfflineRegion$OfflineRegionDeleteCallback {
  const _DeleteOfflineRegionCallback(this.completer);

  final Completer<void> completer;

  @override
  void onDelete() {
    if (completer.isCompleted) return;
    completer.complete();
  }

  @override
  void onError(JString string) {
    if (completer.isCompleted) return;
    completer.completeError(
      Exception(string.toDartString(releaseOriginal: true)),
    );
  }

  @override
  bool get onDelete$async => true;

  @override
  bool get onError$async => true;
}

final class _FileSourceCallback with jni.$OfflineManager$FileSourceCallback {
  const _FileSourceCallback(this.completer);

  final Completer<void> completer;

  @override
  void onError(JString error) {
    completer.completeError(
      Exception(error.toDartString(releaseOriginal: true)),
    );
  }

  @override
  void onSuccess() {
    completer.complete();
  }

  @override
  bool get onError$async => true;

  @override
  bool get onSuccess$async => true;
}

final class _ListOfflineRegionsCallback
    with jni.$OfflineManager$ListOfflineRegionsCallback {
  const _ListOfflineRegionsCallback(this.completer);

  final Completer<List<OfflineRegion>> completer;

  @override
  void onError(JString error) {
    completer.completeError(
      Exception(error.toDartString(releaseOriginal: true)),
    );
  }

  @override
  void onList(JArray<jni.OfflineRegion>? jRegions) => using((arena) {
    if (jRegions == null) {
      completer.complete([]);
      return;
    }
    jRegions.releasedBy(arena);
    final regions = List.generate(jRegions.length, (index) {
      final jRegion = jRegions[index]..releasedBy(arena);
      return jRegion.toOfflineRegion();
    });
    completer.complete(regions);
  });

  @override
  bool get onError$async => true;

  @override
  bool get onList$async => true;
}

final class _CreateOfflineRegionCallback
    with jni.$OfflineManager$CreateOfflineRegionCallback {
  const _CreateOfflineRegionCallback(this.session);

  final _DownloadSession session;

  @override
  void onCreate(jni.OfflineRegion jRegion) => session.attach(jRegion);

  @override
  void onError(JString error) {
    if (!session.controller.isClosed) {
      session.controller.addError(
        Exception(error.toDartString(releaseOriginal: true)),
      );
    }
    session.finish();
  }

  @override
  bool get onCreate$async => true;

  @override
  bool get onError$async => true;
}

final class _OfflineRegionObserver
    with jni.$OfflineRegion$OfflineRegionObserver {
  const _OfflineRegionObserver(this.session);

  final _DownloadSession session;

  @override
  void onStatusChanged(jni.OfflineRegionStatus jStatus) {
    try {
      final region = session.region;
      if (region == null) return;
      final isComplete = jStatus.isComplete;
      if (!session.controller.isClosed) {
        session.controller.add(
          DownloadProgress(
            loadedBytes: jStatus.completedResourceSize,
            loadedTiles: jStatus.completedResourceCount,
            totalTiles: jStatus.requiredResourceCount,
            totalTilesEstimated: !jStatus.isRequiredResourceCountPrecise,
            region: region,
            downloadCompleted: isComplete,
          ),
        );
      }
      if (isComplete) session.finish();
    } finally {
      if (!jStatus.isReleased) jStatus.release();
    }
  }

  @override
  void onError(jni.OfflineRegionError error) {
    try {
      // Le SDK natif ne retire pas la requête en échec et la retente : une
      // ressource lente ou un serveur momentanément indisponible remonte ici
      // sans que le téléchargement soit perdu. Seul REASON_OTHER n'est jamais
      // retenté, c'est le seul cas où arrêter la région a un sens.
      final reason = error.reason.toDartString(releaseOriginal: true);
      final isFatal =
          reason ==
          jni.OfflineRegionError.REASON_OTHER.toDartString(
            releaseOriginal: true,
          );
      if (!isFatal) return;
      if (!session.controller.isClosed) {
        session.controller.addError(
          Exception(error.message.toDartString(releaseOriginal: true)),
        );
      }
      session.finish();
    } finally {
      if (!error.isReleased) error.release();
    }
  }

  @override
  void mapboxTileCountLimitExceeded(int limit) {
    if (!session.controller.isClosed) {
      session.controller.addError(
        Exception('Tile count limit exceeded: $limit'),
      );
    }
    session.finish();
  }

  @override
  bool get onStatusChanged$async => true;

  @override
  bool get onError$async => true;

  @override
  bool get mapboxTileCountLimitExceeded$async => true;
}
