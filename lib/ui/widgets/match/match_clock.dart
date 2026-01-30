import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/match.dart' as app;
import '../../../core/constants/enums.dart';

class MatchClock extends StatefulWidget {
  final app.Match match;
  final TextStyle? style;
  final bool showSeconds;

  const MatchClock({
    super.key,
    required this.match,
    this.style,
    this.showSeconds = true,
  });

  @override
  State<MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<MatchClock> {
  Timer? _timer;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _calculateSeconds();
    if (widget.match.isClockRunning) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(MatchClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.match.isClockRunning != oldWidget.match.isClockRunning ||
        widget.match.clockStartTime != oldWidget.match.clockStartTime ||
        widget.match.accumulatedSeconds != oldWidget.match.accumulatedSeconds) {
      _calculateSeconds();
      if (widget.match.isClockRunning) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _calculateSeconds() {
    setState(() {
      _seconds = widget.match.elapsedSeconds;
    });
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds = widget.match.elapsedSeconds;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    
    if (widget.showSeconds) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return "${minutes.toString().padLeft(2, '0')}'";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.match.status == MatchStatus.scheduled && !widget.match.isClockRunning && widget.match.accumulatedSeconds == 0) {
      return const SizedBox.shrink();
    }

    final color = widget.match.isClockRunning 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatDuration(_seconds),
        style: (widget.style ?? Theme.of(context).textTheme.labelLarge)?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
