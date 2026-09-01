import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/location_accuracy_service.dart';
import 'map_location_picker_screen.dart';

class SavedAddressesScreen extends StatelessWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Saved Addresses', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: auth.addresses.length,
              itemBuilder: (ctx, i) {
                final addr = auth.addresses[i];
                final isSelected = auth.selectedAddress.id == addr.id;
                
                return GestureDetector(
                  onTap: () => auth.selectAddress(addr.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected 
                          ? Border.all(color: const Color(0xFF4F46E5), width: 2)
                          : Border.all(color: Colors.transparent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFF4F46E5).withOpacity(0.1)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            addr.label == 'Home' ? Icons.home_rounded : 
                            addr.label == 'Work' ? Icons.work_rounded : Icons.location_on_rounded,
                            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                addr.label,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                addr.address,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5))
                        else
                          Row(children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                              onPressed: () => _showAddAddressSheet(context, existing: addr),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                              onPressed: () => auth.removeAddress(addr.id),
                            ),
                          ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final lastPos = LocationAccuracyService.lastKnownAccuratePosition;
                    final initialLoc = (lastPos != null && lastPos.latitude != 0.0)
                        ? LatLng(lastPos.latitude, lastPos.longitude)
                        : (auth.selectedAddress.lat != null && auth.selectedAddress.lat != 0.0
                            ? LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!)
                            : null);
                    final initialAddr = (LocationAccuracyService.lastKnownAddress != null && LocationAccuracyService.lastKnownAddress!.isNotEmpty)
                        ? LocationAccuracyService.lastKnownAddress!
                        : (auth.address.isNotEmpty ? auth.address : null);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapLocationPickerScreen(
                          initialLocation: initialLoc,
                          initialAddress: initialAddr,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Add New Address on Map', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context, {UserAddress? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label);
    final addressCtrl = TextEditingController(text: existing?.address);
    double? detectedLat = existing?.lat;
    double? detectedLng = existing?.lng;
    bool isResolvingGps = false;
    String gpsStatus = existing != null ? 'GPS location loaded' : 'Waiting to resolve GPS...';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSheet) {
          Future<void> resolveGps() async {
            setStateSheet(() {
              gpsStatus = 'Resolving GPS location...';
              isResolvingGps = true;
            });
            try {
              final isEnabled = await Geolocator.isLocationServiceEnabled();
              if (!isEnabled) {
                setStateSheet(() {
                  gpsStatus = 'GPS is turned off on device!';
                  isResolvingGps = false;
                });
                return;
              }
              var permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
                if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                  setStateSheet(() {
                    gpsStatus = 'Location permission denied!';
                    isResolvingGps = false;
                  });
                  return;
                }
              }
              if (permission == LocationPermission.deniedForever) {
                setStateSheet(() {
                  gpsStatus = 'Location permission denied forever!';
                  isResolvingGps = false;
                });
                return;
              }
              final pos = await LocationAccuracyService.getBestPosition(
                targetAccuracyMeters: 20,
                maxUsableAccuracyMeters: 100,
                quickFixTimeout: const Duration(seconds: 3),
                refineTimeout: const Duration(seconds: 5),
              );
              if (pos == null) {
                setStateSheet(() {
                  gpsStatus = 'Unable to get current GPS location';
                  isResolvingGps = false;
                });
                return;
              }
              final resolvedPos = pos;
              setStateSheet(() {
                detectedLat = resolvedPos.latitude;
                detectedLng = resolvedPos.longitude;
                gpsStatus = 'GPS Location resolved successfully';
                isResolvingGps = false;
              });
            } catch (e) {
              setStateSheet(() {
                gpsStatus = 'Failed to get GPS: $e';
                isResolvingGps = false;
              });
            }
          }

          if (existing == null && detectedLat == null && !isResolvingGps && gpsStatus == 'Waiting to resolve GPS...') {
            isResolvingGps = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => resolveGps());
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add New Address' : 'Edit Address', 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Label (e.g. Home, Work)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Full Address',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      detectedLat != null ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                      color: detectedLat != null ? const Color(0xFF10B981) : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gpsStatus,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: detectedLat != null ? const Color(0xFF10B981) : Colors.orange,
                        ),
                      ),
                    ),
                    if (gpsStatus.contains('denied') || gpsStatus.contains('off') || gpsStatus.contains('Failed'))
                      TextButton(
                        onPressed: () => resolveGps(),
                        child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (labelCtrl.text.isNotEmpty && addressCtrl.text.isNotEmpty) {
                        final provider = Provider.of<AuthProvider>(context, listen: false);
                        if (existing == null) {
                          provider.addAddress(
                            UserAddress(
                              id: 'a${DateTime.now().millisecondsSinceEpoch}',
                              label: labelCtrl.text,
                              address: addressCtrl.text,
                              lat: detectedLat,
                              lng: detectedLng,
                            ),
                          );
                        } else {
                          provider.updateAddress(
                            existing.id,
                            UserAddress(
                              id: existing.id,
                              label: labelCtrl.text,
                              address: addressCtrl.text,
                              lat: detectedLat ?? existing.lat,
                              lng: detectedLng ?? existing.lng,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(existing == null ? 'Save Address' : 'Update Address', 
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
