// services/backgroundService/BackgroundService.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // --- Service state variables ---
  final String baseUrl = dotenv.env["BASE_API"] ?? "http://localhost:3000";
  final String serverBaseUrl = '$baseUrl/v1';
  final Dio dio = Dio();
  final AudioRecorder audioRecorder = AudioRecorder();
  
  String? sessionId;
  int chunkCounter = 0;
  Timer? chunkUploadTimer;
  String? patientId;
  String? authToken;
  String? currentChunkPath;
  bool isRecording = false;

  // --- Helper functions ---
  Future<void> _startNewChunkRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      currentChunkPath = '${dir.path}/chunk_${chunkCounter++}.wav';
      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, 
          sampleRate: 16000, 
          numChannels: 1
        ),
        path: currentChunkPath!,
      );
      log('Started new chunk recording: $currentChunkPath');
    } catch (e) {
      log('Error starting chunk recording: $e');
      service.invoke('update', {'error': 'Failed to start recording chunk'});
    }
  }

  Future<void> _uploadAudioChunk(File audioFile, int chunkNumber, {required bool isLast}) async {
    if (sessionId == null || authToken == null) {
      log('Session ID or auth token is null');
      return;
    }
    
    try {
      log('Uploading chunk $chunkNumber, isLast: $isLast');
      
      // Get presigned URL
      final presignedUrlResponse = await dio.post(
        '$serverBaseUrl/get-presigned-url',
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
        data: {
          'sessionId': sessionId,
          'chunkNumber': chunkNumber,
          'mimeType': 'audio/wav', // Fixed: was missing mimeType
        },
      );
      
      final presignedUrl = presignedUrlResponse.data['presignedUrl']; // Fixed: correct field name
      final gcsPath = presignedUrlResponse.data['gcsPath']; // Fixed: get gcsPath
      
      // Upload to presigned URL
      await dio.put(
        presignedUrl,
        data: audioFile.openRead(),
        options: Options(headers: {
          'Content-Type': 'audio/wav',
          'Content-Length': await audioFile.length(), // Added content length
        }),
      );

      // Notify server of upload completion
      final notifyResponse = await dio.post(
        '$serverBaseUrl/notify-chunk-uploaded',
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
        data: {
          'sessionId': sessionId, 
          'gcsPath': gcsPath, // Fixed: use gcsPath instead of chunkNumber
          'isLast': isLast
        },
      );

      // Send transcript back to UI
      service.invoke('update', {
        'isFinal': notifyResponse.data['isFinal'] == true,
        'transcript': notifyResponse.data['transcript'] ?? '',
      });
      
      log('Successfully uploaded chunk $chunkNumber');
    } catch (e) {
      log('Error uploading chunk $chunkNumber: $e');
      service.invoke('update', {
        'transcript': '[Error receiving transcript]',
        'error': 'Upload failed for chunk $chunkNumber'
      });
    } finally {
      // Clean up the file
      try {
        await audioFile.delete();
      } catch (e) {
        log('Error deleting file: $e');
      }
    }
  }

  Future<void> _processAndUploadChunk({required bool isLast}) async {
    try {
      final recordingPath = await audioRecorder.stop();
      if (recordingPath == null) {
        log('Recording path is null');
        return;
      }

      final chunkNumberToUpload = chunkCounter - 1;
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
      
      if (isLast) {
        log('Final chunk processed, stopping service');
        isRecording = false;
        service.invoke('update', {'state': 'finished'});
        // Don't immediately stop service, let UI handle it
      }
    } catch (e) {
      log('Error processing chunk: $e');
      service.invoke('update', {'error': 'Failed to process recording chunk'});
    }
  }

  // --- Service event listeners ---
  
  service.on('start').listen((event) async {
    log('Background service received start command');
    
    patientId = event?['patientId'];
    authToken = event?['authToken'];
    
    if (patientId == null || authToken == null) {
      log('Missing patientId or authToken');
      service.invoke('update', {'error': 'Missing patient ID or auth token'});
      return;
    }

    if (!await audioRecorder.hasPermission()) {
      log('No audio recording permission');
      service.invoke('update', {'error': 'No audio recording permission'});
      return;
    }

    try {
      // Start recording session
      service.invoke('update', {'state': 'initializing'});
      
      final response = await dio.post(
        '$serverBaseUrl/upload-session',
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
        data: {'patientId': patientId},
      );
      
      sessionId = response.data['id'];
      log('Created session: $sessionId');

      // Start first chunk
      await _startNewChunkRecording();

      // Start periodic timer
      chunkUploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (isRecording) {
          _processAndUploadChunk(isLast: false);
        }
      });

      isRecording = true;
      service.invoke('update', {'state': 'recording'});
      log('Recording started successfully');
      
    } catch (e) {
      log('Error starting recording session: $e');
      service.invoke('update', {'error': 'Failed to start recording session'});
    }
  });

  service.on('stop').listen((event) async {
    log('Background service received stop command');
    
    chunkUploadTimer?.cancel();
    isRecording = false;
    
    service.invoke('update', {'state': 'finalizing'});
    await _processAndUploadChunk(isLast: true);
  });

  service.on('togglePauseResume').listen((event) async {
    log('Background service received pause/resume command');
    
    try {
      if (isRecording) {
        // Pause recording
        chunkUploadTimer?.cancel();
        await audioRecorder.pause();
        isRecording = false;
        service.invoke('update', {'state': 'paused'});
        log('Recording paused');
      } else {
        // Resume recording
        await audioRecorder.resume();
        chunkUploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          if (isRecording) {
            _processAndUploadChunk(isLast: false);
          }
        });
        isRecording = true;
        service.invoke('update', {'state': 'recording'});
        log('Recording resumed');
      }
    } catch (e) {
      log('Error toggling pause/resume: $e');
      service.invoke('update', {'error': 'Failed to pause/resume recording'});
    }
  });

  service.on('forceStop').listen((event) {
    log('Force stopping background service');
    chunkUploadTimer?.cancel();
    audioRecorder.dispose();
    service.stopSelf();
  });
}