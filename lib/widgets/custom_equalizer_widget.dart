import 'package:flutter/material.dart';
import 'package:sonora/providers/player_provider.dart';

class CustomEqualizerWidget extends StatefulWidget {
  final PlayerProvider playerProvider;

  const CustomEqualizerWidget({super.key, required this.playerProvider});

  @override
  State<CustomEqualizerWidget> createState() => _CustomEqualizerWidgetState();
}

class _CustomEqualizerWidgetState extends State<CustomEqualizerWidget> {
  late Future<dynamic> _paramsFuture;
  List<double> _gains = [];

  final _presets = const <String, List<double>>{
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Pop': [-0.2, 0.2, 0.5, 0.2, -0.2],
    'Rock': [0.5, 0.3, -0.3, 0.3, 0.5],
    'Jazz': [0.4, 0.2, -0.2, 0.2, 0.4],
    'Classical': [0.5, 0.3, -0.2, 0.4, 0.4],
  };

  @override
  void initState() {
    super.initState();
    _paramsFuture = widget.playerProvider.audioHandler.equalizer.parameters;
    var customGains = widget.playerProvider.customEqGains;
    if (customGains != null) {
      _gains = List.from(customGains);
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var player = widget.playerProvider;

    return FutureBuilder<dynamic>(
      future: _paramsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        var params = snapshot.data!;
        // params is AndroidEqualizerParameters
        var bands = params.bands;
        
        if (_gains.isEmpty || _gains.length != bands.length) {
          _gains = List.filled(bands.length, 0.0);
        }

        var isEqActive = player.isCustomEqEnabled;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom Equalizer',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: isEqActive,
                    onChanged: (val) {
                      if (val) {
                        player.setCustomEqBands(_gains);
                      } else {
                        player.resetAllMfx();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isEqActive)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _presets.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    var entry = _presets.entries.elementAt(index);
                    return ActionChip(
                      label: Text(entry.key),
                      onPressed: () {
                        setState(() {
                          var fractions = entry.value;
                          for (var i = 0; i < bands.length; i++) {
                            // Map bands index to 5-band fraction index
                            var mappedIndex = (i / bands.length * fractions.length).floor().clamp(0, fractions.length - 1);
                            var fraction = fractions[mappedIndex];
                            _gains[i] = fraction >= 0 
                                ? fraction * params.maxDecibels 
                                : -fraction * params.minDecibels; 
                          }
                          player.setCustomEqBands(_gains);
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Opacity(
              opacity: isEqActive ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !isEqActive,
                child: SizedBox(
                  height: 150,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(bands.length, (index) {
                      var band = bands[index];
                      var freq = band.centerFrequency;
                      var freqLabel = freq >= 1000 
                          ? '${(freq / 1000).toStringAsFixed(0)}k'
                          : '${freq.toStringAsFixed(0)}';

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Column(
                          children: [
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  value: _gains[index],
                                  min: params.minDecibels,
                                  max: params.maxDecibels,
                                  onChanged: (val) {
                                    setState(() {
                                      _gains[index] = val;
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    player.setCustomEqBands(_gains);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              freqLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
      },
    );
  }
}
