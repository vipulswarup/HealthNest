import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final Uuid _uuid = Uuid();
  
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _currentRecordingPath;
  StreamSubscription<RecordState>? _recordingSubscription;

  // Initialize speech recognition
  Future<void> initialize() async {
    try {
      final bool available = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
      
      if (!available) {
        throw Exception('Speech recognition not available');
      }
    } catch (e) {
      throw Exception('Failed to initialize voice service: $e');
    }
  }

  // Start recording voice note
  Future<void> startRecording(String patientId, String category) async {
    if (_isRecording) return;

    try {
      // Get app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory voiceDir = Directory('${appDir.path}/voice_notes/$patientId');
      await voiceDir.create(recursive: true);

      // Generate unique filename
      final String fileName = '${_uuid.v4()}.m4a';
      _currentRecordingPath = '${voiceDir.path}/$fileName';

      // Start recording
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;

      // Listen to recording state changes
      _recordingSubscription = _recorder.onStateChanged().listen((state) {
        if (state == RecordState.stop) {
          _isRecording = false;
        }
      });

    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      await _recorder.stop();
      _isRecording = false;
      _recordingSubscription?.cancel();
      
      return _currentRecordingPath;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  // Transcribe audio file
  Future<String> transcribeAudio(String audioPath) async {
    if (_isTranscribing) {
      throw Exception('Transcription already in progress');
    }

    _isTranscribing = true;
    String transcribedText = '';

    try {
      // For now, we'll use a placeholder implementation
      // In a real app, you would integrate with a speech-to-text service
      // like Google Cloud Speech-to-Text, Azure Speech Services, or AWS Transcribe
      
      // Simulate transcription delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Placeholder transcription
      transcribedText = 'Transcribed text from audio file: $audioPath';
      
    } catch (e) {
      throw Exception('Failed to transcribe audio: $e');
    } finally {
      _isTranscribing = false;
    }

    return transcribedText;
  }

  // Create voice note with transcription
  Future<VoiceNote> createVoiceNote({
    required String patientId,
    required String category,
    required String audioPath,
    String? transcription,
    String? notes,
    List<String> tags = const [],
  }) async {
    try {
      final String id = _uuid.v4();
      final DateTime now = DateTime.now();

      // If no transcription provided, generate one
      String finalTranscription = transcription ?? '';
      if (finalTranscription.isEmpty) {
        finalTranscription = await transcribeAudio(audioPath);
      }

      return VoiceNote(
        id: id,
        patientId: patientId,
        category: category,
        audioPath: audioPath,
        transcription: finalTranscription,
        notes: notes,
        tags: tags,
        duration: await _getAudioDuration(audioPath),
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      throw Exception('Failed to create voice note: $e');
    }
  }

  // Get audio duration
  Future<Duration> _getAudioDuration(String audioPath) async {
    try {
      final File audioFile = File(audioPath);
      if (await audioFile.exists()) {
        // In a real implementation, you would use a library like just_audio
        // to get the actual duration of the audio file
        return const Duration(minutes: 2); // Placeholder duration
      }
      return Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  // Get voice notes for a patient
  Future<List<VoiceNote>> getVoiceNotes(String patientId, {String? category}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory voiceDir = Directory('${appDir.path}/voice_notes/$patientId');
      
      if (!await voiceDir.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await voiceDir.list().toList();
      final List<VoiceNote> voiceNotes = [];

      for (final file in files) {
        if (file is File && file.path.endsWith('.m4a')) {
          // In a real implementation, you would load the voice note metadata
          // from a database or JSON file
          final String fileName = file.path.split('/').last;
          final String id = fileName.replaceAll('.m4a', '');
          
          // Placeholder voice note
          final voiceNote = VoiceNote(
            id: id,
            patientId: patientId,
            category: 'consultation', // Placeholder
            audioPath: file.path,
            transcription: 'Transcribed text for $fileName',
            notes: null,
            tags: [],
            duration: await _getAudioDuration(file.path),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          if (category == null || voiceNote.category == category) {
            voiceNotes.add(voiceNote);
          }
        }
      }

      return voiceNotes;
    } catch (e) {
      throw Exception('Failed to get voice notes: $e');
    }
  }

  // Delete voice note
  Future<void> deleteVoiceNote(String voiceNoteId, String patientId) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String audioPath = '${appDir.path}/voice_notes/$patientId/$voiceNoteId.m4a';
      final File audioFile = File(audioPath);
      
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete voice note: $e');
    }
  }

  // Check if currently recording
  bool get isRecording => _isRecording;

  // Check if currently transcribing
  bool get isTranscribing => _isTranscribing;

  // Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  // Dispose resources
  void dispose() {
    _recordingSubscription?.cancel();
    _recorder.dispose();
  }
}

class VoiceNote {
  final String id;
  final String patientId;
  final String category; // consultation, symptom, medication, general
  final String audioPath;
  final String transcription;
  final String? notes;
  final List<String> tags;
  final Duration duration;
  final DateTime createdAt;
  final DateTime updatedAt;

  VoiceNote({
    required this.id,
    required this.patientId,
    required this.category,
    required this.audioPath,
    required this.transcription,
    this.notes,
    required this.tags,
    required this.duration,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'category': category,
      'audioPath': audioPath,
      'transcription': transcription,
      'notes': notes,
      'tags': tags,
      'duration': duration.inSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id'],
      patientId: json['patientId'],
      category: json['category'],
      audioPath: json['audioPath'],
      transcription: json['transcription'],
      notes: json['notes'],
      tags: List<String>.from(json['tags']),
      duration: Duration(seconds: json['duration']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
} 