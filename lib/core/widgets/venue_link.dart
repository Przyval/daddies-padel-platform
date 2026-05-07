import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:daddies_app/core/router/app_router.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/services/data_service.dart';

/// Navigates to a venue detail screen by looking up the venue name.
/// Shows a snackbar if the venue is not found.
void navigateToVenue(BuildContext context, String venueName) {
  final venue = DataService().getVenueByName(venueName);
  if (venue != null) {
    context.push(AppRoutes.venueDetailPath(venue.id));
  } else {
    SnackbarHelper.showInfo(context, 'Venue "$venueName" belum terdaftar di sistem');
  }
}
