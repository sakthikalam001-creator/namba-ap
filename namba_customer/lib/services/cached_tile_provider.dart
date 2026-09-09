import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// High-performance Map TileProvider with automatic persistent disk and memory caching.
/// Prevents tile reloading, eliminates gray/white squares during panning,
/// and allows smooth 60fps gestures with zero network stall for visited regions.
class CachedTileProvider extends TileProvider {
  CachedTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(
      url,
      headers: headers,
    );
  }
}
