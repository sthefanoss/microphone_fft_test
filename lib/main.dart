import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:fft/fft.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart' as chart;
import 'package:mic_stream/mic_stream.dart';

enum Command {
  start,
  stop,
  change,
}

const AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;

void main() => runApp(MicStreamExampleApp());

class MicStreamExampleApp extends StatefulWidget {
  @override
  _MicStreamExampleAppState createState() => _MicStreamExampleAppState();
}

class _MicStreamExampleAppState extends State<MicStreamExampleApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Stream<Uint8List>? _stream;
  int page = 0;
  StreamSubscription<Uint8List>? _soundSubscription;
  final _spots = StreamController<List<chart.FlSpot>>.broadcast();
  final _fftSpots = StreamController<List<chart.FlSpot>>.broadcast();
  double _maxTimeValue = 1;
  double _maxFFTValue = 1;
  bool memRecordingState = false;
  bool isRecording = false;
  bool isActive = false;
  @override
  void initState() {
    print("Init application");
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setState(() {
      initPlatformState();
    });
  }

  // Responsible for switching between recording / idle state
  void _controlMicStream({Command command = Command.change}) async {
    switch (command) {
      case Command.change:
        _changeListening();
        break;
      case Command.start:
        _startListening();
        break;
      case Command.stop:
        _stopListening();
        break;
    }
  }

  Future<bool> _changeListening() async => !isRecording ? await _startListening() : _stopListening();

  late int bytesPerSample;
  late int samplesPerSecond;

  Future<bool> _startListening() async {
    print("START LISTENING");
    if (isRecording) return false;
    // if this is the first time invoking the microphone()
    // method to get the stream, we don't yet have access
    // to the sampleRate and bitDepth properties
    print("wait for stream");

    // Default option. Set to false to disable request permission dialogue
    MicStream.shouldRequestPermission(true);

    _stream = await MicStream.microphone(
      audioSource: AudioSource.DEFAULT,
      sampleRate: 44100,
      channelConfig: ChannelConfig.CHANNEL_IN_MONO,
      audioFormat: AudioFormat.ENCODING_PCM_16BIT,
    );
    // after invoking the method for the first time, though, these will be available;
    // It is not necessary to setup a listener first, the stream only needs to be returned first
    print(
        "Start Listening to the microphone, sample rate is ${await MicStream.sampleRate}, bit depth is ${await MicStream.bitDepth}, bufferSize: ${await MicStream.bufferSize}");
    bytesPerSample = (await MicStream.bitDepth)! ~/ 8;
    samplesPerSecond = (await MicStream.sampleRate)!.toInt();
    _maxFFTValue = 1;
    _maxTimeValue = 1;

    setState(() {
      isRecording = true;
    });
    _soundSubscription = _stream!.listen(_micListener);
    return true;
  }

  bool _mutex = false;
  void _micListener(Uint8List f) async {
    if (_mutex) return;
    _mutex = true;
    final computedData = await compute<List, List>((List f) {
      final data = _calculateWaveSamples(f[0] as Uint8List);
      double maxTimeValue = f[1];
      double maxFFTValue = f[2];
      int initialPowerOfTwo = (math.log(data.length) * math.log2e).ceil();
      int samplesFinalLength = math.pow(2, initialPowerOfTwo).toInt();
      final padding = List<double>.filled(samplesFinalLength - data.length, 0);
      final fftSamples = FFT().Transform([...data, ...padding]);
      final timeSpots = List<chart.FlSpot>.generate(data.length, (n) {
        final y = data[n];
        maxTimeValue = math.max(maxTimeValue, y);
        return chart.FlSpot(n.toDouble(), y);
      });
      final frequencySpots = List<chart.FlSpot>.generate(
        1 + fftSamples.length ~/ 2,
        (n) {
          double y = fftSamples[n]!.abs();
          maxFFTValue = math.max(maxFFTValue, y);
          return chart.FlSpot(n.toDouble(), y);
        },
      );
      return [maxTimeValue, timeSpots, maxFFTValue, frequencySpots];
    }, [f, _maxTimeValue, _maxFFTValue]);
    _mutex = false;
    _maxTimeValue = computedData[0];
    _spots.add(computedData[1]);
    _maxFFTValue = computedData[2];
    _fftSpots.add(computedData[3]);
  }

  static List<double> _calculateWaveSamples(Uint8List samples) {
    final x = List<double>.filled(samples.length ~/ 2, 0);
    const norm = 1 / (2 << 15);
    for (int i = 0; i < x.length; i++) {
      int msb = samples[i * 2 + 1];
      int lsb = samples[i * 2];
      if (msb > 128) msb -= 255;
      if (lsb > 128) lsb -= 255;
      x[i] = (lsb + msb * 128) * norm;
    }
    return x;
  }

  bool _stopListening() {
    if (!isRecording) return false;
    print("Stop Listening to the microphone");
    _soundSubscription?.cancel();

    setState(() {
      isRecording = false;
    });
    return true;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    if (!mounted) return;
    isActive = true;
  }

  Color _getBgColor() => (isRecording) ? Colors.red : Colors.cyan;
  Icon _getIcon() => (isRecording) ? Icon(Icons.stop) : Icon(Icons.keyboard_voice);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin: mic_stream :: Debug'),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _controlMicStream,
            child: _getIcon(),
            backgroundColor: _getBgColor(),
            tooltip: (isRecording) ? "Stop recording" : "Start recording",
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.broken_image),
                label: "Sound Wave",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.broken_image),
                label: "Intensity Wave",
              ),
            ],
            backgroundColor: Colors.black26,
            elevation: 20,
            currentIndex: page,
            onTap: (v) => setState(() => page = v),
          ),
          body: [
            StreamBuilder<List<chart.FlSpot>>(
              stream: _spots.stream,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
                  return Container();
                }

                return chart.LineChart(
                  chart.LineChartData(
                    lineBarsData: [
                      chart.LineChartBarData(
                        spots: snapshot.data!,
                        dotData: chart.FlDotData(show: false),
                      ),
                    ],
                    maxY: _maxTimeValue,
                    minY: -_maxTimeValue,
                  ),
                );
              },
              key: const ValueKey(0),
            ),
            StreamBuilder<List<chart.FlSpot>>(
              stream: _fftSpots.stream,
              builder: (context, snapshot) {
                if (snapshot.data == null) {
                  return Container();
                }

                return chart.LineChart(
                  chart.LineChartData(
                    lineBarsData: [
                      chart.LineChartBarData(
                        spots: snapshot.data!,
                        dotData: chart.FlDotData(show: false),
                      ),
                    ],
                    maxY: _maxFFTValue,
                    minY: 0,
                  ),
                );
              },
              key: const ValueKey(1),
            )
          ][page],
        ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      isActive = true;
      print("Resume app");

      _controlMicStream(command: memRecordingState ? Command.start : Command.stop);
    } else if (isActive) {
      memRecordingState = isRecording;
      _controlMicStream(command: Command.stop);

      print("Pause app");
      isActive = false;
    }
  }

  @override
  void dispose() {
    _soundSubscription?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
