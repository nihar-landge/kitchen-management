import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:string_similarity/string_similarity.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import '../models/student_model.dart';
import '../secrets.dart';

class VoiceCommandService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAvailable = false;
  
  static const String _apiKey = geminiApiKey; 
  late GenerativeModel _model;

  VoiceCommandService() {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) => print('Speech Status: $status'),
        onError: (errorNotification) => print('Speech Error: $errorNotification'),
      );
      
      await _flutterTts.setLanguage("en-IN");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
      
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ]
      );


      return _isAvailable;
    } catch (e) {
      print("Error initializing speech/TTS: $e");
      return false;
    }
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<void> listen({
    required Function(String text) onResult,
    required Function(VoiceCommand command) onCommandRecognized,
    required List<Student> students,
  }) async {
    if (!_isAvailable) {
      bool initialized = await initialize();
      if (!initialized) {
        onCommandRecognized(VoiceCommand(
          intent: VoiceIntent.unknown,
          originalText: "",
          error: "Voice recognition not available. Please check permissions."
        ));
        return;
      }
    }

    _speech.listen(
      onResult: (val) {
        onResult(val.recognizedWords);
        if (val.finalResult) {
          _processCommandWithGemini(val.recognizedWords, students, onCommandRecognized);
        }
      },
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
      partialResults: true,
      localeId: "en_IN",
      onDevice: false,
      cancelOnError: false,
      listenMode: stt.ListenMode.search,
    );
  }


  void stop() {
    _speech.stop();
  }

  Future<void> _processCommandWithGemini(String text, List<Student> students, Function(VoiceCommand) onCommandRecognized) async {
    if (text.trim().isEmpty) return;

    // Normalize: lowercase, remove punctuation (.,!?)
    String lower = text.trim().toLowerCase().replaceAll(RegExp(r'[.,!?]'), '');
    
    final confirmationWords = {
      'yes', 'yeah', 'yep', 'sure', 'ok', 'okay', 'correct', 'right', 'do it', 'done',
      'ha', 'haa', 'haan', 'han', 'ji', 'sahi', 'achha', // Hindi
      'ho', 'hoy', 'barobar', 'chale', 'chalel' // Marathi
    };

    if (confirmationWords.contains(lower)) {
       onCommandRecognized(VoiceCommand(intent: VoiceIntent.confirmation, originalText: text));
       return;
    }

    final rejectionWords = {
      'no', 'nope', 'cancel', 'stop', 'wrong', 'wait', 'don\'t',
      'nahi', 'na', 'mat', 'rehne do', // Hindi
      'nako', 'naka', 'chukicha' // Marathi
    };

    if (rejectionWords.contains(lower)) {
       onCommandRecognized(VoiceCommand(intent: VoiceIntent.rejection, originalText: text));
       return;
    }

    try {
      final prompt = '''
      You are a strict voice command parser for a student mess app.
      You understand English, Hindi, and Marathi.
      Analyze this text: "$text"

      STRICTLY classify into one of these intents:
      1. "mark_attendance": User wants to mark a student present. (THIS IS THE ONLY ACTION THAT MODIFIES DATA)
         - English: "Mark Rahul", "Rahul is present".
         - Hindi: "Rahul ki attendance lagao", "Rahul present hai", "Rahul aagaya".
         - Marathi: "Rahul chi attendance lawa", "Rahul aala aahe".
      2. "check_dues": User asks about money/payment/bill. (READ-ONLY)
         - English: "Check dues for Rahul", "How much does Amit owe?".
         - Hindi: "Rahul ke paise check karo", "Amit ka kitna baaki hai?".
         - Marathi: "Rahul che paise kiti ahet?", "Amit kade kiti baaki ahet?".
      3. "check_lunch_count": User asks for headcount or remaining students. (READ-ONLY)
         - English: "How many people remaining?", "Who hasn't eaten?".
         - Hindi: "Kitne log baaki hai?", "Khana kisne nahi khaya?".
         - Marathi: "Kiti lok baaki ahet?", "Jevan konacha rahila?".
      4. "confirmation": User agrees/confirms.
         - "Yes", "Ha", "Ho", "Sahi", "Barobar".
      5. "rejection": User disagrees/cancels.
         - "No", "Nahi", "Nako", "Cancel".
      6. "unknown": Anything else.

      Rules:
      - If the text contains a name but no clear action, assume "mark_attendance".
      - Return ONLY JSON. No markdown.
      
      Output Format:
      {"intent": "mark_attendance", "name": "Rahul Sharma"}
      or
      {"intent": "check_lunch_count", "name": ""}
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception("Empty response from Gemini");
      }

      // Clean up markdown code blocks if present
      final jsonString = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = json.decode(jsonString);

      final intentStr = data['intent'] as String;
      final nameQuery = data['name'] as String;

      VoiceIntent intent = VoiceIntent.unknown;
      if (intentStr == 'mark_attendance') intent = VoiceIntent.markAttendance;
      if (intentStr == 'check_dues') intent = VoiceIntent.checkDues;
      if (intentStr == 'confirmation') intent = VoiceIntent.confirmation;
      if (intentStr == 'rejection') intent = VoiceIntent.rejection;
      if (intentStr == 'check_lunch_count') intent = VoiceIntent.checkLunchCount;

      if (intent == VoiceIntent.unknown) {
        onCommandRecognized(VoiceCommand(intent: VoiceIntent.unknown, originalText: text));
        return;
      }
      
      if (intent == VoiceIntent.confirmation || intent == VoiceIntent.rejection || intent == VoiceIntent.checkLunchCount) {
         onCommandRecognized(VoiceCommand(intent: intent, originalText: text));
         return;
      }

      Student? matchedStudent;
      double bestScore = 0.0;

      for (var student in students) {
        double score = student.name.toLowerCase().similarityTo(nameQuery.toLowerCase());
        String firstName = student.name.split(' ').first.toLowerCase();
        double firstNameScore = firstName.similarityTo(nameQuery.toLowerCase());
        
        if (firstNameScore > score) score = firstNameScore;

        if (score > bestScore) {
          bestScore = score;
          matchedStudent = student;
        }
      }

      if (bestScore > 0.3 && matchedStudent != null) {
        onCommandRecognized(VoiceCommand(
          intent: intent,
          originalText: text,
          student: matchedStudent,
          confidence: bestScore,
        ));
      } else {
        onCommandRecognized(VoiceCommand(
          intent: intent,
          originalText: text,
          error: "Found intent '$intentStr' but could not find student named '$nameQuery'",
        ));
      }

    } catch (e) {
      print("Gemini Error: $e");
      onCommandRecognized(VoiceCommand(
        intent: VoiceIntent.unknown, 
        originalText: text, 
        error: "AI Error: $e"
      ));
    }
  }
}

enum VoiceIntent {
  markAttendance,
  checkDues,
  confirmation,
  rejection,
  checkLunchCount,
  unknown
}

class VoiceCommand {
  final VoiceIntent intent;
  final String originalText;
  final Student? student;
  final String? error;
  final double confidence;

  VoiceCommand({
    required this.intent,
    required this.originalText,
    this.student,
    this.confidence = 0.0,
    this.error,
  });
}
