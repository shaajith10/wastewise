import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'api_client.dart';
import 'theme.dart';

/// Statuses in which a pickup can still be cancelled (mirrors the backend).
const cancellableStatuses = ['Pending', 'Assigned', 'Accepted'];

/// Statuses in which a collector can drop a task they hold.
const releasableStatuses = ['Assigned', 'Accepted'];

/// Citizen/admin: confirm, then cancel the pickup request.
/// Returns true if it was cancelled.
Future<bool> confirmCancelRequest(BuildContext context, String requestId) {
  return _confirmAndRun(
    context,
    title: 'Cancel Pickup Request?',
    message: 'This pickup request will be cancelled. If a collector has accepted it, they will be notified.',
    confirmLabel: 'Cancel Request',
    dismissLabel: 'Keep Request',
    path: '/pickup-requests/$requestId/cancel',
    successText: 'Pickup request cancelled.',
  );
}

/// Collector: confirm, then cancel an unclaimed (Pending) request outright.
/// Unlike [confirmReleaseTask], this is for a request the collector hasn't
/// accepted yet — it cancels it for everyone, not just this collector.
/// Returns true if it was cancelled.
Future<bool> confirmCancelUnclaimedRequest(BuildContext context, String requestId) {
  return _confirmAndRun(
    context,
    title: 'Cancel This Pickup Request?',
    message: "This cancels the citizen's request entirely — it will no longer be available to you or any other collector. The citizen will be notified.",
    confirmLabel: 'Cancel Request',
    dismissLabel: 'Keep Request',
    path: '/pickup-requests/$requestId/cancel',
    successText: 'Pickup request cancelled.',
  );
}

/// Collector: confirm, then drop the task so another collector can take it.
/// Returns true if it was released.
Future<bool> confirmReleaseTask(BuildContext context, String requestId) {
  return _confirmAndRun(
    context,
    title: 'Cancel This Pickup?',
    message: "You'll be removed from this task and it goes back to the open list so another collector can pick it up. The citizen will be notified.",
    confirmLabel: 'Cancel Pickup',
    dismissLabel: 'Keep Task',
    path: '/pickup-requests/$requestId/release',
    successText: 'Pickup cancelled. The task is back in the open list.',
  );
}

Future<bool> _confirmAndRun(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String dismissLabel,
  required String path,
  required String successText,
}) async {
  final ok = await showConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    dismissLabel: dismissLabel,
    danger: true,
  );
  if (!ok || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ApiClient.post(path, {});
    messenger.showSnackBar(SnackBar(content: Text(successText), backgroundColor: AppTheme.success));
    return true;
  } catch (e) {
    final msg = e is ApiException ? e.message : 'Could not reach the server.';
    messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
    return false;
  }
}
