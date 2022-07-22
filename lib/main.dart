import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
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
  List<chart.FlSpot>? _spots;
  List<chart.FlSpot>? _fftSpots;
  List<chart.FlSpot>? _filteredSpots;
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
      audioFormat: AudioFormat.ENCODING_PCM_8BIT,
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
    // ByteData byteData = ByteData.sublistView(f);
    //
    // print({
    //   'vetor': f.sublist(0, 2),
    //   'big': byteData.getUint16(0, Endian.big),
    //   'little': byteData.getUint16(0, Endian.little),
    // });
    //
    // // ByteData byteData = ByteData.sublistView(f);
    //
    // final dataaa = List<int>.filled(f.length, 0);
    //
    // for (int i = 0; i < f.length ~/ 2; i++) {
    //   dataaa[i] = byteData.getUint16(i * 2, Endian.little);
    // }
    // print(dataaa);
    final dataaa = _calculateWaveSamples(f);
    // for (int i = 0; i < f.length ~/ 2; i++) {
    //   dataaa.add(f[i]);
    // }
    // for (int i = 0; i < f.length ~/ 2; i++) {
    //   dataaa[i] += f[i + f.length ~/ 2 - 1] << 255;
    // }

    // late List<int> dataaa;
    //    // print(bytesPerSample);
    //  if(bytesPerSample ==2 ) {
    //    dataaa = f.buffer.asUint16List();
    //  } else {
    //    dataaa = f.toList();
    //  }
    // final dataaa = f;
    // print(dataa.toSet().length);
    // return;
    //  print(data.length);
    int initialPowerOfTwo = (math.log(dataaa.length) * math.log2e).ceil();
    int samplesFinalLength = math.pow(2, initialPowerOfTwo - 1).toInt();
    final offset = 0.0; //math.pow(2, 7.0).toDouble();
    final dataa = dataaa.sublist(0, samplesFinalLength).map((e) => e - offset).toList();
    // print(dataa.length);
    // final window = List<double>.generate(
    //     dataa.length,
    //     (index) => math
    //         .exp(-40 * math.pow((index - dataa.length / 2) / dataa.length, 4)));
    // print(window);
    // var buffer = data.buffer;
    // var bytes = new ByteData.view(buffer);
    // final datas = <double>[];
    // for (int i = 0; i < data.length ~/ 2; i++) {
    //   datas.add(bytes.getUint16(2 * i) - offset);
    // }
    //   bytes.getUint16(byteOffset);

// print(boo.toSet().length);
    // print(data.toSet().length);

    // return;
    // print(data.toSet());
    // final _before = _now;
    // _now = DateTime.now();
    // print(data.length);

    // final datas = List<int>.filled(data.length ~/ 2, 0);
    // for (int i = 0; i < data.length; i += 2) {
    //   datas[i ~/ 2] = data[i] * 256 + data[i + 1];
    // }
    // print(datas.toSet().length);
    // return;
    // print(datas);

    // if (_before != null)
    //   print('dt = ${_now.difference(_before).inMicroseconds}');
    // print(data.length / _now.difference(_before).inMicroseconds);
    final foo = List<chart.FlSpot>.generate(
      dataa.length,
      (x) {
        // final y = window[x] * dataa[x];
        final y = dataa[x];
        _maxTimeValue = math.max(y, _maxTimeValue);
        _minTimeValue = math.min(y, _minTimeValue);
        return chart.FlSpot(x.toDouble(), y);
      },
    );
    if (false) {
      // int initialPowerOfTwo = (math.log(data.length) * math.log2e).ceil();
      // int samplesFinalLength = math.pow(2, initialPowerOfTwo).toInt();
      // final padding =
      //     List<double>.filled(samplesFinalLength - (data.length), 0);
      // final fftSamples = FFT()
      //     .Transform([...data.map((e) => e.toDouble()).toList(), ...padding]);
      // final boo = List<chart.FlSpot>.generate(
      //   fftSamples.length - 1,
      //   (x) {
      //     final y = fftSamples[x + 1].modulus.toDouble();
      //     _maxFFTValue = math.max(y, _maxFFTValue);
      //     return chart.FlSpot(x.toDouble(), y);
      //   },
      // );
      // setState(() {
      //   _spots = foo;
      //   _fftSpots = boo;
      // });
    }
    {
      // int initialPowerOfTwo = (math.log(datas.length) * math.log2e).ceil();
      // int samplesFinalLength = math.pow(2, initialPowerOfTwo - 1).toInt();
      final fftSamples = FFT().Transform(dataa);
      // final maxFreq = (fftSamples.length * 3660 ~/ 4000);
      // final minFerq = (fftSamples.length * 60 ~/ 4000);
      // final fftFilter = List<chart.FlSpot>.generate(
      //   fftSamples.length,
      //   (x) {
      //     double y;
      //     if (x > minFerq && x < maxFreq) {
      //       y = 1;
      //     } else {
      //       y = 0;
      //     }
      //     // _maxFFTValue = math.max(y, _maxFFTValue);
      //     return chart.FlSpot(x.toDouble(), y);
      //   },
      // );
      // print(fftFilter);
      final boo = List<chart.FlSpot>.generate(
        fftSamples.length ~/ 2,
        (x) {
          double y = fftSamples[x]!.abs();
          _maxFFTValue = math.max(y, _maxFFTValue);
          return chart.FlSpot(x.toDouble(), y);
        },
      );
      setState(() {
        _spots = foo;
        _fftSpots = boo;
      });
    }
  }

  List<int> _calculateWaveSamples(Uint8List samples) {
    if (bytesPerSample == 1)
      return samples.toList().map((element) {
        return element - 127;
      }).toList();
    bool first = true;
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
            _spots != null
                ? chart.LineChart(
                    chart.LineChartData(
                      lineBarsData: [
                        chart.LineChartBarData(
                          spots: _spots,
                        ),
                      ],
                      maxY: _maxTimeValue,
                      minY: _minTimeValue,
                    ),
                  )
                : Container(),
            _fftSpots != null
                ? chart.LineChart(
                    chart.LineChartData(
                      lineBarsData: [
                        chart.LineChartBarData(
                          spots: _fftSpots,
                        ),
                      ],
                      minY: 0,
                      maxY: _maxFFTValue,
                    ),
                  )
                : Container(),
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
