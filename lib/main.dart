import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:fft/fft.dart';
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
  double _minTimeValue = 0;
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

  void _micListener(Uint8List f) {
    final dataaa = _calculateWaveSamples(f);
    final dataa = dataaa.map((e) => e - 0.0).toList();
    final foo = List<chart.FlSpot>.generate(
      dataa.length,
      (x) {
        final y = dataa[x];
        _maxTimeValue = math.max(y, _maxTimeValue);
        _minTimeValue = math.min(y, _minTimeValue);
        return chart.FlSpot(x.toDouble(), y);
      },
    );
    _spots.add(foo);

    int initialPowerOfTwo = (math.log(dataaa.length) * math.log2e).ceil();
    int samplesFinalLength = math.pow(2, initialPowerOfTwo).toInt();
    final padding = List<double>.filled(samplesFinalLength - dataaa.length, 0);
    final fftSamples = FFT().Transform([...dataa, ...padding]);
    final boo = List<chart.FlSpot>.generate(
      1 + fftSamples.length ~/ 2,
      (x) {
        double y = fftSamples[x]!.abs();
        _maxFFTValue = math.max(y, _maxFFTValue);
        return chart.FlSpot(x.toDouble(), y);
      },
    );
    _fftSpots.add(boo);
  }

  List<int> _calculateWaveSamples(Uint8List samples) {
    if (bytesPerSample == 1)
      return samples.toList().map((element) {
        return element - 127;
      }).toList();
    bool first = false;
    final visibleSamples = <int>[];
    int tmp = 0;
    for (int sample in samples) {
      if (sample > 128) sample -= 255;
      if (first) {
        tmp = sample * 128;
      } else {
        tmp += sample;
        visibleSamples.add(tmp);
        tmp = 0;
      }
      first = !first;
    }
    return visibleSamples;
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
                      ),
                    ],
                    maxY: _maxTimeValue,
                    minY: _minTimeValue,
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
