import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';

class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({
    super.key,
    this.rows = 5,
    this.timeout = const Duration(seconds: 4),
    this.timeoutTitle = 'Dane jeszcze się ładują',
    this.timeoutMessage =
        'Sprawdź połączenie i odśwież ekran. Aplikacja nie została zablokowana.',
    this.onRefresh,
  });

  final int rows;
  final Duration timeout;
  final String timeoutTitle;
  final String timeoutMessage;
  final VoidCallback? onRefresh;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer> {
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LoadingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeout != widget.timeout) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut) {
      return EmptyState(
        icon: Icons.hourglass_empty,
        title: widget.timeoutTitle,
        message: widget.timeoutMessage,
        actionLabel: 'Odśwież',
        onAction: () {
          widget.onRefresh?.call();
          _startTimer();
        },
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: widget.rows,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.panelAlt,
                borderRadius: BorderRadius.circular(8),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1500.ms, color: Colors.white12);
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() => _timedOut = false);
    } else {
      _timedOut = false;
    }
    _timer = Timer(widget.timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }
}
