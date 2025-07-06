

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

  VoiceNote copyWith({
    String? id,
    String? patientId,
    String? category,
    String? audioPath,
    String? transcription,
    String? notes,
    List<String>? tags,
    Duration? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      category: category ?? this.category,
      audioPath: audioPath ?? this.audioPath,
      transcription: transcription ?? this.transcription,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 