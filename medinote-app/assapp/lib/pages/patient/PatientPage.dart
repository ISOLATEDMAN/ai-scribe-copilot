// patient_page_with_bloc.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:assapp/blocs/PatientBloc/bloc/patient_handling_bloc.dart';
import 'package:assapp/services/StorageService/StorageService.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class Patientpage extends StatefulWidget {
  final String patientName;
  final String patientId;

  const Patientpage({
    super.key,
    required this.patientName,
    required this.patientId,
  });

  @override
  State<Patientpage> createState() => _PatientpageState();
}

enum RecordingState { notStarted, recording, paused, sending, finalizing, finished }

class _PatientpageState extends State<Patientpage> with WidgetsBindingObserver, TickerProviderStateMixin {
  // --- Configuration ---
  final String baseUrl = dotenv.env["BASE_API"] ?? "http://localhost:3000";
  late final String _serverBaseUrl;
  final storageService = StorageService();
  final Dio _dio = Dio();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // --- State Variables ---
  String? _authToken;
  RecordingState _recordingState = RecordingState.notStarted;
  List<String> _transcripts = [];
  String? _finalTranscript;
  String? _sessionId;
  int _chunkCounter = 0;
  Timer? _chunkUploadTimer;
  String? _currentChunkPath;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _serverBaseUrl = '$baseUrl/v1';
    _initializeAuthToken();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeAuthToken() async {
    final token = await storageService.getToken();
    if (mounted) {
      setState(() => _authToken = token);
    }
  }

