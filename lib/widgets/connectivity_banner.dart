// lib/widgets/connectivity_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivityService = Provider.of<ConnectivityService>(context);

    if (connectivityService.isConnected) {
      return SizedBox.shrink();
    }

    // If not connected, show the banner with the new style
    return Material(
      elevation: 2.0,
      child: Container(
        width: double.infinity,
        color: Color(0xFFFFF8E1),
        padding: EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),
        child: SafeArea(
          bottom: false,
          left: true,
          right: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: Colors.grey[700],
                size: 20.0,
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  'You are offline. Changes will sync once reconnected.',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