  @override
  void dispose() {
    _chunkUploadTimer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    log('App Lifecycle State: $state');
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_recordingState == RecordingState.recording) {
          _autoPauseRecording();
        }
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }
  
  Future<void> _autoPauseRecording() async {
    if (_recordingState != RecordingState.recording) return;

    log('App is backgrounded. Auto-pausing recording...');
    _chunkUploadTimer?.cancel();
    await _audioRecorder.pause();
    _pulseController.stop();
    _waveController.stop();
    if (mounted) {
      setState(() => _recordingState = RecordingState.paused);
    }
  }

  // --- Core Recording Logic ---

  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission() || _authToken == null) {
      log('No permission or auth token is missing.');
      return;
    }

    setState(() => _recordingState = RecordingState.sending);

    try {
      final response = await _dio.post(
        '$_serverBaseUrl/upload-session',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
        data: {'patientId': widget.patientId},
      );
      _sessionId = response.data['id'];

      await _startNewChunkRecording();

      _chunkUploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _processAndUploadChunk(isLast: false);
      });

      setState(() {
        _recordingState = RecordingState.recording;
        _transcripts = [];
        _finalTranscript = null;
      });
      
      // Start animations
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      
    } catch (e) {
      log('Error starting recording session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not start session'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetState();
    }
  }

  Future<void> _startNewChunkRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    _currentChunkPath = '${dir.path}/chunk_${_chunkCounter++}.wav';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: _currentChunkPath!,
    );
  }

  Future<void> _processAndUploadChunk({required bool isLast}) async {
    final recordingPath = await _audioRecorder.stop();
    if (recordingPath == null) return;

    final chunkNumberToUpload = _chunkCounter - 1;

    final file = File(recordingPath);
    if (!await file.exists() || await file.length() == 0) {
        log('Chunk file is empty or does not exist for index: $chunkNumberToUpload');
        if (!isLast) await _startNewChunkRecording();
        return;
    }

    if (!isLast) {
      await _startNewChunkRecording();
    }
    
    await _uploadAudioChunk(file, chunkNumberToUpload, isLast: isLast);
  }

  Future<void> _togglePauseResume() async {
    if (_recordingState == RecordingState.recording) {
      _chunkUploadTimer?.cancel();
      await _audioRecorder.pause();
      _pulseController.stop();
      _waveController.stop();
      setState(() => _recordingState = RecordingState.paused);
    } else if (_recordingState == RecordingState.paused) {
      _chunkUploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _processAndUploadChunk(isLast: false);
      });
      await _audioRecorder.resume();
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      setState(() => _recordingState = RecordingState.recording);
    }
  }

  Future<void> _endRecording() async {
    setState(() => _recordingState = RecordingState.finalizing);
    _chunkUploadTimer?.cancel();
    _pulseController.stop();
    _waveController.stop();
    await _processAndUploadChunk(isLast: true);
    if (mounted) {
      setState(() => _recordingState = RecordingState.finished);
    }
  }

  Future<void> _uploadAudioChunk(File audioFile, int chunkNumberForUpload, {required bool isLast}) async {
    if (_sessionId == null) return;
    
    try {
      final presignedUrlResponse = await _dio.post(
        '$_serverBaseUrl/get-presigned-url',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
        data: {
          'sessionId': _sessionId,
          'chunkNumber': chunkNumberForUpload,
          'mimeType': 'audio/wav',
        },
      );
      final presignedUrl = presignedUrlResponse.data['presignedUrl'];
      final gcsPath = presignedUrlResponse.data['gcsPath'];

      await _dio.put(
        presignedUrl,
        data: audioFile.openRead(),
        options: Options(headers: {
          'Content-Type': 'audio/wav',
          'Content-Length': await audioFile.length(),
        }),
      );

      final notifyResponse = await _dio.post(
        '$_serverBaseUrl/notify-chunk-uploaded',
        options: Options(headers: {'Authorization': 'Bearer $_authToken'}),
        data: {'sessionId': _sessionId, 'gcsPath': gcsPath, 'isLast': isLast},
      );
      
      if (notifyResponse.data['isFinal'] == true) {
         if (mounted) {
          setState(() {
            _finalTranscript = notifyResponse.data['transcript'] as String?;
            _transcripts.clear();
          });
        }
      } else {
        final transcript = notifyResponse.data['transcript'] as String?;
        if (mounted && transcript != null && transcript.isNotEmpty) {
          setState(() => _transcripts.add(transcript));
        }
      }
    } catch (e) {
      log('Error uploading chunk $chunkNumberForUpload: $e');
      if (mounted) {
        setState(() => _transcripts.add('[Error receiving transcript]'));
      }
    } finally {
      await audioFile.delete();
    }
  }
  
  // Updated method to use BLoC for saving transcript
  Future<void> _saveTranscriptToServer() async {
    if (_sessionId == null || _finalTranscript == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transcript to save.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Use BLoC to save transcript
    context.read<PatientHandlingBloc>().add(SaveTranscriptEvent(
      patientId: widget.patientId,
      sessionId: _sessionId!,
      transcript: _finalTranscript!,
    ));
  }
  
  void _resetState() {
    _chunkUploadTimer?.cancel();
    _pulseController.stop();
    _waveController.stop();
    if(mounted) {
      setState(() {
        _recordingState = RecordingState.notStarted;
        _sessionId = null;
        _chunkCounter = 0;
        _transcripts = [];
        _finalTranscript = null;
      });
    }
  }

  // --- UI Build Methods ---
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patientName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Recording Session',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor().withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: BlocListener<PatientHandlingBloc, PatientHandlingState>(
          listener: (context, state) {
            if (state is TranscriptSavedState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Transcript saved successfully!'),
                    ],
                  ),
                  backgroundColor: Colors.green.shade500,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
              _resetState();
            } else if (state is PatientErrorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Error: ${state.message}')),
                    ],
                  ),
                  backgroundColor: Colors.red.shade500,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          },
          child: Column(
            children: [
              // Recording Visualization Area
              _buildRecordingVisualization(),
              
              // Transcript Area
              Expanded(child: _buildTranscriptArea()),
              
              // Control Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      offset: Offset(0, -4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: BlocBuilder<PatientHandlingBloc, PatientHandlingState>(
                  builder: (context, state) {
                    if (state is TranscriptSavingState) {
                      return Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Saving transcript...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    }
                    return _buildControlButtons();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingVisualization() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Center(
        child: _buildMicrophoneIcon(),
      ),
    );
  }

  Widget _buildMicrophoneIcon() {
    if (_recordingState == RecordingState.recording) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade200,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 50,
              ),
            ),
          );
        },
      );
    } else if (_recordingState == RecordingState.paused) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.orange.shade500,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade200,
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(
          Icons.pause,
          color: Colors.white,
          size: 50,
        ),
      );
    } else {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic_off,
          color: Colors.grey.shade600,
          size: 50,
        ),
      );
    }
  }

  Widget _buildTranscriptArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.text_fields,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Transcript',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (_finalTranscript != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Final',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildTranscriptContent()),
        ],
      ),
    );
  }

  Widget _buildTranscriptContent() {
    if (_finalTranscript != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade50,
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Text(
            _finalTranscript!,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      );
    }

    if (_recordingState == RecordingState.notStarted && _transcripts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_off_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to record',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the record button to start capturing audio',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade50,
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ListView.separated(
        itemCount: _transcripts.length,
        separatorBuilder: (context, index) => Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          height: 1,
          color: Colors.grey.shade100,
        ),
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 8, right: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  _transcripts[index],
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlButtons() {
    switch (_recordingState) {
      case RecordingState.notStarted:
        return _buildStartButton();
      case RecordingState.recording:
      case RecordingState.paused:
        return _buildRecordingControls();
      case RecordingState.sending:
        return _buildLoadingState('Initializing session...');
      case RecordingState.finalizing:
        return _buildLoadingState('Finalizing recording...');
      case RecordingState.finished:
        return _buildFinishedControls();
    }
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _startRecording,
        icon: const Icon(Icons.fiber_manual_record, size: 24),
        label: const Text(
          'Start Recording',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _togglePauseResume,
              icon: Icon(
                _recordingState == RecordingState.recording ? Icons.pause : Icons.play_arrow,
                size: 24,
              ),
              label: Text(
                _recordingState == RecordingState.recording ? 'Pause' : 'Resume',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _endRecording,
              icon: const Icon(Icons.stop, size: 24),
              label: const Text(
                'Stop',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(String message) {
    return Column(
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedControls() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _resetState,
              icon: const Icon(Icons.delete_outline, size: 24),
              label: const Text(
                'Discard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _saveTranscriptToServer,
              icon: const Icon(Icons.save_alt, size: 24),
              label: const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_recordingState) {
      case RecordingState.notStarted:
        return Colors.grey.shade500;
      case RecordingState.recording:
        return Colors.red.shade500;
      case RecordingState.paused:
        return Colors.orange.shade500;
      case RecordingState.sending:
      case RecordingState.finalizing:
        return Colors.blue.shade500;
      case RecordingState.finished:
        return Colors.green.shade500;
    }
  }

  String _getStatusText() {
    switch (_recordingState) {
      case RecordingState.notStarted:
        return 'Ready';
      case RecordingState.recording:
        return 'Recording';
      case RecordingState.paused:
        return 'Paused';
      case RecordingState.sending:
        return 'Starting';
      case RecordingState.finalizing:
        return 'Processing';
      case RecordingState.finished:
        return 'Complete';
    }
  }
}